import 'package:flutter/material.dart';
import 'package:forja_foundation/components/crossfade_swap.dart';
import 'package:forja_foundation/components/network_image.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/utils/cover_urls.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja_foundation/widgets/catalog/interactive_poster_card.dart';
import 'package:forja_foundation/widgets/catalog/poster_rail.dart';

/// Because-you-watched row paint — props only (RFC-106 Zone A).
///
/// Host loads rail items / shuffle; this paints seed + title + [PosterRail].
class BecauseSection extends StatelessWidget {
  const BecauseSection({
    super.key,
    this.title,
    this.becauseTitle,
    this.seedPosterUrl,
    this.items,
    this.children,
    this.rail,
    this.trailing,
    this.titlePadding,
    this.cardWidth,
    this.cardHeight,
    this.gap,
    this.kickerFontSize,
    this.titleFontSize,
    this.seeAllFontSize,
    this.onSeeAll,
  }) : assert(items != null || children != null || rail != null);

  /// Full section heading. When null, built from [becauseTitle].
  final String? title;

  /// Source title for “Because you watched …”.
  final String? becauseTitle;

  /// Optional seed poster beside the heading.
  final String? seedPosterUrl;

  final List<PosterItem>? items;
  final List<Widget>? children;

  /// Full rail widget (host [KitSection]). Wins over [items]/[children].
  final Widget? rail;

  final Widget? trailing;
  final EdgeInsetsGeometry? titlePadding;

  /// Poster rail card size / gap — omit → [PosterRail] defaults.
  final double? cardWidth;
  final double? cardHeight;
  final double? gap;
  final double? kickerFontSize;
  final double? titleFontSize;
  final double? seeAllFontSize;
  final VoidCallback? onSeeAll;

  String get _seedTitle {
    if (becauseTitle != null && becauseTitle!.trim().isNotEmpty) {
      return becauseTitle!.trim();
    }
    const prefix = 'Because you watched ';
    final trimmed = (title ?? '').trim();
    if (trimmed.startsWith(prefix)) {
      return trimmed.substring(prefix.length).trim();
    }
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final themeSeed = _seedTitle;
    final seedUrl = resolveAbsoluteCoverUrl(seedPosterUrl ?? '');
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final kickerFontSize =
        this.kickerFontSize ?? (tv ? ShellTokens.tvMetaFontSize : 11.5);
    final titleFontSize =
        this.titleFontSize ?? (tv ? ShellTokens.tvTitleFontSize : 19.0);
    final seeAllFontSize =
        this.seeAllFontSize ?? (tv ? ShellTokens.tvBodyFontSize : 13.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: titlePadding ?? EdgeInsets.zero,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _BecauseSeedPoster(url: seedUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Because you watched',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: kickerFontSize,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    CrossfadeSwap(
                      child: Text(
                        themeSeed.isEmpty ? 'recently' : themeSeed,
                        key: ValueKey(
                          themeSeed.isEmpty ? 'recently' : themeSeed,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ?trailing,
              if (onSeeAll != null)
                GestureDetector(
                  onTap: onSeeAll,
                  child: Text(
                    'See all',
                    style: TextStyle(
                      color: ForjaShellColors.textSecondary,
                      fontSize: seeAllFontSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (rail != null)
          rail!
        else
          PosterRail(
            items: children == null ? items : null,
            itemWidth:
                cardWidth ?? InteractivePosterCard.cardWidth(context),
            itemHeight:
                cardHeight ?? InteractivePosterCard.cardHeight(context),
            gap: gap,
            children: children,
          ),
      ],
    );
  }
}

class _BecauseSeedPoster extends StatelessWidget {
  const _BecauseSeedPoster({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 50,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: ForjaShellColors.surfaceElevated,
        border: Border.all(
          color: ForjaShellColors.borderSubtle,
          width: 1.2,
        ),
      ),
      child: url.isEmpty
          ? const Icon(Icons.movie_outlined, color: Colors.white38, size: 18)
          : ForjaNetworkImage(
              url: url,
              fit: BoxFit.cover,
              placeholder: ColoredBox(color: ForjaShellColors.surfaceElevated),
              error: ColoredBox(color: ForjaShellColors.surfaceElevated),
            ),
    );
  }
}
