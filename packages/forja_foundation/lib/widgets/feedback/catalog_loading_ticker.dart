import 'package:flutter/material.dart';
import 'package:forja_foundation/components/spinner.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centered catalog load ticker — spinner + title + step detail.
///
/// Pre-wipe IPTV shelf load (not a card skeleton grid).
class CatalogLoadingTicker extends StatelessWidget {
  const CatalogLoadingTicker({
    super.key,
    required this.title,
    required this.detail,
  });

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Spinner(size: SpinnerSize.lg),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: ForjaShellColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              if (detail.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  detail,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white54,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
