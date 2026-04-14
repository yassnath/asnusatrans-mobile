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
    await PushNotificationService.instance._initializeLocalNotifications();
    await PushNotificationService.instance
        ._showNotificationFromRemoteMessage(message);
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
    'cvant_alerts_v2',
    'CVANT Alerts',
    description: 'Push notification channel for approval and invoice alerts.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
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
  String? _boundRoleTopic;
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

  Future<void> ensureNotificationPermissionPrompt() async {
    await _requestNotificationPermission();
  }

  Future<void> bindAuthenticatedSession(AuthSession session) async {
    final previousRole = _boundSession?.normalizedRole;
    _boundSession = session;
    if (!_pushRuntimeReady) return;
    await _syncRoleTopicSubscription(
      previousRole: previousRole,
      nextRole: session.normalizedRole,
    );
    await _requestNotificationPermission();
    await _syncBoundToken();
  }

  Future<void> clearAuthenticatedSession() async {
    final token = _activeToken;
    final previousRole = _boundSession?.normalizedRole;
    _boundSession = null;
    _cancelTokenRetry();
    if (_pushRuntimeReady) {
      await _syncRoleTopicSubscription(
        previousRole: previousRole,
        nextRole: null,
      );
    }
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

  String? _roleTopicName(String? role) {
    final cleaned = (role ?? '').trim().toLowerCase();
    switch (cleaned) {
      case 'admin':
      case 'owner':
      case 'pengurus':
      case 'customer':
        return 'role_$cleaned';
      default:
        return null;
    }
  }

  Future<void> _syncRoleTopicSubscription({
    required String? previousRole,
    required String? nextRole,
  }) async {
    if (!_pushRuntimeReady) return;
    final previousTopic = _roleTopicName(previousRole);
    final nextTopic = _roleTopicName(nextRole);

    if (previousTopic != null && previousTopic != nextTopic) {
      try {
        await FirebaseMessaging.instance.unsubscribeFromTopic(previousTopic);
      } catch (error, stackTrace) {
        AppSecurity.debugLog(
          'Failed to unsubscribe push role topic $previousTopic',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    if (nextTopic != null && _boundRoleTopic != nextTopic) {
      try {
        await FirebaseMessaging.instance.subscribeToTopic(nextTopic);
        _boundRoleTopic = nextTopic;
        AppSecurity.debugLog('Subscribed push role topic $nextTopic');
      } catch (error, stackTrace) {
        AppSecurity.debugLog(
          'Failed to subscribe push role topic $nextTopic',
          error: error,
          stackTrace: stackTrace,
        );
      }
      return;
    }

    _boundRoleTopic = nextTopic;
  }

  Future<void> _initializeLocalNotifications() async {
    if (_localNotificationsReady) return;
    const androidSettings =
        AndroidInitializationSettings('ic_stat_notification');
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
      await _syncRoleTopicSubscription(
        previousRole: null,
        nextRole: session.normalizedRole,
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
    await _showNotificationFromRemoteMessage(message);
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

  Future<void> _showNotificationFromRemoteMessage(RemoteMessage message) async {
    if (!_localNotificationsReady) return;

    final title = _resolveMessageTitle(message);
    final body = _resolveMessageBody(message);
    if (title.isEmpty && body.isEmpty) return;
    final badgeCount = int.tryParse(
          '${message.data['badge_count'] ?? message.data['notification_count'] ?? ''}'
              .trim(),
        ) ??
        1;

    await _localNotifications.show(
      id: message.messageId?.hashCode ?? message.hashCode,
      title: title.isEmpty ? 'AS Nusa Trans' : title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _defaultChannel.id,
          _defaultChannel.name,
          channelDescription: _defaultChannel.description,
          importance: Importance.max,
          priority: Priority.max,
          icon: 'ic_stat_notification',
          color: const Color(0xFF5B8CFF),
          playSound: true,
          enableVibration: true,
          ticker: title.isEmpty ? 'AS Nusa Trans' : title,
          visibility: NotificationVisibility.public,
          category: AndroidNotificationCategory.message,
          number: badgeCount,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: _encodePayload(message.data),
    );
  }

  String _resolveMessageTitle(RemoteMessage message) {
    final fromNotification = message.notification?.title?.trim() ?? '';
    if (fromNotification.isNotEmpty) return fromNotification;
    final fromData =
        '${message.data['title'] ?? message.data['notification_title'] ?? ''}'
            .trim();
    return fromData;
  }

  String _resolveMessageBody(RemoteMessage message) {
    final fromNotification = message.notification?.body?.trim() ?? '';
    if (fromNotification.isNotEmpty) return fromNotification;
    final fromData =
        '${message.data['body'] ?? message.data['notification_body'] ?? message.data['message'] ?? ''}'
            .trim();
    return fromData;
  }
}
