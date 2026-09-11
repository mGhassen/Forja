import 'package:flutter/material.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';

/// Toast tone.
enum ToastVariant {
  default_,
  success,
  error,
  info,
}

/// Thin toast API stub for Part 1.
///
/// Host toast (`ForjaToast`) is richer (queue, TV focus). Package API:
/// [showForjaToast] paints a short [SnackBar]-style overlay so kit code can
/// call a stable surface. Full host parity lands in Part 2 migration.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showForjaToast(
  BuildContext context, {
  required String message,
  ToastVariant variant = ToastVariant.default_,
  Duration duration = const Duration(seconds: 3),
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return null;
  final theme = ForjaThemeExtension.of(context);
  final accent = switch (variant) {
    ToastVariant.success => theme.brandGreen,
    ToastVariant.error => const Color(0xFFF87171),
    ToastVariant.info => theme.textSecondary,
    ToastVariant.default_ => theme.borderSubtle,
  };
  return messenger.showSnackBar(
    SnackBar(
      duration: duration,
      backgroundColor: theme.surfaceElevated,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(theme.radiusMd),
        side: BorderSide(color: accent),
      ),
      content: Text(
        message,
        style: TextStyle(color: theme.textPrimary, fontSize: 14),
      ),
    ),
  );
}
