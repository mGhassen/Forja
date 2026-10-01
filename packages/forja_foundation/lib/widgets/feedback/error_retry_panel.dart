import 'package:flutter/material.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja_foundation/tokens/forja_motion_theme.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

/// Centered error copy + retry CTA. On TV the retry button autofocuses on show.
class ShellErrorRetryPanel extends StatefulWidget {
  const ShellErrorRetryPanel({
    super.key,
    required this.message,
    required this.onRetry,
    this.label = 'Retry',
    this.buttonIcon = Icons.refresh_rounded,
    this.statusIcon = Icons.error_outline_rounded,
    this.statusIconSize = 48,
  });

  final String message;
  final VoidCallback? onRetry;
  final String label;
  final IconData buttonIcon;
  final IconData statusIcon;
  final double statusIconSize;

  @override
  State<ShellErrorRetryPanel> createState() => _ShellErrorRetryPanelState();
}

class _ShellErrorRetryPanelState extends State<ShellErrorRetryPanel> {
  final FocusNode _retryFocus = FocusNode(debugLabel: 'error-retry');

  @override
  void initState() {
    super.initState();
    _scheduleRetryFocus();
  }

  @override
  void didUpdateWidget(covariant ShellErrorRetryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message != widget.message ||
        oldWidget.onRetry != widget.onRetry) {
      _scheduleRetryFocus();
    }
  }

  void _scheduleRetryFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ShellPaintScope.usesTvDensityOf(context)) return;
      if (widget.onRetry == null) return;
      if (_retryFocus.canRequestFocus) {
        _retryFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _retryFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tvFocus = ShellPaintScope.useTvFocusOf(context);
    final tvDensity = ShellPaintScope.usesTvDensityOf(context);
    final messageFontSize =
        tvDensity ? ShellTokens.tvBodyFontSize : 14.0;
    final pad = ShellTokens.chromeScale(32, tv: tvDensity);
    final gap = ShellTokens.chromeScale(16, tv: tvDensity);
    final iconSize = ShellTokens.chromeScale(
      widget.statusIconSize,
      tv: tvDensity,
    );
    final radius = ShellTokens.chromeScale(24, tv: tvDensity);

    return Center(
      child: Padding(
        padding: EdgeInsets.all(pad),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.statusIcon,
              color: ForjaShellColors.sectionAccent,
              size: iconSize,
            ),
            SizedBox(height: gap),
            Text(
              widget.message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: messageFontSize,
              ),
            ),
            SizedBox(height: gap),
            if (tvFocus)
              ShellPaintScope.focusableTap(
                context: context,
                onTap: widget.onRetry,
                focusNode: _retryFocus,
                borderRadius: radius,
                motion: ForjaMotionPreset.chipLift,
                ensureVisibleMode: ShellPaintEnsureVisible.item,
                child: _RetryButtonFace(
                  label: widget.label,
                  icon: widget.buttonIcon,
                  enabled: widget.onRetry != null,
                  fontSize: messageFontSize,
                  tv: tvDensity,
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: widget.onRetry,
                icon: Icon(widget.buttonIcon),
                label: Text(widget.label),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RetryButtonFace extends StatelessWidget {
  const _RetryButtonFace({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.fontSize,
    this.tv = false,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final double fontSize;
  final bool tv;

  @override
  Widget build(BuildContext context) {
    final fg = enabled ? Colors.black : Colors.black38;
    final bg = enabled ? Colors.white : Colors.white.withValues(alpha: 0.45);
    final radius = ShellTokens.chromeScale(24, tv: tv);
    final padH = ShellTokens.chromeScale(18, tv: tv);
    final padV = ShellTokens.chromeScale(10, tv: tv);
    final iconSize = ShellTokens.chromeScale(18, tv: tv);
    final gap = ShellTokens.chromeScale(8, tv: tv);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(radius),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: fg, size: iconSize),
            SizedBox(width: gap),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
