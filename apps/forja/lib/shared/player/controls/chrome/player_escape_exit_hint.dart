import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

/// Top-right toast while player exit is armed (second Esc / Back / Exit leaves).
class PlayerEscapeExitHint extends StatelessWidget {
  const PlayerEscapeExitHint({
    super.key,
    this.message = 'Press Esc again to exit',
  });

  /// Android TV — Back and Exit share the player leave ladder.
  const PlayerEscapeExitHint.tv({super.key})
      : message = 'Press again to exit';

  final String message;

  @override
  Widget build(BuildContext context) {
    final tv = ShellPaintScope.usesTvDensityOf(context);
    return Positioned(
      top: tv ? 10 : 16,
      right: tv ? 10 : 16,
      child: IgnorePointer(
        child: SafeArea(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: tv ? 10 : 14,
                vertical: tv ? 6 : 10,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(tv ? 6 : 10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.14),
                ),
              ),
              child: Text(
                message,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: tv
                      ? ShellTokens.playerChromeStatusFontSizeTv
                      : ShellTokens.playerChromeStatusFontSize,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
