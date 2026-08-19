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
            height: 1.1,
            letterSpacing: 0.4,
          ),
        );
      },
    );
  }
}
