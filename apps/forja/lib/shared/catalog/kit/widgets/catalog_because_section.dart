import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/catalog/filter.dart';
import 'package:forja/shared/catalog/kit/cards/hub_poster_card.dart';
import 'package:forja/shared/catalog/kit/chrome/catalog_chrome_filters.dart';
import 'package:forja/shared/catalog/kit/rows/hub_catalog_section.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/catalog/runtime.dart';
import 'package:forja/shared/catalog/services/catalog_resume_seeds.dart';
import 'package:forja/shared/catalog/shell/catalog_open.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/widgets/home_loading_skeleton.dart';

/// Layout widget type `because` — pack owns rail logic; host renders meta rows.
class CatalogBecauseSection extends StatefulWidget {
  const CatalogBecauseSection({
    super.key,
    required this.pluginId,
    required this.tabId,
    required this.spec,
    this.tvRowOrder = 0,
  });

  final String pluginId;
  final String tabId;
  final Map<String, dynamic> spec;
  final int tvRowOrder;

  @override
  State<CatalogBecauseSection> createState() => _CatalogBecauseSectionState();
}

class _CatalogBecauseSectionState extends State<CatalogBecauseSection> {
  Future<_BecausePayload>? _future;
  int _shuffleKey = 0;
  int _epoch = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant CatalogBecauseSection oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    return FutureBuilder<_BecausePayload>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting &&
            !snap.hasData) {
          return homeLoadingShimmer(homeMovieRowSkeleton(context));
        }
        final payload = snap.data ?? const _BecausePayload.empty();
        if (payload.items.isEmpty) return const SizedBox.shrink();

        final rowId = (widget.spec['id'] ?? 'because').toString();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: shellHomeSectionTitlePadding(context),
              child: Row(
                children: [
                  if (payload.seedPoster.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: CachedNetworkImage(
                        imageUrl: payload.seedPoster,
                        width: 32,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      payload.heading.isEmpty
                          ? 'Because you watched'
                          : payload.heading,
                      style: ShellSectionTitle.titleStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (payload.canShuffle)
                    IconButton(
                      tooltip: 'Shuffle seed',
                      onPressed: _shuffle,
                      icon: Icon(
                        Icons.shuffle_rounded,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 22,
                      ),
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
                subtitle:
                    item.releaseInfo.isEmpty ? null : item.releaseInfo,
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
