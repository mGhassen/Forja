import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:forja/shell/core/forja_shell_input_policy.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shared/services/update/app_version.dart';
import 'package:forja/shared/services/app/splash_sound.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja_foundation/brand/animated_logo.dart';

export 'package:forja_foundation/brand/animated_logo.dart';

const _maxLogoHeight = 320.0;

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
                              onAppear: () => SplashSound.instance.play(),
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
