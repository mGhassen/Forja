import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/widgets/forja_logo.dart';

void main() {
  testWidgets('forja logo halo paints green glow pixels', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const key = Key('halo_probe');
    const logoHeight = 160.0;
    const logoWidth = logoHeight * forjaLogoAspectRatio;
    const haloDiameter = logoHeight * 4.0;
    const blurSigma = haloDiameter * 0.14;
    const glowSourceSize = haloDiameter * 0.38;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF141414),
          body: Center(
            child: RepaintBoundary(
              key: key,
              child: ForjaLogo(
                width: logoWidth,
                height: logoHeight,
                letterStyles: {
                  for (final letter in forjaLetterOrder)
                    letter: const ForjaLetterStyle(
                      color: Color(0xFF1CE783),
                      opacity: 1,
                    ),
                },
                halo: const ForjaLogoHalo(
                  color: Color(0xFF1CE783),
                  centerAlpha: 0.18,
                  midAlpha: 0.08,
                  blurSigma: blurSigma,
                  glowSourceSize: glowSourceSize,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(key),
    );
    final image = await boundary.toImage(pixelRatio: 1.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    expect(bytes, isNotNull);

    final center = Offset(image.width / 2, image.height / 2);
    final above = _pixelBrightness(bytes!, image.width, center.dx, center.dy - 40);
    final below = _pixelBrightness(bytes, image.width, center.dx, center.dy + 40);
    final background = _pixelBrightness(bytes, image.width, 4, 4);

    expect(above, greaterThan(background + 8));
    expect(below, greaterThan(background + 8));
  });
}

double _pixelBrightness(ByteData bytes, int width, double x, double y) {
  final px = x.round().clamp(0, width - 1);
  final py = y.round().clamp(0, (bytes.lengthInBytes ~/ 4 ~/ width) - 1);
  final offset = (py * width + px) * 4;
  final r = bytes.getUint8(offset.toInt());
  final g = bytes.getUint8(offset.toInt() + 1);
  final b = bytes.getUint8(offset.toInt() + 2);
  return (r + g + b) / 3.0;
}
