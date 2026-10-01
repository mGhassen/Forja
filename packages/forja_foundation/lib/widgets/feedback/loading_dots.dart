import 'package:flutter/material.dart';

/// Three cycling dots — same glyph as Sources kind tabs while a fetch is live.
class ForjaLoadingDots extends StatefulWidget {
  const ForjaLoadingDots({super.key, required this.color, this.fontSize = 13});

  final Color color;
  final double fontSize;

  @override
  State<ForjaLoadingDots> createState() => _ForjaLoadingDotsState();
}

class _ForjaLoadingDotsState extends State<ForjaLoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final lit = (_c.value * 3).floor() % 3;
        // height 1.0 + tight strut keeps layout size == [fontSize] so chips /
        // kind tabs do not grow when loading dots appear.
        return Text.rich(
          TextSpan(
            children: [
              for (var i = 0; i < 3; i++)
                TextSpan(
                  text: '.',
                  style: TextStyle(
                    color: widget.color.withValues(alpha: i <= lit ? 1 : 0.25),
                  ),
                ),
            ],
          ),
          style: TextStyle(
            fontSize: widget.fontSize,
            fontWeight: FontWeight.w700,
            height: 1.0,
            letterSpacing: 0.4,
          ),
          strutStyle: StrutStyle(
            fontSize: widget.fontSize,
            height: 1.0,
            forceStrutHeight: true,
          ),
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          ),
        );
      },
    );
  }
}

/// Loading `...` that turns into ✕ on hover when [onCancel] is set (kind tabs
/// + provider chips).
///
/// [size] must match the surrounding label font so idle → loading does not
/// change chip / tab height.
class ForjaBusyCancelGlyph extends StatelessWidget {
  const ForjaBusyCancelGlyph({
    super.key,
    required this.color,
    required this.hovered,
    required this.onHover,
    this.onCancel,
    this.size = 13,
  });

  final Color color;
  final bool hovered;
  final ValueChanged<bool> onHover;
  final VoidCallback? onCancel;

  /// Box + glyph size — keep equal to the chip / tab label font size.
  final double size;

  @override
  Widget build(BuildContext context) {
    final showCancel = hovered && onCancel != null;
    final box = size;
    return ExcludeFocus(
      child: MouseRegion(
        cursor: onCancel == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onEnter: (_) => onHover(true),
        onExit: (_) => onHover(false),
        child: GestureDetector(
          onTap: onCancel,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: box + 2,
            height: box,
            child: Center(
              child: showCancel
                  ? Icon(Icons.close_rounded, size: box, color: color)
                  : ForjaLoadingDots(color: color, fontSize: box),
            ),
          ),
        ),
      ),
    );
  }
}
