import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

enum SnackType { info, success, warning, error }

/// Snackbars uniformes (icône + couleur par type), remplaçant la précédente.
class AppSnackbar {
  AppSnackbar._();

  static void show(
    BuildContext context,
    String message, {
    SnackType type = SnackType.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final (Color bg, IconData icon) = switch (type) {
      SnackType.success => (AppColors.secondaryDark, Icons.check_circle_rounded),
      SnackType.warning => (const Color(0xFFB45309), Icons.warning_amber_rounded),
      SnackType.error => (const Color(0xFFB91C1C), Icons.error_rounded),
      SnackType.info => (AppColors.foreground, Icons.info_rounded),
    };

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: bg,
          duration: duration ?? Duration(milliseconds: type == SnackType.error ? 4500 : 3000),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, height: 1.35),
                ),
              ),
            ],
          ),
          action: actionLabel != null
              ? SnackBarAction(label: actionLabel, textColor: Colors.white, onPressed: onAction ?? () {})
              : null,
        ),
      );
  }

  static void success(BuildContext context, String message) => show(context, message, type: SnackType.success);
  static void error(BuildContext context, String message) => show(context, message, type: SnackType.error);
  static void warning(BuildContext context, String message) => show(context, message, type: SnackType.warning);
  static void info(BuildContext context, String message) => show(context, message, type: SnackType.info);

  /// Nettoie un message d'exception ("Exception: ..." → "...").
  static String clean(Object error) {
    var msg = error.toString();
    if (msg.startsWith('Exception: ')) msg = msg.substring(11);
    return msg;
  }
}
