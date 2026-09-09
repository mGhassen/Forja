import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
    return Positioned(
      top: 16,
      right: 16,
      child: IgnorePointer(
        child: SafeArea(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.14),
                ),
              ),
              child: Text(
                message,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 13,
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
