import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:forja/shared/playback/loading_overlay.dart';
import 'package:forja/shell/focus/shell_focusable_tap.dart';
import 'package:forja/shell/desktop/desktop_window_chrome.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

/// Tone for resolve / loading-page failures.
enum ResolveFailureTone {
  /// Hard fail - no stream, crash, not found.
  error,

  /// Soft wait - upcoming, countdown, rate limit cool-down.
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

/// Centered failure content (no backdrop) - used inside [LoadingOverlay]
/// and [ResolveFailureScaffold].
class ResolveFailurePanel extends StatefulWidget {
  const ResolveFailurePanel({
    super.key,
    required this.failure,
    this.compact = false,
  });

  final ResolveFailure failure;

  /// Bottom-strip layout on the loading overlay (tighter spacing).
  final bool compact;

  @override
  State<ResolveFailurePanel> createState() => _ResolveFailurePanelState();
}

class _ResolveFailurePanelState extends State<ResolveFailurePanel> {
  final FocusNode _primaryFocus =
      FocusNode(debugLabel: 'resolve-failure-primary');
  final FocusNode _secondaryFocus =
      FocusNode(debugLabel: 'resolve-failure-secondary');

  @override
  void initState() {
    super.initState();
    _schedulePrimaryFocus();
  }

  @override
  void didUpdateWidget(covariant ResolveFailurePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.failure.title != widget.failure.title ||
        oldWidget.failure.onPrimary != widget.failure.onPrimary) {
      _schedulePrimaryFocus();
    }
  }

  void _schedulePrimaryFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ShellScope.inputPolicyOf(context).useFocusableMoodChips) return;
      if (ShellScope.inputPolicyOf(context).scaleOnHover) return;
      if (widget.failure.onPrimary == null) {
        if (widget.failure.onSecondary != null &&
            _secondaryFocus.canRequestFocus) {
          _secondaryFocus.requestFocus();
        }
        return;
      }
      if (_primaryFocus.canRequestFocus) {
        _primaryFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _primaryFocus.dispose();
    _secondaryFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final failure = widget.failure;
    final compact = widget.compact;
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final tvFocus = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final mouseHover = ShellScope.inputPolicyOf(context).scaleOnHover;
    final leanback = tvFocus && !mouseHover;
    final accent = failure.tone == ResolveFailureTone.waiting
        ? Colors.amber.shade200
        : AppTheme.primaryColor;
    final iconSize = compact
        ? (tv
            ? ShellTokens.streamLoadingFailureIconCompactTv
            : ShellTokens.streamLoadingFailureIconCompact)
        : (tv
            ? ShellTokens.streamLoadingFailureIconTv
            : ShellTokens.streamLoadingFailureIcon);
    final iconPad = tv
        ? ShellTokens.streamLoadingFailureIconPadTv
        : ShellTokens.streamLoadingFailureIconPad;
    final titleSize = compact
        ? (tv
            ? ShellTokens.streamLoadingFailureTitleFontSizeCompactTv
            : ShellTokens.streamLoadingFailureTitleFontSizeCompact)
        : (tv
            ? ShellTokens.streamLoadingFailureTitleFontSizeTv
            : ShellTokens.streamLoadingFailureTitleFontSize);
    final detailSize = compact
        ? (tv
            ? ShellTokens.streamLoadingFailureDetailFontSizeCompactTv
            : ShellTokens.streamLoadingFailureDetailFontSizeCompact)
        : (tv
            ? ShellTokens.streamLoadingFailureDetailFontSizeTv
            : ShellTokens.streamLoadingFailureDetailFontSize);
    final maxW = tv
        ? ShellTokens.streamLoadingFailureMaxWidthTv
        : ShellTokens.streamLoadingFailureMaxWidth;
    final titleGap = compact
        ? (tv
            ? ShellTokens.streamLoadingFailureTitleGapCompactTv
            : ShellTokens.streamLoadingFailureTitleGapCompact)
        : (tv
            ? ShellTokens.streamLoadingFailureTitleGapTv
            : ShellTokens.streamLoadingFailureTitleGap);
    final detailGap = compact
        ? (tv
            ? ShellTokens.streamLoadingFailureDetailGapCompactTv
            : ShellTokens.streamLoadingFailureDetailGapCompact)
        : (tv
            ? ShellTokens.streamLoadingFailureDetailGapTv
            : ShellTokens.streamLoadingFailureDetailGap);
    final actionsGap = compact
        ? (tv
            ? ShellTokens.streamLoadingFailureActionsGapCompactTv
            : ShellTokens.streamLoadingFailureActionsGapCompact)
        : (tv
            ? ShellTokens.streamLoadingFailureActionsGapTv
            : ShellTokens.streamLoadingFailureActionsGap);
    final secondaryGap = tv
        ? ShellTokens.streamLoadingFailureSecondaryGapTv
        : ShellTokens.streamLoadingFailureSecondaryGap;
    final secondaryPadH = tv
        ? ShellTokens.streamLoadingFailureSecondaryPadHTv
        : ShellTokens.streamLoadingFailureSecondaryPadH;
    final secondaryPadV = tv
        ? ShellTokens.streamLoadingFailureSecondaryPadVTv
        : ShellTokens.streamLoadingFailureSecondaryPadV;
    final secondaryFont = tv
        ? ShellTokens.streamLoadingFailureSecondaryFontSizeTv
        : ShellTokens.streamLoadingFailureSecondaryFontSize;
    final buttonRadius = tv
        ? ShellTokens.streamLoadingFailureButtonRadiusTv
        : ShellTokens.streamLoadingFailureButtonRadius;
    final buttonPadH = tv
        ? ShellTokens.streamLoadingFailureButtonPadHTv
        : ShellTokens.streamLoadingFailureButtonPadH;
    final buttonPadV = tv
        ? ShellTokens.streamLoadingFailureButtonPadVTv
        : ShellTokens.streamLoadingFailureButtonPadV;
    final buttonFont = tv
        ? ShellTokens.streamLoadingFailureButtonFontSizeTv
        : ShellTokens.streamLoadingFailureButtonFontSize;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxW),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: iconSize + iconPad,
            height: iconSize + iconPad,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.12),
              border: Border.all(color: accent.withValues(alpha: 0.28)),
            ),
            child: Icon(failure.icon, color: accent, size: iconSize * 0.55),
          ),
          SizedBox(height: titleGap),
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
            SizedBox(height: detailGap),
            Text(
              failure.detail!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: detailSize,
                fontWeight: FontWeight.w400,
                height: 1.45,
                fontFamily: 'Poppins',
              ),
            ),
          ],
          SizedBox(height: actionsGap),
          if (failure.onPrimary != null)
            leanback
                ? shellFocusableTap(
                    context: context,
                    onTap: failure.onPrimary,
                    focusNode: _primaryFocus,
                    borderRadius: buttonRadius,
                    scaleOnFocus: 1.0,
                    showFocusBorder: true,
                    onDownEdge: failure.onSecondary != null
                        ? () {
                            if (_secondaryFocus.canRequestFocus) {
                              _secondaryFocus.requestFocus();
                            }
                          }
                        : null,
                    child: _PrimaryFailureButtonFace(
                      label: failure.primaryLabel,
                      icon: failure.primaryIcon,
                    ),
                  )
                : FilledButton.icon(
                    onPressed: failure.onPrimary,
                    icon: Icon(
                      failure.primaryIcon,
                      size: ShellPaintScope.iconOf(context, 18),
                    ),
                    label: Text(failure.primaryLabel),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(
                        horizontal: buttonPadH,
                        vertical: buttonPadV,
                      ),
                      textStyle: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: buttonFont,
                      ),
                    ),
                  ),
          if (failure.onSecondary != null) ...[
            SizedBox(height: secondaryGap),
            leanback
                ? shellFocusableTap(
                    context: context,
                    onTap: failure.onSecondary,
                    focusNode: _secondaryFocus,
                    borderRadius: buttonRadius,
                    scaleOnFocus: 1.0,
                    showFocusBorder: true,
                    onUpEdge: failure.onPrimary != null
                        ? () {
                            if (_primaryFocus.canRequestFocus) {
                              _primaryFocus.requestFocus();
                            }
                          }
                        : null,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: secondaryPadH,
                        vertical: secondaryPadV,
                      ),
                      child: Text(
                        failure.secondaryLabel,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w500,
                          fontSize: secondaryFont,
                        ),
                      ),
                    ),
                  )
                : TextButton(
                    onPressed: failure.onSecondary,
                    child: Text(
                      failure.secondaryLabel,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                        fontSize: secondaryFont,
                      ),
                    ),
                  ),
          ],
        ],
      ),
    );
  }
}

class _PrimaryFailureButtonFace extends StatelessWidget {
  const _PrimaryFailureButtonFace({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final radius = tv
        ? ShellTokens.streamLoadingFailureButtonRadiusTv
        : ShellTokens.streamLoadingFailureButtonRadius;
    final padH = tv
        ? ShellTokens.streamLoadingFailureButtonPadHTv
        : ShellTokens.streamLoadingFailureButtonPadH;
    final padV = tv
        ? ShellTokens.streamLoadingFailureButtonPadVTv
        : ShellTokens.streamLoadingFailureButtonPadV;
    final gap = tv
        ? ShellTokens.streamLoadingFailureIconGapTv
        : ShellTokens.streamLoadingFailureIconGap;
    final fontSize = tv
        ? ShellTokens.streamLoadingFailureButtonFontSizeTv
        : ShellTokens.streamLoadingFailureButtonFontSize;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: ShellPaintScope.iconOf(context, 18),
              color: Colors.black,
            ),
            SizedBox(width: gap),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: fontSize,
                color: Colors.black,
              ),
            ),
          ],
        ),
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

    if (failure.onSecondary == null && failure.onPrimary == null) return body;

    final escape = failure.onSecondary ?? failure.onPrimary!;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): escape,
      },
      child: body,
    );
  }
}
