import 'package:flutter/material.dart';
import 'package:path_parsing/path_parsing.dart';

const forjaLogoAspectRatio = 370.0 / 160.0;

enum ForjaLetter { f, o, r, j, a }

const forjaLetterOrder = [
  ForjaLetter.f,
  ForjaLetter.o,
  ForjaLetter.r,
  ForjaLetter.j,
  ForjaLetter.a,
];

const _viewBoxWidth = 370.0;
const _viewBoxHeight = 160.0;
const _groupTranslateX = -132.141059;
const _groupTranslateY = 283.992524;
const _groupScale = 0.1;

const _letterPaths = <(ForjaLetter, String)>[
  (ForjaLetter.j, 'M3784 2821 c-53 -32 -74 -68 -74 -125 0 -66 27 -111 83 -136 55 -26 85 -25 137 3 138 73 86 277 -70 277 -26 0 -58 -8 -76 -19z'),
  (ForjaLetter.f, 'M1580 2796 c-90 -24 -183 -105 -220 -192 -36 -84 -41 -155 -38 -589 l3 -420 137 -3 138 -3 2 253 3 253 153 3 152 3 0 124 0 125 -156 0 -157 0 7 57 c13 112 45 134 201 141 l115 5 0 128 0 129 -147 -1 c-83 0 -168 -6 -193 -13z'),
  (ForjaLetter.o, 'M2334 2461 c-174 -50 -295 -187 -325 -369 -50 -300 217 -559 526 -513 108 17 193 59 265 131 174 174 175 456 0 631 -121 122 -300 168 -466 120z m214 -246 c131 -55 164 -233 64 -338 -41 -43 -75 -57 -141 -57 -94 0 -144 27 -181 100 -39 78 -30 179 22 245 46 59 157 82 236 50z'),
  (ForjaLetter.r, 'M4437 2465 c-226 -62 -367 -275 -336 -505 32 -225 240 -395 461 -377 63 5 157 42 173 67 13 21 25 9 25 -25 l0 -35 131 0 130 0 -3 283 c-3 264 -5 286 -26 337 -50 124 -160 222 -285 253 -78 20 -202 21 -270 2z m208 -254 c151 -68 153 -300 4 -377 -37 -19 -122 -21 -172 -5 -54 18 -103 78 -118 145 -11 49 -10 64 4 110 22 68 46 98 99 125 53 26 129 27 183 2z'),
  (ForjaLetter.j, 'M3265 2446 c-135 -43 -214 -147 -235 -312 -6 -43 -10 -182 -8 -309 l3 -230 138 -3 137 -3 0 253 c0 221 2 257 18 287 30 61 57 72 176 78 l106 6 0 123 0 124 -147 -1 c-90 0 -164 -5 -188 -13z'),
  (ForjaLetter.a, 'M3720 2020 c0 -477 -1 -491 -54 -525 -14 -10 -55 -20 -91 -23 l-65 -5 0 -113 0 -114 103 0 c232 0 349 96 377 311 7 53 10 237 8 494 l-3 410 -137 3 -138 3 0 -441z'),
];

class ForjaLogoColors {
  const ForjaLogoColors._();

  static const peacock = {
    ForjaLetter.f: Color(0xFF22D3EE),
    ForjaLetter.o: Color(0xFF1CE783),
    ForjaLetter.r: Color(0xFFF472B6),
    ForjaLetter.j: Color(0xFF818CF8),
    ForjaLetter.a: Color(0xFFFBBF24),
  };
}

class ForjaLetterStyle {
  const ForjaLetterStyle({
    required this.color,
    this.opacity = 1,
  });

  final Color color;
  final double opacity;
}

class ForjaLogoHalo {
  const ForjaLogoHalo({
    required this.color,
    required this.centerAlpha,
    required this.midAlpha,
    required this.blurSigma,
    required this.glowSourceSize,
  });

  final Color color;
  final double centerAlpha;
  final double midAlpha;
  final double blurSigma;
  final double glowSourceSize;
}

Path _pathFromSvg(String data) {
  final path = Path();
  writeSvgPathDataToPath(data, _PathProxy(path));
  return path;
}

class _LetterData {
  const _LetterData({
    required this.letter,
    required this.path,
    required this.useEvenOdd,
  });

  final ForjaLetter letter;
  final Path path;
  final bool useEvenOdd;
}

List<_LetterData> _buildLetterData() {
  final grouped = <ForjaLetter, List<Path>>{};
  for (final (letter, data) in _letterPaths) {
    grouped.putIfAbsent(letter, () => []).add(_pathFromSvg(data));
  }

  return forjaLetterOrder.map((letter) {
    final combined = Path();
    for (final path in grouped[letter]!) {
      combined.addPath(path, Offset.zero);
    }
    final useEvenOdd =
        letter == ForjaLetter.o || letter == ForjaLetter.r || letter == ForjaLetter.a;
    if (useEvenOdd) {
      combined.fillType = PathFillType.evenOdd;
    }
    return _LetterData(letter: letter, path: combined, useEvenOdd: useEvenOdd);
  }).toList(growable: false);
}

class ForjaLogo extends StatelessWidget {
  const ForjaLogo({
    super.key,
    required this.width,
    required this.height,
    required this.letterStyles,
    this.halo,
  });

  final double width;
  final double height;
  final Map<ForjaLetter, ForjaLetterStyle> letterStyles;
  final ForjaLogoHalo? halo;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _ForjaLogoPainter(
        letterStyles: letterStyles,
        halo: halo,
      ),
    );
  }
}

class _ForjaLogoPainter extends CustomPainter {
  _ForjaLogoPainter({
    required this.letterStyles,
    this.halo,
  });

  final Map<ForjaLetter, ForjaLetterStyle> letterStyles;
  final ForjaLogoHalo? halo;
  static final _letters = _buildLetterData();

  @override
  void paint(Canvas canvas, Size size) {
    final haloConfig = halo;
    if (haloConfig != null &&
        (haloConfig.centerAlpha > 0 || haloConfig.midAlpha > 0)) {
      final center = Offset(size.width / 2, size.height / 2);
      final radius = haloConfig.glowSourceSize / 2;
      final haloRect = Rect.fromCircle(center: center, radius: radius);
      final haloPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            haloConfig.color.withValues(alpha: haloConfig.centerAlpha),
            haloConfig.color.withValues(alpha: haloConfig.midAlpha),
            haloConfig.color.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(haloRect)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, haloConfig.blurSigma);
      canvas.drawCircle(center, radius, haloPaint);
    }

    final fill = Paint()..style = PaintingStyle.fill;

    canvas.save();
    canvas.scale(size.width / _viewBoxWidth, size.height / _viewBoxHeight);
    canvas.translate(_groupTranslateX, _groupTranslateY);
    canvas.scale(_groupScale, -_groupScale);

    for (final data in _letters) {
      final style = letterStyles[data.letter]!;
      if (style.opacity <= 0) continue;
      fill.color = style.color.withValues(alpha: style.opacity);
      canvas.drawPath(data.path, fill);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ForjaLogoPainter oldDelegate) {
    if (oldDelegate.halo != halo) {
      final a = oldDelegate.halo;
      final b = halo;
      if (a == null || b == null) return true;
      if (a.color != b.color ||
          a.centerAlpha != b.centerAlpha ||
          a.midAlpha != b.midAlpha ||
          a.blurSigma != b.blurSigma ||
          a.glowSourceSize != b.glowSourceSize) {
        return true;
      }
    }
    for (final letter in forjaLetterOrder) {
      final a = letterStyles[letter]!;
      final b = oldDelegate.letterStyles[letter]!;
      if (a.color != b.color || a.opacity != b.opacity) return true;
    }
    return false;
  }
}

class _PathProxy implements PathProxy {
  _PathProxy(this._path);

  final Path _path;

  @override
  void close() => _path.close();

  @override
  void cubicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) {
    _path.cubicTo(x1, y1, x2, y2, x3, y3);
  }

  @override
  void lineTo(double x, double y) => _path.lineTo(x, y);

  @override
  void moveTo(double x, double y) => _path.moveTo(x, y);
}
