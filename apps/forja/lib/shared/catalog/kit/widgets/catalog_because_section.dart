import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/catalog/filter.dart';
import 'package:forja/shared/catalog/kit/meta/catalog_meta_movie.dart';
import 'package:forja/shared/catalog/kit/cards/hub_poster_card.dart';
import 'package:forja/shared/catalog/kit/chrome/catalog_chrome_filters.dart';
import 'package:forja/shared/catalog/kit/rows/catalog_row_prefetch.dart';
import 'package:forja/shared/catalog/kit/rows/hub_catalog_section.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/catalog/runtime.dart';
import 'package:forja/shared/catalog/services/catalog_watch_history.dart';
import 'package:forja/shared/catalog/shell/catalog_open.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/home_loading_skeleton.dart';

/// Layout widget type `because` — pack owns rail logic; host renders meta rows.
class CatalogBecauseSection extends StatefulWidget {
  const CatalogBecauseSection({
    super.key,
    required this.pluginId,
    required this.tabId,
    required this.spec,
    this.tvRowOrder = 0,
    this.prefetchSlot,
  });

  final String pluginId;
  final String tabId;
  final Map<String, dynamic> spec;
  final int tvRowOrder;
  final CatalogHubRowPrefetchSlot? prefetchSlot;

  @override
  State<CatalogBecauseSection> createState() => _CatalogBecauseSectionState();
}

class _CatalogBecauseSectionState extends State<CatalogBecauseSection> {
  Future<_BecausePayload>? _future;
  int _shuffleKey = 0;
  int _epoch = 0;
  bool _viewportActivated = false;

  @override
  void initState() {
    super.initState();
    _registerPrefetch();
    CatalogWatchHistory.revision.addListener(_onHistoryRevision);
  }

  void _onHistoryRevision() {
    if (_viewportActivated) _reload();
  }

  void _onViewportVisible() {
    _activate(prefetch: false);
  }

  void _registerPrefetch() {
    final slot = widget.prefetchSlot;
    if (slot == null) return;
    slot.lane.register(slot.index, () => _activate(prefetch: true));
  }

  void _activate({required bool prefetch}) {
    if (_viewportActivated) {
      if (!prefetch) widget.prefetchSlot?.notifyVisible();
      return;
    }
    setState(() => _viewportActivated = true);
    _reload();
    widget.prefetchSlot?.notifyVisible();
  }

  @override
  void dispose() {
    CatalogWatchHistory.revision.removeListener(_onHistoryRevision);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CatalogBecauseSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.prefetchSlot != null) {
      _registerPrefetch();
    }
    if (oldWidget.spec != widget.spec ||
        oldWidget.pluginId != widget.pluginId ||
        oldWidget.tabId != widget.tabId) {
      _reload();
    }
  }

  void _reload() {
    final epoch = ++_epoch;
    setState(() {
      _future = _load().then((payload) {
        if (!mounted || epoch != _epoch) return const _BecausePayload.empty();
        return payload;
      });
    });
  }

  Future<_BecausePayload> _load() async {
    final rawParams = widget.spec['params'];
    final params = <String, dynamic>{
      if (rawParams is Map) ...Map<String, dynamic>.from(rawParams),
      'rail': (widget.spec['rail'] ?? 'because').toString(),
      'shuffleKey': _shuffleKey,
      'resumeSeeds': await catalogResumeSeeds(widget.pluginId),
    };
    final envelope = await CatalogRuntime.instance.run(
      pluginId: widget.pluginId,
      action: (widget.spec['action'] ?? 'rail').toString().trim(),
      params: catalogParamsWithFilters(
        params,
        filters: catalogChromeFilters(
          tabId: widget.tabId,
          pluginId: widget.pluginId,
        ),
      ),
    );
    if (!envelope.ok) return const _BecausePayload.empty();
    final data = envelope.data ?? const {};
    return _BecausePayload(
      heading: (data['heading'] ?? widget.spec['title'] ?? '').toString(),
      seedPoster: (data['seedPoster'] ?? '').toString(),
      canShuffle: data['canShuffle'] == true,
      items: envelope.items,
    );
  }

  void _shuffle() {
    setState(() => _shuffleKey++);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return HubLazyViewportGate(
      detectorKey: ValueKey('because:${widget.tabId}:${widget.spec['id']}'),
      placeholderHeight: HubCatalogSection.sectionHeight(context),
      prefetchSlot: widget.prefetchSlot,
      onVisible: _onViewportVisible,
      builder: (_) => FutureBuilder<_BecausePayload>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return homeLoadingShimmer(homeMovieRowSkeleton(context));
          }
          final payload = snap.data ?? const _BecausePayload.empty();
          if (payload.items.isEmpty) return const SizedBox.shrink();

          final rowId = (widget.spec['id'] ?? 'because').toString();
          final seedTitle = _becauseSeedTitle(payload.heading);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: shellSectionTitlePadding(context),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _BecauseSeedPoster(url: payload.seedPoster),
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
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            seedTitle.isEmpty ? 'recently' : seedTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (payload.canShuffle)
                      ForjaPlainIcon(
                        icon: Icons.shuffle_rounded,
                        tooltip: 'Pick a different show',
                        onTap: _shuffle,
                      ),
                  ],
                ),
              ),
              HubCatalogSection<CatalogMetaItem>(
                title: '',
                items: payload.items,
                embedded: true,
                compactTop: true,
                tvTabId: widget.tabId,
                tvRowId: rowId,
                tvRowOrder: widget.tvRowOrder,
                cardBuilder: (context, item, index) => HubPosterCard(
                  imageUrl: item.poster,
                  title: item.name,
                  subtitle: hubPosterCardSubtitle(item),
                  rating: item.rating,
                  listIndex: index,
                  tvTabId: widget.tabId,
                  tvRowId: rowId,
                  onTap: () => unawaited(
                    openCatalogMetaItem(
                      context,
                      pluginId: widget.pluginId,
                      item: item,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _becauseSeedTitle(String heading) {
  const prefix = 'Because you watched ';
  final trimmed = heading.trim();
  if (trimmed.startsWith(prefix)) {
    return trimmed.substring(prefix.length).trim();
  }
  return trimmed;
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
        color: AppTheme.bgCard,
        border: Border.all(
          color: ForjaShellColors.borderSubtle,
          width: 1.2,
        ),
      ),
      child: url.isEmpty
          ? const Icon(Icons.movie_outlined, color: Colors.white38, size: 18)
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, _) => ColoredBox(color: AppTheme.bgCard),
              errorWidget: (_, _, _) => ColoredBox(color: AppTheme.bgCard),
            ),
    );
  }
}

class _BecausePayload {
  const _BecausePayload({
    required this.heading,
    required this.seedPoster,
    required this.canShuffle,
    required this.items,
  });

  const _BecausePayload.empty()
      : heading = '',
        seedPoster = '',
        canShuffle = false,
        items = const [];

  final String heading;
  final String seedPoster;
  final bool canShuffle;
  final List<CatalogMetaItem> items;
}
