import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shared/design/src/forja_buttons.dart';
import 'package:forja/shared/design/src/forja_shell_colors.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';
import 'package:rust/rust.dart';

/// Compact TMDB watch-provider strip — first row of the search keyboard column.
class SearchProviderRow extends StatefulWidget {
  const SearchProviderRow({super.key, this.onProviderChanged});

  final ValueChanged<int?>? onProviderChanged;

  @override
  State<SearchProviderRow> createState() => _SearchProviderRowState();
}

class _SearchProviderRowState extends State<SearchProviderRow> {
  final TmdbApi _api = TmdbApi();
  late Future<List<WatchProvider>> _providersFuture;

  @override
  void initState() {
    super.initState();
    _providersFuture = _api.getTopWatchProviders();
  }

  void _onTap(int providerId) {
    final current = ShellBus.selectedWatchProviderId.value;
    final next = current == providerId ? null : providerId;
    ShellBus.selectedWatchProviderId.value = next;
    widget.onProviderChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: ShellTokens.searchProviderRowHeight,
      child: FutureBuilder<List<WatchProvider>>(
        future: _providersFuture,
        builder: (context, snapshot) {
          final providers = snapshot.data ?? TmdbApi.fallbackWatchProviders;
          return ValueListenableBuilder<int?>(
            valueListenable: ShellBus.selectedWatchProviderId,
            builder: (context, selectedId, _) {
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: providers.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final provider = providers[index];
                  final isActive = selectedId == provider.id;
                  return _ProviderChip(
                    provider: provider,
                    isActive: isActive,
                    onTap: () => _onTap(provider.id),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _ProviderChip extends StatelessWidget {
  const _ProviderChip({
    required this.provider,
    required this.isActive,
    required this.onTap,
  });

  final WatchProvider provider;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const w = ShellTokens.searchProviderCardWidth;
    const h = ShellTokens.searchProviderCardHeight;

    return ForjaInteractive(
      onTap: onTap,
      hoverScale: 1.04,
      builder: (hover, _) {
        return AnimatedContainer(
          duration: ShellTokens.navSelectionAnimation,
          width: w,
          height: h,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: ForjaShellColors.surfaceElevated,
            borderRadius: BorderRadius.circular(ShellTokens.shellProviderCardRadius),
            border: Border.all(
              color: isActive || hover ? Colors.white : ForjaShellColors.borderSubtle,
              width: isActive || hover ? 2 : 1,
            ),
            image: provider.logoPath.isNotEmpty
                ? DecorationImage(
                    image: CachedNetworkImageProvider(provider.logoCardUrl),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: provider.logoPath.isEmpty
              ? Center(
                  child: Text(
                    provider.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: ForjaShellColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }
}
