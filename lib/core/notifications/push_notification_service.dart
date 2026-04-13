import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../../features/auth/models/auth_session.dart';
import '../security/app_security.dart';

enum PushNavigationTarget {
  orderAcceptance,
  invoiceList,
  customerNotifications,
}

class PushNavigationIntent {
  const PushNavigationIntent({
    required this.target,
    this.sourceId,
    this.payload = const <String, dynamic>{},
  });

  final PushNavigationTarget target;
  final String? sourceId;
  final Map<String, dynamic> payload;
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await _initializeFirebaseForPush();
  } catch (_) {
    // Ignore: app may already be initialized or Firebase config may be absent.
  }
}

Future<void> _initializeFirebaseForPush() async {
  if (Firebase.apps.isNotEmpty) return;
  final options = AppConfig.firebaseOptionsForCurrentPlatform;
  if (options != null) {
    await Firebase.initializeApp(options: options);
    return;
  }
  await Firebase.initializeApp();
}

@pragma('vm:entry-point')
void handleLocalNotificationBackgroundTap(NotificationResponse response) {
  final payload = response.payload ?? '';
  final intent = PushNotificationService.instance._intentFromPayloadString(
    payload,
  );
  if (intent != null) {
    PushNotificationService.instance._emitIntent(intent);
  }
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  static const AndroidNotificationChannel _defaultChannel =
      AndroidNotificationChannel(
    'cvant_alerts',
    'CVANT Alerts',
    description: 'Push notification channel for approval and invoice alerts.',
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final StreamController<PushNavigationIntent> _intentController =
      StreamController<PushNavigationIntent>.broadcast();

  Stream<PushNavigationIntent> get intents => _intentController.stream;
  PushNavigationIntent? _pendingIntent;

  PushNavigationIntent? consumePendingIntent() {
    final pending = _pendingIntent;
    _pendingIntent = null;
    return pending;
  }

  bool _initialized = false;
  bool _localNotificationsReady = false;
  bool _pushRuntimeReady = false;
  String? _activeToken;
  AuthSession? _boundSession;
  String? _initializationFailureReason;
  AppLifecycleListener? _lifecycleListener;
  Timer? _tokenRetryTimer;
  int _tokenRetryAttempt = 0;

  bool get _supportsPushRuntime {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (!_supportsPushRuntime) return;

    try {
      await _initializeFirebaseForPush();
      _pushRuntimeReady = true;
    } catch (error, stackTrace) {
      final manualConfigHint = AppConfig.hasFirebaseManualOptions
          ? 'Pastikan nilai FIREBASE_* dart-define sesuai project Firebase.'
          : 'Tambahkan android/app/google-services.json atau ios/Runner/GoogleService-Info.plist, atau isi FIREBASE_* lewat --dart-define.';
      _initializationFailureReason =
          'Push runtime skipped: Firebase belum siap. $manualConfigHint';
      AppSecurity.debugLog(
        _initializationFailureReason!,
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }

    _lifecycleListener ??= AppLifecycleListener(
      onResume: () {
        unawaited(_syncBoundToken());
      },
    );

    await _initializeLocalNotifications();

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await FirebaseMessaging.instance.setAutoInitEnabled(true);
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    await _requestNotificationPermission();

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);
    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      _activeToken = token.trim().isEmpty ? null : token.trim();
      await _syncBoundToken();
    });

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageTap(initialMessage);
    }
  }

  Future<void> bindAuthenticatedSession(AuthSession session) async {
    _boundSession = session;
    if (!_pushRuntimeReady) return;
    await _requestNotificationPermission();
    await _syncBoundToken();
  }

  Future<void> clearAuthenticatedSession() async {
    final token = _activeToken;
    _boundSession = null;
    _cancelTokenRetry();
    if (!_pushRuntimeReady || token == null || token.isEmpty) return;
    try {
      await Supabase.instance.client.rpc(
        'deactivate_device_push_token',
        params: <String, dynamic>{'p_token': token},
      );
    } catch (error, stackTrace) {
      AppSecurity.debugLog(
        'Failed to deactivate push token',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _initializeLocalNotifications() async {
    if (_localNotificationsReady) return;
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        _emitIntentFromPayloadString(response.payload);
      },
      onDidReceiveBackgroundNotificationResponse:
          handleLocalNotificationBackgroundTap,
    );

    final androidPlatform =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlatform?.createNotificationChannel(_defaultChannel);

    _localNotificationsReady = true;
  }

  Future<void> _requestNotificationPermission() async {
    if (!_pushRuntimeReady) return;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      final androidPlatform =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlatform?.requestNotificationsPermission();
      AppSecurity.debugLog(
        'Notification permission status: ${settings.authorizationStatus.name}',
      );
    } catch (error, stackTrace) {
      AppSecurity.debugLog(
        'Notification permission request failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _syncBoundToken() async {
    final session = _boundSession;
    if (!_pushRuntimeReady || session == null) return;
    final userId = session.userId?.trim() ?? '';
    if (userId.isEmpty) return;

    try {
      var token = _activeToken;
      token ??= await FirebaseMessaging.instance.getToken();
      final cleanedToken = token?.trim() ?? '';
      if (cleanedToken.isEmpty) {
        AppSecurity.debugLog(
          'Push token kosong. Firebase Messaging belum memberikan device token.',
          error: _initializationFailureReason,
        );
        _scheduleTokenRetry();
        return;
      }
      _activeToken = cleanedToken;
      _cancelTokenRetry();
      _tokenRetryAttempt = 0;

      await Supabase.instance.client.rpc(
        'upsert_device_push_token',
        params: <String, dynamic>{
          'p_token': cleanedToken,
          'p_platform': Platform.isAndroid ? 'android' : 'ios',
          'p_app_role': session.normalizedRole,
        },
      );
      AppSecurity.debugLog(
        'Push token synced for role ${session.normalizedRole}.',
      );
    } catch (error, stackTrace) {
      AppSecurity.debugLog(
        'Push token registration failed',
        error: error,
        stackTrace: stackTrace,
      );
      _scheduleTokenRetry();
    }
  }

  void _scheduleTokenRetry() {
    final session = _boundSession;
    if (!_pushRuntimeReady || session == null) return;
    if (_tokenRetryTimer?.isActive == true) return;

    const retryScheduleSeconds = <int>[3, 10, 30];
    final retryIndex =
        _tokenRetryAttempt.clamp(0, retryScheduleSeconds.length - 1);
    final retryDelay = Duration(seconds: retryScheduleSeconds[retryIndex]);
    _tokenRetryAttempt += 1;

    _tokenRetryTimer = Timer(retryDelay, () {
      _tokenRetryTimer = null;
      unawaited(_syncBoundToken());
    });
  }

  void _cancelTokenRetry() {
    _tokenRetryTimer?.cancel();
    _tokenRetryTimer = null;
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (!_localNotificationsReady) return;
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      id: message.hashCode,
      title: notification.title ?? 'AS Nusa Trans',
      body: notification.body ?? '',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _defaultChannel.id,
          _defaultChannel.name,
          channelDescription: _defaultChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: _encodePayload(message.data),
    );
  }

  void _handleMessageTap(RemoteMessage message) {
    _emitIntent(_intentFromData(message.data));
  }

  void _emitIntentFromPayloadString(String? payload) {
    final intent = _intentFromPayloadString(payload);
    if (intent != null) {
      _emitIntent(intent);
    }
  }

  PushNavigationIntent? _intentFromPayloadString(String? payload) {
    if (payload == null || payload.trim().isEmpty) return null;
    try {
      final decoded = Map<String, dynamic>.from(
        _decodePayload(payload),
      );
      return _intentFromData(decoded);
    } catch (_) {
      return null;
    }
  }

  PushNavigationIntent? _intentFromData(Map<String, dynamic> rawData) {
    final data = rawData.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final target = '${data['target'] ?? ''}'.trim().toLowerCase();
    final requestType = '${data['request_type'] ?? ''}'.trim().toLowerCase();
    final sourceType = '${data['source_type'] ?? ''}'.trim().toLowerCase();
    final sourceId = '${data['source_id'] ?? data['invoice_id'] ?? ''}'.trim();

    PushNavigationTarget? navTarget;
    if (target == 'order_acceptance') {
      navTarget = PushNavigationTarget.orderAcceptance;
    } else if (target == 'invoice_list') {
      navTarget = PushNavigationTarget.invoiceList;
    } else if (target == 'customer_notifications') {
      navTarget = PushNavigationTarget.customerNotifications;
    } else if (sourceType == 'invoice' &&
        (requestType == 'new_income' || requestType == 'edit_request')) {
      navTarget = PushNavigationTarget.orderAcceptance;
    } else if (sourceType == 'invoice') {
      navTarget = PushNavigationTarget.invoiceList;
    }

    if (navTarget == null) return null;
    return PushNavigationIntent(
      target: navTarget,
      sourceId: sourceId.isEmpty ? null : sourceId,
      payload: data,
    );
  }

  void _emitIntent(PushNavigationIntent? intent) {
    if (intent == null) return;
    _pendingIntent = intent;
    if (_intentController.isClosed) return;
    _intentController.add(intent);
  }

  String _encodePayload(Map<String, dynamic> payload) {
    return jsonEncode(payload);
  }

  Map<String, dynamic> _decodePayload(String payload) {
    final decoded = jsonDecode(payload);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }
    return <String, dynamic>{};
  }
}
