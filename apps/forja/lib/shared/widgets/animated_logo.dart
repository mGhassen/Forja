import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:forja/shared/theme/app_theme.dart';

const splashSlogan = 'THE RAKSHA YOU DESERVE';

const _logoAspectRatio = 370.0 / 160.0;
const _maxLogoHeight = 320.0;
const _haloScale = 4.0;

class LogoColors {
  const LogoColors({required this.base});

  final Color base;

  static LogoColors forTheme(bool isLight) {
    if (isLight) {
      return const LogoColors(base: Color(0xFFE6DCD0));
    }
    return const LogoColors(base: Color(0xFF1CE783));
  }
}

class SplashLogoWithHalo extends StatelessWidget {
  const SplashLogoWithHalo({
    super.key,
    required this.logoHeight,
    required this.isLight,
  });

  final double logoHeight;
  final bool isLight;

  @override
  Widget build(BuildContext context) {
    final colors = LogoColors.forTheme(isLight);
    final logoWidth = logoHeight * _logoAspectRatio;
    final haloDiameter = logoHeight * _haloScale;
    final blurSigma = haloDiameter * 0.14;
    final glowSourceSize = haloDiameter * 0.38;
    final logoAsset = isLight
        ? 'assets/icon/logo-light.png'
        : 'assets/icon/logo-dark.png';

    return SizedBox(
      width: logoWidth,
      height: logoHeight,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          OverflowBox(
            maxWidth: haloDiameter + blurSigma * 4,
            maxHeight: haloDiameter + blurSigma * 4,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: blurSigma,
                sigmaY: blurSigma,
              ),
              child: Container(
                width: glowSourceSize,
                height: glowSourceSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      colors.base.withValues(alpha: isLight ? 0.28 : 0.22),
                      colors.base.withValues(alpha: isLight ? 0.12 : 0.1),
                      colors.base.withValues(alpha: 0),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: logoWidth,
            height: logoHeight,
            child: Image.asset(
              logoAsset,
              fit: BoxFit.contain,
              alignment: Alignment.center,
            ),
          ),
        ],
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
            final opacity = 0.25 + 0.75 * (1 - (phase - 0.5).abs() * 2).clamp(0.0, 1.0);
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
    required this.isLight,
    this.slogan = splashSlogan,
  });

  final bool isLight;
  final String slogan;

  @override
  Widget build(BuildContext context) {
    final logoColors = LogoColors.forTheme(isLight);

    return Container(
      decoration: AppTheme.backgroundDecoration,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final logoHeight = math.min(
            _maxLogoHeight,
            constraints.maxHeight * 0.38,
          );
          return Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              clipBehavior: Clip.none,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SplashLogoWithHalo(
                    logoHeight: logoHeight,
                    isLight: isLight,
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      slogan,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        letterSpacing: 4,
                        color: logoColors.base,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SplashLoadingDots(color: logoColors.base),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
