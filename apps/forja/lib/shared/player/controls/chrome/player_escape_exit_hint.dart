import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

/// Top-right toast while exit is armed (second Back / Esc leaves).
class PlayerEscapeExitHint extends StatelessWidget {
  const PlayerEscapeExitHint({super.key, this.message});

  /// Defaults to Back copy on TV density, Esc copy elsewhere.
  final String? message;

  static const backMessage = 'Press Back again to exit';
  static const escMessage = 'Press Esc again to exit';

  @override
  Widget build(BuildContext context) {
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final text = message ?? (tv ? backMessage : escMessage);
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
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: Text(
                text,
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
