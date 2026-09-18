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

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.statusIcon,
              color: ForjaShellColors.sectionAccent,
              size: widget.statusIconSize,
            ),
            const SizedBox(height: 16),
            Text(
              widget.message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: messageFontSize,
              ),
            ),
            const SizedBox(height: 16),
            if (tvFocus)
              ShellPaintScope.focusableTap(
                context: context,
                onTap: widget.onRetry,
                focusNode: _retryFocus,
                borderRadius: 24,
                motion: ForjaMotionPreset.chipLift,
                ensureVisibleMode: ShellPaintEnsureVisible.item,
                child: _RetryButtonFace(
                  label: widget.label,
                  icon: widget.buttonIcon,
                  enabled: widget.onRetry != null,
                  fontSize: messageFontSize,
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
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final fg = enabled ? Colors.black : Colors.black38;
    final bg = enabled ? Colors.white : Colors.white.withValues(alpha: 0.45);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: fg, size: 18),
            const SizedBox(width: 8),
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
