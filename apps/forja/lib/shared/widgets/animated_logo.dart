import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:storage/storage.dart';

const splashSlogan = 'THE RAKSHA YOU DESERVE';

const _logoAspectRatio = 370.0 / 160.0;
const _maxLogoHeight = 320.0;

class ForjaLogoColors {
  const ForjaLogoColors({required this.base});

  final Color base;

  static ForjaLogoColors forTheme(bool isLight) {
    if (isLight) {
      return const ForjaLogoColors(base: Color(0xFFE6DCD0));
    }
    return const ForjaLogoColors(base: Color(0xFF1CE783));
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
    final colors = ForjaLogoColors.forTheme(isLight);
    final haloSize = logoHeight * 15;
    final logoAsset = isLight
        ? 'assets/icon/logo-light.png'
        : 'assets/icon/logo-dark.png';

    return SizedBox(
      height: logoHeight,
      child: AspectRatio(
        aspectRatio: _logoAspectRatio,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Center(
                child: SizedBox(
                  width: haloSize,
                  height: haloSize,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          colors.base.withValues(alpha: 0.4),
                          colors.base.withValues(alpha: 0.15),
                          colors.base.withValues(alpha: 0),
                        ],
                        stops: const [0.0, 0.35, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Image.asset(
                logoAsset,
                fit: BoxFit.contain,
                alignment: Alignment.center,
              ),
            ),
          ],
        ),
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
    final logoColors = ForjaLogoColors.forTheme(isLight);

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
