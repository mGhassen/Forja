import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

/// Generic letter mark (linked vs crossed). Pack chooses the letter / meaning.
class LetterLinkMark extends StatelessWidget {
  const LetterLinkMark({
    super.key,
    required this.letter,
    required this.linked,
    this.selected = false,
    this.size = 16,
    this.onTap,
  });

  final String letter;
  final bool linked;
  final bool selected;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mark = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LetterLinkPainter(
          letter: letter,
          linked: linked,
          selected: selected,
        ),
      ),
    );
    if (onTap == null) return mark;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: mark,
    );
  }
}

class _LetterLinkPainter extends CustomPainter {
  _LetterLinkPainter({
    required this.letter,
    required this.linked,
    required this.selected,
  });

  final String letter;
  final bool linked;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final c = Offset(size.width / 2, size.height / 2);
    final fill = Paint()
      ..color = selected || linked
          ? const Color(0xFF22C55E)
          : ForjaShellColors.iconMuted;
    canvas.drawCircle(c, r, fill);
    final tp = TextPainter(
      text: TextSpan(
        text: letter.isEmpty ? '?' : letter.substring(0, 1),
        style: TextStyle(
          color: Colors.black,
          fontSize: size.shortestSide * 0.55,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));
    if (!linked) {
      final x = Paint()
        ..color = const Color(0xFFEF4444)
        ..strokeWidth = size.shortestSide * 0.14
        ..strokeCap = StrokeCap.round;
      final inset = r * 0.35;
      canvas.drawLine(
        Offset(c.dx - inset, c.dy - inset),
        Offset(c.dx + inset, c.dy + inset),
        x,
      );
      canvas.drawLine(
        Offset(c.dx + inset, c.dy - inset),
        Offset(c.dx - inset, c.dy + inset),
        x,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LetterLinkPainter old) =>
      old.letter != letter || old.linked != linked || old.selected != selected;
}
