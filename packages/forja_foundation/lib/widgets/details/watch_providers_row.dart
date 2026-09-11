import 'package:flutter/material.dart';

class WatchProviderTile {
  const WatchProviderTile({required this.name, required this.logoUrl});

  final String name;
  final String logoUrl;
}

/// Watch-provider logos on a details hero. Host maps rust `WatchProvider`.
class HeroWatchProvidersRow extends StatelessWidget {
  const HeroWatchProvidersRow({
    super.key,
    required this.providers,
    this.maxVisible = 8,
    this.visible = true,
  });

  final List<WatchProviderTile> providers;
  final int maxVisible;
  final bool visible;

  static const double tileSize = 40;
  static const double tileGap = 8;
  static const double rowHeight = tileSize;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    final shown = providers
        .where((p) => p.logoUrl.trim().isNotEmpty)
        .take(maxVisible)
        .toList();
    if (shown.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: rowHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        itemCount: shown.length,
        separatorBuilder: (_, _) => const SizedBox(width: tileGap),
        itemBuilder: (context, index) {
          final provider = shown[index];
          return Tooltip(
            message: provider.name,
            child: Semantics(
              label: provider.name,
              child: SizedBox(
                width: tileSize,
                height: tileSize,
                child: Image.network(
                  provider.logoUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Text(
                    provider.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
