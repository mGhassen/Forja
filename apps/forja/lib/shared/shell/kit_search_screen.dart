import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja_foundation/protocol/filter.dart';
import 'package:forja/shared/engine/hub/chrome_filters.dart';
import 'package:forja/shared/engine/hub/meta_movie.dart';
import 'package:forja/shared/engine/hub/legacy_movie_meta.dart';
import 'package:forja/shared/shell/kit_search_page.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja/shared/engine/hub/meta_runtime.dart';
import 'package:forja/shared/engine/hub/catalog_open.dart';
import 'package:forja/shared/host/search/host_search_engine.dart';
import 'package:forja/shared/host/search/host_search_kit.dart';
import 'package:forja/shell/chrome/player_surface_chrome_stub.dart';
import 'package:forja_foundation/widgets/chrome/catalog_search_screen.dart';
import 'package:forja/shell/routing/app_router.dart';
import 'package:rust/rust.dart';

export 'package:forja_foundation/widgets/chrome/catalog_search_screen.dart'
    show CatalogSearchScreen;

/// Hub search backed by pack `search` and/or host search engine (`host_search`).
///
/// Screen chrome is always [KitSearchPage]. Packs with [hostSearch] use the
/// host TMDB + Stremio addon engine; others call MetaRuntime `search`.
class KitSearchScreen extends StatefulWidget {
  const KitSearchScreen({
    super.key,
    required this.pluginId,
    required this.tabId,
    this.hintText = 'Search…',
    this.structuredSearch = false,
    this.applyChromeFilters = false,
    this.hostSearch = false,
  });

  final String pluginId;
  final String tabId;
  final String hintText;
  final bool structuredSearch;
  final bool applyChromeFilters;
  final bool hostSearch;

  @override
  State<KitSearchScreen> createState() => _KitSearchScreenState();
}

class _KitSearchScreenState extends State<KitSearchScreen> {
  HostSearchEngine? _hostEngine;

  @override
  void initState() {
    super.initState();
    if (widget.hostSearch) {
      _hostEngine = HostSearchEngine();
    }
  }

  @override
  void didUpdateWidget(covariant KitSearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hostSearch && _hostEngine == null) {
      _hostEngine = HostSearchEngine();
    } else if (!widget.hostSearch && _hostEngine != null) {
      _hostEngine!.cancel();
      _hostEngine = null;
    }
  }

  @override
  void dispose() {
    _hostEngine?.cancel();
    super.dispose();
  }

  Future<List<KitSearchResult>> _packSearch(String query) async {
    final base = <String, dynamic>{'query': query, 'limit': 40};
    final params = widget.applyChromeFilters
        ? catalogParamsWithFilters(
            base,
            filters: catalogChromeFilters(
              tabId: widget.tabId,
              pluginId: widget.pluginId,
            ),
          )
        : base;
    final env = await MetaRuntime.instance.run(
      pluginId: widget.pluginId,
      action: 'search',
      params: params,
    );
    if (!env.ok) return const [];
    return [
      for (final item in env.items)
        KitSearchResult(
          key: item.id,
          title: item.name,
          posterUrl: item.poster,
          backdropUrl: item.background.isEmpty ? null : item.background,
          subtitle: kitPosterSubtitle(item),
          rating: item.rating,
          payload: item,
        ),
    ];
  }

  Future<List<String>> _packRecommendations({
    required String query,
    required List<KitSearchResult> results,
  }) async {
    if (results.isEmpty) return const [];
    final titles = <String>[];
    for (final r in results) {
      final t = r.title.trim();
      if (t.isEmpty || titles.contains(t)) continue;
      titles.add(t);
      if (titles.length >= 12) break;
    }
    return titles;
  }

  void _openResult(BuildContext context, KitSearchResult result) {
    final payload = result.payload;
    if (payload is MetaItem) {
      openMetaItem(
        context,
        pluginId: widget.pluginId,
        item: payload,
      );
      return;
    }
    if (payload is Movie) {
      openMetaItem(
        context,
        pluginId: widget.pluginId,
        item: metaItemFromMovie(payload),
      );
      return;
    }
    if (payload is Map) {
      unawaited(
        AppRouter.openStremioSearchResult(
          context,
          Map<String, dynamic>.from(payload),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final host = widget.hostSearch;
    final engine = _hostEngine;
    return PlayerSurfaceChromeStub(
      builder: (context) => CatalogSearchScreen(
        hintText: widget.hintText,
        tvTabId: widget.tabId,
        structuredSearch: widget.structuredSearch,
        onSearch: host
            ? (q) async {
                return const [];
              }
            : _packSearch,
        loadRecommendations:
            host ? hostKitRecommendations : _packRecommendations,
        onOpen: (result) => _openResult(context, result),
        pageBuilder: ({
          required onSearch,
          required onOpen,
          required hintText,
          required structuredSearch,
          loadRecommendations,
        }) {
          return KitSearchPage(
            hintText: hintText,
            tvTabId: widget.tabId,
            structuredSearch: structuredSearch,
            onSearch: onSearch,
            onSearchProgressive: engine == null
                ? null
                : (query, emit) => runHostKitSearch(
                      query,
                      emit,
                      engine: engine,
                    ),
            onSearchLoadMore: engine == null
                ? null
                : (emit) => runHostKitSearchLoadMore(
                      emit,
                      engine: engine,
                    ),
            loadRecommendations: loadRecommendations ??
                (host ? hostKitRecommendations : _packRecommendations),
            onOpen: onOpen,
          );
        },
      ),
    );
  }
}
