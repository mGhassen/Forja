import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:storage/storage.dart';

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
      child: Column(
        children: [
          Expanded(
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
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 48),
            child: Text(
              'INITIALIZING ENGINE...',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
                color: isLight ? Colors.black38 : Colors.white38,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
