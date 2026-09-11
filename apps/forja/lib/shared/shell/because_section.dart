import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:forja_foundation/protocol/filter.dart';
import 'package:forja/shared/engine/hub/meta_movie.dart';
import 'package:forja/shared/shell/kit_poster_card.dart';
import 'package:forja/shared/engine/hub/chrome_filters.dart';
import 'package:forja/shared/engine/hub/kit_row_prefetch.dart';
import 'package:forja/shared/shell/kit_section.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja/shared/engine/hub/meta_runtime.dart';
import 'package:forja/shared/host/watch/watch_history.dart';
import 'package:forja/shared/engine/hub/kit_open.dart';
import 'package:forja/shared/shell/shell_focusable_tap.dart';
import 'package:forja/shared/shell/forja_shell_layout.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/shell/tv/tv_focus_graph.dart';
import 'package:forja/shared/shell/home_loading_skeleton.dart';

/// Layout widget type `because` — pack owns rail logic; host renders meta rows.
class BecauseSection extends StatefulWidget {
  const BecauseSection({
    super.key,
    required this.pluginId,
    required this.tabId,
    required this.spec,
    this.tvHeaderRowOrder = 0,
    this.tvRowOrder = 0,
    this.prefetchSlot,
  });

  final String pluginId;
  final String tabId;
  final Map<String, dynamic> spec;
  /// Shuffle control — between the previous rail and [tvRowOrder] cards.
  final int tvHeaderRowOrder;
  final int tvRowOrder;
  final KitRowPrefetchSlot? prefetchSlot;

  @override
  State<BecauseSection> createState() => _BecauseSectionState();
}

class _BecauseSectionState extends State<BecauseSection> {
  Future<_BecausePayload>? _future;
  int _shuffleKey = 0;
  int _epoch = 0;
  bool _viewportActivated = false;
  bool _shuffleHovered = false;
  final FocusNode _shuffleFocusNode = FocusNode(debugLabel: 'because-shuffle');

  @override
  void initState() {
    super.initState();
    _registerPrefetch();
    WatchHistory.revision.addListener(_onHistoryRevision);
    _shuffleFocusNode.addListener(_onShuffleFocusChanged);
  }

  void _onShuffleFocusChanged() {
    if (mounted) setState(() {});
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
    WatchHistory.revision.removeListener(_onHistoryRevision);
    _shuffleFocusNode.removeListener(_onShuffleFocusChanged);
    _shuffleFocusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant BecauseSection oldWidget) {
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
    final envelope = await MetaRuntime.instance.run(
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
    return KitLazyViewportGate(
      detectorKey: ValueKey('because:${widget.tabId}:${widget.spec['id']}'),
      placeholderHeight: KitSection.sectionHeight(context),
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
          final headerRowId = '${rowId}_header';
          final seedTitle = _becauseSeedTitle(payload.heading);
          final shuffleActive =
              _shuffleHovered || _shuffleFocusNode.hasFocus;

          Widget? shuffle;
          if (payload.canShuffle) {
            final cardsLast = ShellTvFocusCoordinator.rowHandle(
                  widget.tabId,
                  rowId,
                )?.lastFocusedIndex ??
                0;
            shuffle = MouseRegion(
              onEnter: (_) => setState(() => _shuffleHovered = true),
              onExit: (_) => setState(() => _shuffleHovered = false),
              child: shellFocusableTap(
                context: context,
                focusNode: _shuffleFocusNode,
                borderRadius: 20,
                onTap: _shuffle,
                onDownEdge: () => ShellTvFocusCoordinator.focusRowItem(
                  widget.tabId,
                  rowId,
                  cardsLast,
                ),
                tvTabId: widget.tabId,
                tvRowId: headerRowId,
                tvZone: ShellTvZone.row,
                tvItemIndex: 0,
                child: AnimatedScale(
                  scale: shuffleActive ? 1.08 : 1.0,
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOutCubic,
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: shuffleActive
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.transparent,
                      ),
                      child: Icon(
                        Icons.shuffle_rounded,
                        size: 24,
                        color: shuffleActive
                            ? Colors.white
                            : ForjaShellColors.iconMuted,
                      ),
                    ),
                  ),
                ),
              ),
            );
            shuffle = TvKitRow(
              tabId: widget.tabId,
              rowId: headerRowId,
              sortOrder: widget.tvHeaderRowOrder,
              itemCount: 1,
              child: shuffle,
            );
          }

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
                    ?shuffle,
                  ],
                ),
              ),
              KitSection<MetaItem>(
                title: '',
                items: payload.items,
                embedded: true,
                compactTop: true,
                tvTabId: widget.tabId,
                tvRowId: rowId,
                tvRowOrder: widget.tvRowOrder,
                cardBuilder: (context, item, index) => KitPosterCard(
                  imageUrl: item.poster,
                  title: item.name,
                  subtitle: kitPosterSubtitle(item),
                  rating: item.rating,
                  listIndex: index,
                  tvTabId: widget.tabId,
                  tvRowId: rowId,
                  onTap: () => unawaited(
                    openMetaItem(
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
  final List<MetaItem> items;
}
