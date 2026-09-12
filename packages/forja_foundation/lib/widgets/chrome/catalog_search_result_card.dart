import 'package:flutter/material.dart';
import 'package:forja_foundation/components/settled_network_image.dart';
import 'package:forja_foundation/theme/forja_theme_extension.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

/// Search result card paint — film (wide grid) or compact poster.
///
/// Host injects TV / focus via [interactiveBuilder].
class CatalogSearchResultCard extends StatelessWidget {
  const CatalogSearchResultCard.film({
    super.key,
    required this.title,
    required this.posterUrl,
    this.subtitle,
    this.rating,
    this.selected = false,
    this.titleFontSize,
    this.onTap,
    this.interactiveBuilder,
  })  : compact = false,
        compactWidth = null;

  const CatalogSearchResultCard.compact({
    super.key,
    required this.title,
    required this.posterUrl,
    this.subtitle,
    this.rating,
    this.titleFontSize,
    this.compactWidth,
    this.onTap,
    this.interactiveBuilder,
  })  : compact = true,
        selected = false;

  final String title;
  final String posterUrl;
  final String? subtitle;
  final double? rating;
  final bool selected;
  final bool compact;
  final double? titleFontSize;
  final double? compactWidth;
  final VoidCallback? onTap;
  final Widget Function({
    required Widget child,
    required VoidCallback onTap,
  })? interactiveBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = ForjaThemeExtension.of(context);
    final child = compact
        ? _compactBody(context, theme)
        : _filmBody(context, theme);
    final tap = onTap ?? () {};
    final wrap = interactiveBuilder;
    if (wrap != null) {
      return wrap(child: child, onTap: tap);
    }
    return GestureDetector(onTap: onTap, child: child);
  }

  Widget _filmBody(BuildContext context, ForjaThemeExtension theme) {
    final size = titleFontSize ?? 13.0;
    return SizedBox.expand(
      child: AnimatedContainer(
        duration: ShellTokens.navSelectionAnimation,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: selected ? Border.all(color: Colors.white, width: 2) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: selected ? 0.65 : 0.5),
              blurRadius: selected ? 20 : 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: theme.bgDark,
                child: posterUrl.isNotEmpty
                    ? SettledNetworkImage(
                        imageUrl: posterUrl,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.medium,
                        errorWidget: Center(
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white24,
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white24,
                          ),
                        ),
                      ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                      Colors.black.withValues(alpha: 0.95),
                    ],
                    stops: const [0.0, 0.45, 0.8, 1.0],
                  ),
                ),
              ),
              if (rating != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 12,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          rating!.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Positioned(
                bottom: 10,
                left: 10,
                right: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: size,
                        height: 1.2,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _compactBody(BuildContext context, ForjaThemeExtension theme) {
    final cardWidth = compactWidth ?? ShellTokens.searchCardWidthCompact;
    final cardHeight = cardWidth * 1.5;
    final bgCard = theme.surfaceElevated;

    return Container(
      width: cardWidth,
      height: cardHeight,
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (posterUrl.isNotEmpty)
            SettledNetworkImage(
              imageUrl: posterUrl,
              fit: BoxFit.cover,
              errorWidget: const Center(
                child: Icon(Icons.broken_image, color: Colors.white24),
              ),
            )
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          if (rating != null)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  rating!.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading placeholder for search result grids.
class CatalogSearchSkeletonCard extends StatelessWidget {
  const CatalogSearchSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withValues(alpha: 0.06),
        ),
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}
