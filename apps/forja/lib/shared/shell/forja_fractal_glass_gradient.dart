import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Params from [fractal-glass-gradients](https://github.com/franky-adl/fractal-glass-gradients)
/// Leva controls (`Experience.jsx`): Pattern, Palette, Algo, noise, warp, grain, flute, brightness.
class FractalGlassParams {
  const FractalGlassParams({
    this.pattern = FractalGlassPattern.balanced,
    this.noiseScaleX = 4.0,
    this.noiseScaleY = 0.75,
    this.warpStrength = 0.26,
    this.warpSpeed = 0.21,
    this.grainStrength = 0.67,
    /// Logical px per flute. Edit THIS (or [forTv]) - not only a leftover default.
    this.fluteWidth = 33,
    this.fluteStrength = 114,
    this.patternBrightness = 0.56,
    this.algo = FractalGlassAlgo.blobs,
    this.palette = FractalGlassPalette.neonFlux,
  });

  /// Builds params from the repo **Pattern** preset (sets noise + warp + algo).
  factory FractalGlassParams.fromPattern(
    FractalGlassPattern pattern, {
    FractalGlassPalette palette = FractalGlassPalette.neonFlux,
    double warpSpeed = 0.21,
    double grainStrength = 0.67,
    double fluteWidth = 33,
    double fluteStrength = 114,
    double patternBrightness = 0.56,
  }) {
    return switch (pattern) {
      FractalGlassPattern.balanced => FractalGlassParams(
          pattern: pattern,
          noiseScaleX: 4.0,
          noiseScaleY: 0.75,
          warpStrength: 0.26,
          warpSpeed: warpSpeed,
          grainStrength: grainStrength,
          fluteWidth: fluteWidth,
          fluteStrength: fluteStrength,
          patternBrightness: patternBrightness,
          algo: FractalGlassAlgo.blobs,
          palette: palette,
        ),
      FractalGlassPattern.flowLike => FractalGlassParams(
          pattern: pattern,
          noiseScaleX: 0.35,
          noiseScaleY: 0.55,
          warpStrength: 0.4,
          warpSpeed: warpSpeed,
          grainStrength: grainStrength,
          fluteWidth: fluteWidth,
          fluteStrength: fluteStrength,
          patternBrightness: patternBrightness,
          algo: FractalGlassAlgo.ellipses,
          palette: palette,
        ),
    };
  }

  /// Repo Pattern **Flow-like** (Experience.jsx PRESETS).
  static const flowLike = FractalGlassParams(
    pattern: FractalGlassPattern.flowLike,
    noiseScaleX: 0.35,
    noiseScaleY: 0.55,
    warpStrength: 0.4,
    warpSpeed: 0.12,
    grainStrength: 0.5,
    fluteWidth: 70,
    fluteStrength: 140,
    patternBrightness: 0.9,
    algo: FractalGlassAlgo.ellipses,
    palette: FractalGlassPalette.neonFlux,
  );

  /// Demo screenshot look (Balanced + Neon Flux + Algo1).
  /// Same object as the constructor defaults - edit the constructor fields above.
  static const balanced = FractalGlassParams();

  /// TV auth background. **This is what the app uses.** Same as constructor defaults.
  static const forTv = FractalGlassParams();

  /// Repo Leva **Pattern** (`patternPreset`: Balanced | Flow-like).
  final FractalGlassPattern pattern;

  final double noiseScaleX;
  final double noiseScaleY;
  final double warpStrength;
  final double warpSpeed;
  final double grainStrength;

  /// Flute period in logical px (repo: 5–200). Live on TV via [forTv]/[FractalGlassParams.new].
  final double fluteWidth;

  /// Horizontal refraction amount (repo: 0–200).
  final double fluteStrength;

  /// Repo `patternBrightness` / `uToneMapExposure`.
  final double patternBrightness;
  final FractalGlassAlgo algo;
  final FractalGlassPalette palette;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FractalGlassParams &&
          pattern == other.pattern &&
          noiseScaleX == other.noiseScaleX &&
          noiseScaleY == other.noiseScaleY &&
          warpStrength == other.warpStrength &&
          warpSpeed == other.warpSpeed &&
          grainStrength == other.grainStrength &&
          fluteWidth == other.fluteWidth &&
          fluteStrength == other.fluteStrength &&
          patternBrightness == other.patternBrightness &&
          algo == other.algo &&
          palette == other.palette;

  @override
  int get hashCode => Object.hash(
        pattern,
        noiseScaleX,
        noiseScaleY,
        warpStrength,
        warpSpeed,
        grainStrength,
        fluteWidth,
        fluteStrength,
        patternBrightness,
        algo,
        palette,
      );
}

/// Repo Leva control **Pattern** (`PRESETS` in Experience.jsx).
enum FractalGlassPattern {
  /// `Balanced` → Algo1 blobs; demo screenshot uses noise ~4.0×0.75.
  balanced,

  /// `Flow-like` → Algo2 ellipses, noise 0.35×0.55, warp 0.4.
  flowLike,
}

enum FractalGlassAlgo {
  /// Repo Algo1 - circular Gaussian blobs.
  blobs,

  /// Repo Algo2 - elliptical Gaussians (Flow-like).
  ellipses,
}

/// Palettes: repo 5-stops, Neon Flux adds Forja green + amber (7).
enum FractalGlassPalette { neonFlux, sunset, aurora, forja }

extension on FractalGlassPalette {
  /// RGB 0–1 triples. Shader always reads 7 stops; shorter lists pad with black.
  List<(double, double, double)> get colors => switch (this) {
    FractalGlassPalette.neonFlux => const [
      (0.02, 0.2, 0.75),
      (0.8, 0.05, 0.55),
      (0.95, 0.1, 0.15),
      (0.97, 0.48, 0.08),
      (0.2, 0.65, 0.88),
      (0.110, 0.906, 0.514), // Forja brand green #1CE783
      (0.984, 0.749, 0.141), // Forja logo amber #FBBF24
    ],
    FractalGlassPalette.sunset => const [
      (0.95, 0.25, 0.05),
      (0.85, 0.08, 0.35),
      (1.0, 0.6, 0.0),
      (0.55, 0.05, 0.5),
      (1.0, 0.85, 0.2),
    ],
    FractalGlassPalette.aurora => const [
      (0.0, 0.75, 0.45),
      (0.05, 0.45, 0.95),
      (0.55, 0.05, 0.85),
      (0.0, 0.9, 0.7),
      (0.3, 0.0, 0.65),
    ],
    FractalGlassPalette.forja => const [
      (0.04, 0.35, 0.32),
      (0.11, 0.91, 0.51),
      (0.85, 1.0, 0.35),
      (1.0, 0.72, 0.29),
      (0.91, 0.29, 0.16),
    ],
  };
}

/// Full-screen animated fractal glass background (GPU fragment shader).
class FractalGlassGradient extends StatefulWidget {
  const FractalGlassGradient({
    super.key,
    this.params = FractalGlassParams.flowLike,
  });

  final FractalGlassParams params;

  @override
  State<FractalGlassGradient> createState() => _FractalGlassGradientState();
}

class _FractalGlassGradientState extends State<FractalGlassGradient>
    with SingleTickerProviderStateMixin {
  static const _shaderAsset = 'shaders/fractal_glass.frag';
  static const _grainAsset = 'assets/textures/film_grain_contrasted.jpg';

  ui.FragmentShader? _shader;
  ui.Image? _grain;
  late final AnimationController _tick;
  final Stopwatch _clock = Stopwatch();

  @override
  void initState() {
    super.initState();
    // Continuous vsync listenable - CustomPainter.repaint must hear every frame.
    _tick = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _clock.start();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final program = await ui.FragmentProgram.fromAsset(_shaderAsset);
      final data = await rootBundle.load(_grainAsset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() {
        _shader = program.fragmentShader();
        _grain = frame.image;
      });
    } catch (_) {
      // Keep solid fallback background.
    }
  }

  @override
  void dispose() {
    _tick.dispose();
    _shader?.dispose();
    _grain?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shader = _shader;
    final grain = _grain;
    if (shader == null || grain == null) {
      return const ColoredBox(color: Color(0xFF030708));
    }

    // Paint to parent constraints (Positioned.fill). FlutterFragCoord matches this box in logical px.
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return CustomPaint(
          size: size,
          painter: _FractalGlassPainter(
            shader: shader,
            grain: grain,
            params: widget.params,
            clock: _clock,
            repaint: _tick,
          ),
        );
      },
    );
  }
}

class _FractalGlassPainter extends CustomPainter {
  _FractalGlassPainter({
    required this.shader,
    required this.grain,
    required this.params,
    required this.clock,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final ui.FragmentShader shader;
  final ui.Image grain;
  final FractalGlassParams params;
  final Stopwatch clock;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final timeSeconds = clock.elapsedMicroseconds / 1e6;

    var i = 0;
    void f(double v) => shader.setFloat(i++, v);
    void v2(double x, double y) {
      f(x);
      f(y);
    }

    void v3(double x, double y, double z) {
      f(x);
      f(y);
      f(z);
    }

    // Logical paint size - must match FlutterFragCoord space.
    v2(size.width, size.height);
    f(1.0); // uPixelRatio unused (kept for uniform layout); coords are already logical
    f(timeSeconds);
    f(params.warpStrength);
    f(params.noiseScaleX);
    f(params.noiseScaleY);
    f(params.warpSpeed);
    f(params.grainStrength);
    f(params.fluteWidth);
    f(params.fluteStrength);
    f(params.patternBrightness);
    f(params.algo == FractalGlassAlgo.blobs ? 0.0 : 1.0);
    // Shader expects 7 vec3 stops; pad shorter palettes with black (no contrib).
    const pad = (0.0, 0.0, 0.0);
    final stops = [...params.palette.colors, pad, pad, pad, pad, pad, pad, pad]
        .take(7);
    for (final c in stops) {
      v3(c.$1, c.$2, c.$3);
    }
    shader.setImageSampler(0, grain);

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _FractalGlassPainter old) =>
      old.params != params || old.grain != grain || old.shader != shader;
}
