import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

/// Tracker / link mark: optional logo image, else letter. Crossed when not linked.
class LetterLinkMark extends StatelessWidget {
  const LetterLinkMark({
    super.key,
    required this.letter,
    required this.linked,
    this.selected = false,
    this.size = 16,
    this.onTap,
    this.image,
    this.color,
  });

  final String letter;
  final bool linked;
  final bool selected;
  final double size;
  final VoidCallback? onTap;

  /// Pack/host-supplied logo (asset or network). Falls back to [letter].
  final ImageProvider? image;

  /// Optional tint override (e.g. focus/hover green). Else selected/linked defaults.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final mark = SizedBox(
      width: size,
      height: size,
      child: image != null
          ? _ImageMark(
              image: image!,
              linked: linked,
              selected: selected,
              size: size,
              color: color,
            )
          : CustomPaint(
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

class _ImageMark extends StatelessWidget {
  const _ImageMark({
    required this.image,
    required this.linked,
    required this.selected,
    required this.size,
    this.color,
  });

  final ImageProvider image;
  final bool linked;
  final bool selected;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    // CDN/logos are often black-on-transparent — tint on dark chrome.
    final tint =
        color ??
        (selected
            ? ForjaShellColors.brandGreen
            : linked
            ? Colors.white
            : Colors.white54);
    return Stack(
      fit: StackFit.expand,
      children: [
        Image(
          image: image,
          fit: BoxFit.contain,
          color: tint,
          colorBlendMode: BlendMode.srcIn,
        ),
        if (!linked)
          CustomPaint(painter: _RedCrossPainter(stroke: size * 0.12)),
      ],
    );
  }
}

class _RedCrossPainter extends CustomPainter {
  _RedCrossPainter({required this.stroke});

  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final inset = size.shortestSide * 0.22;
    final x = Paint()
      ..color = const Color(0xFFEF4444)
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
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

  @override
  bool shouldRepaint(covariant _RedCrossPainter old) => old.stroke != stroke;
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
      _RedCrossPainter(stroke: size.shortestSide * 0.14).paint(canvas, size);
    }
  }

  @override
  bool shouldRepaint(covariant _LetterLinkPainter old) =>
      old.letter != letter || old.linked != linked || old.selected != selected;
}
