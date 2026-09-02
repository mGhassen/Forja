import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/services/app_version.dart';
import 'package:forja/shared/services/splash_sound.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/forja_logo.dart';

const splashSlogan = 'Relax, look at the sun';

const _logoAspectRatio = forjaLogoAspectRatio;
const _maxLogoHeight = 320.0;
const _haloScale = 4.0;

class LogoColors {
  const LogoColors({required this.base});

  final Color base;

  static const dark = LogoColors(base: Color(0xFF1CE783));
}

class SplashLogoWithHalo extends StatefulWidget {
  const SplashLogoWithHalo({
    super.key,
    required this.logoHeight,
  });

  final double logoHeight;

  @override
  State<SplashLogoWithHalo> createState() => _SplashLogoWithHaloState();
}

class _SplashLogoWithHaloState extends State<SplashLogoWithHalo>
    with SingleTickerProviderStateMixin {
  static const _totalMs = 8500;
  static const _fadeEndMs = 800;
  static const _cycleEndMs = 3500;
  static const _greenStartMs = 3500;
  static const _greenEndMs = 6500;

  static const _palette = [
    Color(0xFF22D3EE),
    Color(0xFF1CE783),
    Color(0xFFF472B6),
    Color(0xFF818CF8),
    Color(0xFFFBBF24),
  ];

  late final AnimationController _controller;
  late final List<(double time, int letterIndex)> _colorChanges;

  @override
  void initState() {
    super.initState();
    _colorChanges = _buildColorSchedule();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _totalMs),
    )..forward();
    SplashSound.instance.play();
  }

  List<(double time, int letterIndex)> _buildColorSchedule() {
    final rnd = math.Random(42);
    final changes = <(double, int)>[];
    var t = 0.0;
    var step = 0;
    while (t < _cycleEndMs) {
      t += 300 + rnd.nextDouble() * 500;
      if (t >= _cycleEndMs) break;
      changes.add((t, step % forjaLetterOrder.length));
      step++;
    }
    return changes;
  }

  double _window(double ms, num start, num end) {
    if (ms <= start) return 0;
    if (ms >= end) return 1;
    return Curves.easeInOutCubic.transform((ms - start) / (end - start));
  }

  Color _cycleColor(int letterIndex, double ms) {
    var idx = letterIndex;
    var prevIdx = idx;
    var lastChangeAt = 0.0;

    for (final (time, li) in _colorChanges) {
      if (time > ms) break;
      if (li == letterIndex) {
        prevIdx = idx;
        idx = (idx + 1) % _palette.length;
        lastChangeAt = time;
      }
    }

    final current = _palette[idx];
    if (lastChangeAt > 0) {
      const crossfadeMs = 280.0;
      final age = ms - lastChangeAt;
      if (age < crossfadeMs) {
        return Color.lerp(
          _palette[prevIdx],
          current,
          Curves.easeInOut.transform(age / crossfadeMs),
        )!;
      }
    }
    return current;
  }

  Map<ForjaLetter, ForjaLetterStyle> _letterStyles(double t, Color baseColor) {
    final ms = t * _totalMs;
    final introFade = Curves.easeOut.transform(_window(ms, 0, _fadeEndMs));
    final greenT = _window(ms, _greenStartMs, _greenEndMs);

    final opacity = introFade *
        (ms < _greenStartMs ? 0.5 + introFade * 0.4 : (0.9 + greenT * 0.1));

    return {
      for (var i = 0; i < forjaLetterOrder.length; i++)
        forjaLetterOrder[i]: ForjaLetterStyle(
          color: ms < _greenStartMs
              ? _cycleColor(i, ms)
              : Color.lerp(_cycleColor(i, _cycleEndMs.toDouble()), baseColor, greenT)!,
          opacity: opacity,
        ),
    };
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const colors = LogoColors.dark;
    final logoWidth = widget.logoHeight * _logoAspectRatio;
    final haloDiameter = widget.logoHeight * _haloScale;
    final blurSigma = haloDiameter * 0.14;
    final glowSourceSize = haloDiameter * 0.38;
    final haloOverflow = haloDiameter + blurSigma * 4;

    return SizedBox(
      width: logoWidth,
      height: widget.logoHeight,
      child: OverflowBox(
        maxWidth: haloOverflow,
        maxHeight: haloOverflow,
        alignment: Alignment.center,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value;
            final ms = t * _totalMs;
            final introFade =
                Curves.easeOut.transform(_window(ms, 0, _fadeEndMs));
            final greenT = _window(ms, _greenStartMs, _greenEndMs);
            final bounce = 1 + math.sin(greenT * math.pi) * 0.035;
            final haloCenterAlpha = 0.18 * introFade;
            final haloMidAlpha = 0.08 * introFade;

            return Transform.scale(
              scale: bounce,
              child: ForjaLogo(
                width: logoWidth,
                height: widget.logoHeight,
                letterStyles: _letterStyles(t, colors.base),
                halo: ForjaLogoHalo(
                  color: colors.base,
                  centerAlpha: haloCenterAlpha,
                  midAlpha: haloMidAlpha,
                  blurSigma: blurSigma,
                  glowSourceSize: glowSourceSize,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class SplashLoadingDots extends StatefulWidget {
  const SplashLoadingDots({super.key, required this.color});

  final Color color;

  @override
  State<SplashLoadingDots> createState() => _SplashLoadingDotsState();
}

class _SplashLoadingDotsState extends State<SplashLoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final phase = (_controller.value + index * 0.2) % 1.0;
            final opacity =
                0.25 + 0.75 * (1 - (phase - 0.5).abs() * 2).clamp(0.0, 1.0);
            return Opacity(opacity: opacity, child: child);
          },
          child: Container(
            width: 7,
            height: 7,
            margin: EdgeInsets.only(left: index == 0 ? 0 : 10),
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
    );
  }
}

class SplashOverlayContent extends StatelessWidget {
  const SplashOverlayContent({
    super.key,
    this.slogan = splashSlogan,
    this.statusLabel,
    this.statusProgress,
    this.onContinueInBackground,
    this.showContinueInBackground = false,
  });

  final String slogan;

  /// Current boot step - shown above the version at the bottom of the splash.
  final String? statusLabel;

  /// Pack install fraction (0–1). Non-null draws a thin bar under the status.
  final double? statusProgress;

  /// When [showContinueInBackground] is true, shows a TV-focusable CTA under
  /// the status (stuck / slow / failed pack download).
  final VoidCallback? onContinueInBackground;
  final bool showContinueInBackground;

  @override
  Widget build(BuildContext context) {
    const logoColors = LogoColors.dark;

    final versionStyle = TextStyle(
      fontSize: 11,
      letterSpacing: 2,
      color: logoColors.base.withValues(alpha: 0.5),
      fontWeight: FontWeight.bold,
    );
    final statusStyle = GoogleFonts.plusJakartaSans(
      fontSize: 12,
      letterSpacing: 0.4,
      color: logoColors.base.withValues(alpha: 0.65),
      decoration: TextDecoration.none,
      fontWeight: FontWeight.w500,
    );

    return SelectionContainer.disabled(
      child: SizedBox.expand(
        child: ColoredBox(
          color: AppTheme.bgDark,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final logoHeight = math.min(
                _maxLogoHeight,
                constraints.maxHeight * 0.38,
              );
              final status = statusLabel?.trim() ?? '';
              final progress = statusProgress;
              final showContinue = showContinueInBackground &&
                  onContinueInBackground != null;
              return Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: OverflowBox(
                      maxWidth: constraints.maxWidth,
                      maxHeight: constraints.maxHeight,
                      alignment: Alignment.center,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        clipBehavior: Clip.none,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SplashLogoWithHalo(
                              logoHeight: logoHeight,
                            ),
                            const SizedBox(height: 20),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              child: DefaultSelectionStyle.merge(
                                selectionColor: Colors.transparent,
                                child: Text(
                                  slogan,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 18,
                                    letterSpacing: 4,
                                    color: logoColors.base,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SplashLoadingDots(color: logoColors.base),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: MediaQuery.paddingOf(context).bottom + 24,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (status.isNotEmpty) ...[
                          Text(
                            status,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: statusStyle,
                          ),
                          if (progress != null) ...[
                            const SizedBox(height: 10),
                            Center(
                              child: SizedBox(
                                width: math.min(220, constraints.maxWidth - 48),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    value: progress.clamp(0.0, 1.0),
                                    minHeight: 3,
                                    backgroundColor:
                                        logoColors.base.withValues(alpha: 0.15),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      logoColors.base.withValues(alpha: 0.75),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (showContinue) ...[
                            const SizedBox(height: 14),
                            SplashContinueInBackgroundButton(
                              onPressed: onContinueInBackground!,
                            ),
                          ],
                          const SizedBox(height: 10),
                        ],
                        AppVersionLabel(
                          style: versionStyle.copyWith(
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Opens the app while pack install keeps running. Autofocuses on TV.
class SplashContinueInBackgroundButton extends StatelessWidget {
  const SplashContinueInBackgroundButton({
    super.key,
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.maybeOf(context)?.inputPolicy ??
        ShellInputPolicy.desktop;
    final tv = policy.useFocusableMoodChips;

    return FocusableControl(
      onTap: onPressed,
      autoFocus: tv,
      showFocusBorder: tv,
      showFocusFill: tv,
      borderRadius: 8,
      scaleOnFocus: tv ? 1.04 : 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Text(
          'Continue in background',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            color: LogoColors.dark.base,
            fontSize: tv ? 15 : 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

/// Small looping logo for empty states — no splash sound, no one-shot timeline.
class ForjaLogoIdle extends StatefulWidget {
  const ForjaLogoIdle({
    super.key,
    this.logoHeight = 88,
  });

  final double logoHeight;

  @override
  State<ForjaLogoIdle> createState() => _ForjaLogoIdleState();
}

class _ForjaLogoIdleState extends State<ForjaLogoIdle>
    with SingleTickerProviderStateMixin {
  static const _palette = [
    Color(0xFF22D3EE),
    Color(0xFF1CE783),
    Color(0xFFF472B6),
    Color(0xFF818CF8),
    Color(0xFFFBBF24),
  ];

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _letterColor(int letterIndex, double t) {
    final phase = (t + letterIndex * 0.11) % 1.0;
    final scaled = phase * _palette.length;
    final idx = scaled.floor() % _palette.length;
    final next = (idx + 1) % _palette.length;
    final mix = scaled - scaled.floor();
    return Color.lerp(_palette[idx], _palette[next], mix)!;
  }

  @override
  Widget build(BuildContext context) {
    const colors = LogoColors.dark;
    final logoWidth = widget.logoHeight * _logoAspectRatio;
    final haloDiameter = widget.logoHeight * _haloScale;
    final blurSigma = haloDiameter * 0.14;
    final glowSourceSize = haloDiameter * 0.38;
    final haloOverflow = haloDiameter + blurSigma * 4;

    return SizedBox(
      width: logoWidth,
      height: widget.logoHeight,
      child: OverflowBox(
        maxWidth: haloOverflow,
        maxHeight: haloOverflow,
        alignment: Alignment.center,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value;
            final pulse = 1 + math.sin(t * math.pi * 2) * 0.028;
            final haloAlpha = 0.12 + math.sin(t * math.pi * 2) * 0.04;

            return Transform.scale(
              scale: pulse,
              child: ForjaLogo(
                width: logoWidth,
                height: widget.logoHeight,
                letterStyles: {
                  for (var i = 0; i < forjaLetterOrder.length; i++)
                    forjaLetterOrder[i]: ForjaLetterStyle(
                      color: _letterColor(i, t),
                      opacity: 0.92,
                    ),
                },
                halo: ForjaLogoHalo(
                  color: colors.base,
                  centerAlpha: haloAlpha,
                  midAlpha: haloAlpha * 0.45,
                  blurSigma: blurSigma,
                  glowSourceSize: glowSourceSize,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
