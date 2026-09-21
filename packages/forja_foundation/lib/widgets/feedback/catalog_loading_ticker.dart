import 'package:flutter/material.dart';
import 'package:forja_foundation/components/spinner.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
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
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final maxW = tv
        ? ShellTokens.catalogLoadingTickerMaxWidthTv
        : ShellTokens.catalogLoadingTickerMaxWidth;
    final padH = tv
        ? ShellTokens.catalogLoadingTickerPadHTv
        : ShellTokens.catalogLoadingTickerPadH;
    final padV = tv
        ? ShellTokens.catalogLoadingTickerPadVTv
        : ShellTokens.catalogLoadingTickerPadV;
    final gap = tv
        ? ShellTokens.catalogLoadingTickerGapTv
        : ShellTokens.catalogLoadingTickerGap;
    final detailGap = tv
        ? ShellTokens.catalogLoadingTickerDetailGapTv
        : ShellTokens.catalogLoadingTickerDetailGap;
    final titleSize = tv
        ? ShellTokens.catalogLoadingTickerTitleFontSizeTv
        : ShellTokens.catalogLoadingTickerTitleFontSize;
    final detailSize = tv
        ? ShellTokens.catalogLoadingTickerDetailFontSizeTv
        : ShellTokens.catalogLoadingTickerDetailFontSize;
    final spinner = tv
        ? ShellTokens.catalogLoadingTickerSpinnerTv
        : ShellTokens.catalogLoadingTickerSpinner;
    final stroke = tv
        ? ShellTokens.catalogLoadingTickerStrokeTv
        : ShellTokens.catalogLoadingTickerStroke;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Spinner(
                size: SpinnerSize.lg,
                strokeWidth: stroke,
                dimension: spinner,
              ),
              SizedBox(height: gap),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: ForjaShellColors.textPrimary,
                  fontSize: titleSize,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              if (detail.trim().isNotEmpty) ...[
                SizedBox(height: detailGap),
                Text(
                  detail,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white54,
                    fontSize: detailSize,
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
