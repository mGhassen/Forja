import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/desktop_window_chrome.dart';

/// Tone for resolve / loading-page failures.
enum ResolveFailureTone {
  /// Hard fail — no stream, crash, not found.
  error,

  /// Soft wait — upcoming, countdown, rate limit cool-down.
  waiting,
}

/// UX copy + actions for a cinematic resolve failure.
class ResolveFailure {
  final String title;
  final String? detail;
  final ResolveFailureTone tone;
  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback? onPrimary;
  final String secondaryLabel;
  final VoidCallback? onSecondary;

  const ResolveFailure({
    required this.title,
    this.detail,
    this.tone = ResolveFailureTone.error,
    this.primaryLabel = 'Try again',
    this.primaryIcon = Icons.refresh_rounded,
    this.onPrimary,
    this.secondaryLabel = 'Close',
    this.onSecondary,
  });

  IconData get icon => switch (tone) {
        ResolveFailureTone.waiting => Icons.schedule_rounded,
        ResolveFailureTone.error => Icons.wifi_tethering_error_rounded,
      };
}

/// Centered failure content (no backdrop) — used inside [LoadingOverlay]
/// and [ResolveFailureScaffold].
class ResolveFailurePanel extends StatelessWidget {
  const ResolveFailurePanel({
    super.key,
    required this.failure,
    this.compact = false,
  });

  final ResolveFailure failure;

  /// Bottom-strip layout on the loading overlay (tighter spacing).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accent = failure.tone == ResolveFailureTone.waiting
        ? Colors.amber.shade200
        : AppTheme.primaryColor;
    final iconSize = compact ? 40.0 : 52.0;
    final titleSize = compact ? 18.0 : 22.0;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: iconSize + 28,
            height: iconSize + 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.12),
              border: Border.all(color: accent.withValues(alpha: 0.28)),
            ),
            child: Icon(failure.icon, color: accent, size: iconSize * 0.55),
          ),
          SizedBox(height: compact ? 16 : 20),
          Text(
            failure.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.96),
              fontSize: titleSize,
              fontWeight: FontWeight.w600,
              height: 1.25,
              letterSpacing: 0.2,
              fontFamily: 'Poppins',
            ),
          ),
          if (failure.detail != null && failure.detail!.trim().isNotEmpty) ...[
            SizedBox(height: compact ? 8 : 10),
            Text(
              failure.detail!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: compact ? 13.0 : 14.0,
                fontWeight: FontWeight.w400,
                height: 1.45,
                fontFamily: 'Poppins',
              ),
            ),
          ],
          SizedBox(height: compact ? 22 : 28),
          if (failure.onPrimary != null)
            FilledButton.icon(
              onPressed: failure.onPrimary,
              icon: Icon(failure.primaryIcon, size: 18),
              label: Text(failure.primaryLabel),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          if (failure.onSecondary != null) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: failure.onSecondary,
              child: Text(
                failure.secondaryLabel,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Full-screen cinematic failure (backdrop + scrim + [ResolveFailurePanel]).
class ResolveFailureScaffold extends StatelessWidget {
  const ResolveFailureScaffold({
    super.key,
    required this.failure,
    this.backdropUrl,
  });

  final ResolveFailure failure;
  final String? backdropUrl;

  @override
  Widget build(BuildContext context) {
    final url = backdropUrl?.trim() ?? '';
    final body = Material(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url.isNotEmpty)
            CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, _) => const ColoredBox(color: Colors.black),
              errorWidget: (_, _, _) => const ColoredBox(color: Colors.black),
            )
          else
            const ColoredBox(color: Colors.black),
          Container(color: Colors.black.withValues(alpha: 0.72)),
          DesktopWindowChrome.overlayDragStrip(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 24,
                ),
                child: ResolveFailurePanel(failure: failure),
              ),
            ),
          ),
        ],
      ),
    );

    if (failure.onSecondary == null) return body;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): failure.onSecondary!,
      },
      child: Focus(autofocus: true, child: body),
    );
  }
}
