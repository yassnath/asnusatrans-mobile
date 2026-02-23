import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/cvant_button_styles.dart';

enum CvantPopupType {
  success,
  error,
  warning,
  info,
  neutral,
}

Color _accentFor(CvantPopupType type) {
  switch (type) {
    case CvantPopupType.success:
      return AppColors.success;
    case CvantPopupType.warning:
      return AppColors.warning;
    case CvantPopupType.info:
      return AppColors.blue;
    case CvantPopupType.neutral:
      return AppColors.blue;
    case CvantPopupType.error:
      return AppColors.danger;
  }
}

IconData _iconFor(CvantPopupType type) {
  switch (type) {
    case CvantPopupType.success:
      return Icons.check_circle_outline;
    case CvantPopupType.warning:
      return Icons.warning_amber;
    case CvantPopupType.info:
      return Icons.info_outline;
    case CvantPopupType.neutral:
      return Icons.info_outline;
    case CvantPopupType.error:
      return Icons.warning_amber;
  }
}

String _titleFor(CvantPopupType type) {
  switch (type) {
    case CvantPopupType.success:
      return 'Success';
    case CvantPopupType.warning:
      return 'Warning';
    case CvantPopupType.info:
      return 'Info';
    case CvantPopupType.neutral:
      return 'Info';
    case CvantPopupType.error:
      return 'Error';
  }
}

Future<void> showCvantPopup({
  required BuildContext context,
  required String message,
  CvantPopupType type = CvantPopupType.info,
  String? title,
  String okLabel = 'OK',
  bool showOkButton = true,
  bool showCloseButton = true,
  bool barrierDismissible = true,
  Duration? autoCloseAfter,
}) {
  final accent = _accentFor(type);
  var autoDismissScheduled = false;
  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: barrierDismissible,
    barrierColor: AppColors.popupOverlay,
    builder: (dialogContext) {
      if (!autoDismissScheduled && autoCloseAfter != null) {
        autoDismissScheduled = true;
        final route = ModalRoute.of(dialogContext);
        Future<void>.delayed(autoCloseAfter, () {
          if (!dialogContext.mounted) return;
          if (route?.isCurrent != true) return;
          Navigator.of(dialogContext, rootNavigator: true).pop();
        });
      }

      return _CvantPopupFrame(
        accent: accent,
        icon: _iconFor(type),
        title: title ?? _titleFor(type),
        showCloseButton: showCloseButton,
        onClose: () => Navigator.of(dialogContext).pop(),
        body: Text(
          message,
          style: TextStyle(
            color: AppColors.textSecondaryFor(dialogContext),
            fontSize: 15,
            height: 1.4,
          ),
        ),
        actions: showOkButton
            ? [
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  style: CvantButtonStyles.filled(dialogContext, color: accent),
                  child: Text(okLabel),
                ),
              ]
            : const [],
      );
    },
  );
}

Future<bool> showCvantConfirmPopup({
  required BuildContext context,
  required String title,
  required String message,
  CvantPopupType type = CvantPopupType.error,
  String cancelLabel = 'Cancel',
  String confirmLabel = 'Confirm',
}) async {
  final accent = _accentFor(type);
  final ok = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierColor: AppColors.popupOverlay,
    builder: (dialogContext) {
      return _CvantPopupFrame(
        accent: accent,
        icon: _iconFor(type),
        title: title,
        showCloseButton: true,
        onClose: () => Navigator.of(dialogContext).pop(false),
        body: Text(
          message,
          style: TextStyle(
            color: AppColors.textSecondaryFor(dialogContext),
            fontSize: 15,
            height: 1.4,
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: CvantButtonStyles.outlined(
              dialogContext,
              color: AppColors.isLight(dialogContext)
                  ? AppColors.textSecondaryLight
                  : const Color(0xFFE2E8F0),
              borderColor: AppColors.neutralOutline,
            ),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: CvantButtonStyles.filled(dialogContext, color: accent),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return ok == true;
}

class _CvantPopupFrame extends StatelessWidget {
  const _CvantPopupFrame({
    required this.accent,
    required this.icon,
    required this.title,
    required this.showCloseButton,
    required this.onClose,
    required this.body,
    required this.actions,
  });

  final Color accent;
  final IconData icon;
  final String title;
  final bool showCloseButton;
  final VoidCallback onClose;
  final Widget body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final width = max(
      280.0,
      min(MediaQuery.sizeOf(context).width - 32, 600.0),
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: width,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.35),
                blurRadius: 36,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(icon, color: accent, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: AppColors.textPrimaryFor(context),
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          body,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (showCloseButton)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onClose,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.close,
                            color: AppColors.textMutedFor(context),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: actions,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
