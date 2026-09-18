import 'package:flutter/material.dart';
import 'package:forja/features/settings/packs/engine_pack_update.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

/// Heartbeating yellow circle with sun + exclamation.
class PackUpdateAlertIcon extends StatefulWidget {
  const PackUpdateAlertIcon({
    super.key,
    this.size = ShellTokens.packUpdateBadgeSize,
    this.heartbeat = true,
  });

  final double size;
  final bool heartbeat;

  @override
  State<PackUpdateAlertIcon> createState() => _PackUpdateAlertIconState();
}

class _PackUpdateAlertIconState extends State<PackUpdateAlertIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: ShellTokens.packUpdateHeartbeat,
    );
    if (widget.heartbeat) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant PackUpdateAlertIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.heartbeat == oldWidget.heartbeat) return;
    if (widget.heartbeat) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse
        ..stop()
        ..value = 1;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glyph = _SunExclamation(
      size: widget.size * ShellTokens.packUpdateGlyphScale,
    );
    final circle = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: ForjaShellColors.packUpdateAlert,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: ForjaShellColors.packUpdateAlert.withValues(
              alpha: ShellTokens.packUpdateGlowAlpha,
            ),
            blurRadius: widget.size * ShellTokens.packUpdateGlowBlurScale,
            spreadRadius: ShellTokens.packUpdateGlowSpread,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: glyph,
    );
    if (!widget.heartbeat) return circle;
    return ScaleTransition(
      scale: Tween<double>(
        begin: ShellTokens.packUpdateHeartbeatScaleMin,
        end: ShellTokens.packUpdateHeartbeatScaleMax,
      ).animate(
        CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
      ),
      child: circle,
    );
  }
}

class _SunExclamation extends StatelessWidget {
  const _SunExclamation({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(
            PackUpdateAlertGlyph.icon,
            size: size * ShellTokens.packUpdateSunScale,
            color: Colors.black.withValues(
              alpha: ShellTokens.packUpdateSunInkAlpha,
            ),
          ),
          Positioned(
            right: -size * ShellTokens.packUpdateBangOffsetX,
            top: -size * ShellTokens.packUpdateBangOffsetY,
            child: Text(
              '!',
              style: TextStyle(
                color: Colors.black,
                fontSize: size * ShellTokens.packUpdateBangFontScale,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
