import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/my_list/providers/external_lists_providers.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/services/youtube_stream_service.dart';
import 'package:forja/shared/tv/media_details_tv_scope.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';
import 'package:forja/shared/widgets/hero/hero_pill_buttons.dart';
import 'package:forja/shared/widgets/my_list_button.dart';
import 'package:forja/shell/app_router.dart';
import 'package:rust/rust.dart';

/// Hero actions shared by torrent and direct-streaming details.
class MediaDetailsTorrentActionRow extends StatefulWidget {
  const MediaDetailsTorrentActionRow({
    super.key,
    required this.movie,
    required this.hasResume,
    required this.onOpenSources,
    this.onClearProgress,
    this.onPlayStreaming,
    this.showPlayStreaming = false,
    this.isStreamingExtracting = false,
    required this.onOverflowAction,
    this.trailers = const [],
    this.trailerLanguageCode,
    this.userTraktRating,
    this.userSimklRating,
    this.isInTraktCollection = false,
    this.showPlay = true,
    this.statusMessage,
    this.playFocusNode,
    this.onPlayKeyEvent,
    this.tvTabId,
    this.tvFocusUp,
  });

  final Movie movie;
  final bool hasResume;
  final VoidCallback onOpenSources;
  final VoidCallback? onClearProgress;
  final VoidCallback? onPlayStreaming;
  final bool showPlayStreaming;
  final bool isStreamingExtracting;
  final ValueChanged<String> onOverflowAction;
  final List<MediaTrailer> trailers;
  final String? trailerLanguageCode;
  final int? userTraktRating;
  final int? userSimklRating;
  final bool isInTraktCollection;
  final bool showPlay;
  final String? statusMessage;
  final FocusNode? playFocusNode;
  final KeyEventResult Function(FocusNode node, KeyEvent event)? onPlayKeyEvent;
  final String? tvTabId;
  final VoidCallback? tvFocusUp;

  @override
  State<MediaDetailsTorrentActionRow> createState() =>
      _MediaDetailsTorrentActionRowState();
}

class _MediaDetailsTorrentActionRowState
    extends State<MediaDetailsTorrentActionRow> {
  /// Hero ⋮ menu (Trakt/Simkl) - kept wired; hide until product wants it back.
  static const bool _overflowVisible = false;

  @override
  void initState() {
    super.initState();
    _prefetchBestTrailer();
  }

  @override
  void didUpdateWidget(covariant MediaDetailsTorrentActionRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trailers.isEmpty && widget.trailers.isNotEmpty) {
      _prefetchBestTrailer();
    }
  }

  void _prefetchBestTrailer() {
    if (widget.trailers.isEmpty) return;
    YoutubeStreamService.prefetch(widget.trailers.map((t) => t.key), limit: 1);
  }

  void _invalidateSimklLists() {
    try {
      ProviderScope.containerOf(
        context,
        listen: false,
      ).invalidate(simklWatchlistProvider);
    } catch (_) {}
  }

  void _openBestTrailer(BuildContext context) {
    if (widget.trailers.isEmpty) return;
    AppRouter.openTrailerPlayer(
      context,
      trailers: widget.trailers,
      initialIndex: 0,
      movie: widget.movie,
      languageCode: widget.trailerLanguageCode,
    );
  }

  Future<void> _showOverflowMenu(BuildContext context) async {
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          backgroundColor: ForjaShellColors.cinematic.menuSurface,
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, 'trakt_rate'),
              child: Text(
                widget.userTraktRating != null
                    ? 'Trakt rating: ${widget.userTraktRating}'
                    : 'Rate on Trakt',
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, 'simkl_rate'),
              child: Text(
                widget.userSimklRating != null
                    ? 'Simkl rating: ${widget.userSimklRating}'
                    : 'Rate on Simkl',
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, 'collect'),
              child: Text(
                widget.isInTraktCollection
                    ? 'Remove from collection'
                    : 'Add to collection',
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, 'checkin'),
              child: const Text('Trakt check-in'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, 'trakt_list'),
              child: const Text('Add to Trakt list'),
            ),
          ],
        );
      },
    );
    if (value != null) widget.onOverflowAction(value);
  }

  int _focusableActionCount() {
    final canPlay = !widget.isStreamingExtracting;
    var n = 0;
    if (widget.showPlayStreaming && canPlay) n++;
    if (widget.showPlay && canPlay) n++;
    if (widget.onClearProgress != null) n++;
    if (widget.trailers.isNotEmpty) n++;
    n++; // My List
    if (_overflowVisible) n++;
    return n;
  }

  HeroPillPlayButton _playButton({
    required String label,
    IconData? icon,
    required HeroPillPlayTone tone,
    VoidCallback? onTap,
    required bool attachFocus,
    required int? tvItemIndex,
  }) {
    return HeroPillPlayButton(
      label: label,
      icon: icon,
      tone: tone,
      onTap: onTap,
      focusNode: attachFocus ? widget.playFocusNode : null,
      onKeyEvent: attachFocus ? widget.onPlayKeyEvent : null,
      onUpEdge: widget.tvTabId != null ? widget.tvFocusUp : null,
      tvTabId: widget.tvTabId,
      tvRowId: widget.tvTabId != null ? MediaDetailsTv.heroRowId : null,
      tvItemIndex: tvItemIndex,
    );
  }

  Widget _buildRow(BuildContext context) {
    final playLabel = widget.hasResume ? 'Resume' : 'Play';
    var attachNextPlayFocus = widget.playFocusNode != null;
    final canPlay = !widget.isStreamingExtracting;
    final children = <Widget>[];
    var tvIndex = 0;

    if (widget.isStreamingExtracting) {
      children.add(
        const Padding(
          padding: EdgeInsets.only(right: 8),
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white70,
            ),
          ),
        ),
      );
    }

    if (widget.showPlayStreaming) {
      final idx = tvIndex;
      children.addAll([
        _playButton(
          label: widget.isStreamingExtracting ? 'Loading' : playLabel,
          icon: widget.isStreamingExtracting ? null : Icons.play_arrow_rounded,
          tone: HeroPillPlayTone.primary,
          onTap: canPlay ? widget.onPlayStreaming : null,
          attachFocus: attachNextPlayFocus && canPlay,
          tvItemIndex: canPlay ? idx : null,
        ),
        const SizedBox(width: 10),
      ]);
      if (canPlay) tvIndex++;
      if (attachNextPlayFocus && canPlay) attachNextPlayFocus = false;
    }

    if (widget.showPlay) {
      final idx = tvIndex;
      children.addAll([
        _playButton(
          label: playLabel,
          icon: Icons.link_rounded,
          tone: widget.showPlayStreaming
              ? HeroPillPlayTone.streaming
              : HeroPillPlayTone.primary,
          onTap: canPlay ? widget.onOpenSources : null,
          attachFocus: attachNextPlayFocus && canPlay,
          tvItemIndex: canPlay ? idx : null,
        ),
        const SizedBox(width: 10),
      ]);
      if (canPlay) tvIndex++;
      if (attachNextPlayFocus && canPlay) attachNextPlayFocus = false;
    }

    if (widget.onClearProgress != null) {
      final idx = tvIndex++;
      children.addAll([
        HeroPillIconGroup(
          tvTabId: widget.tvTabId,
          tvRowId: widget.tvTabId != null ? MediaDetailsTv.heroRowId : null,
          tvItemIndexStart: idx,
          onUpEdge: widget.tvFocusUp,
          slots: [
            HeroPillIconSlot(
              icon: Icons.delete_outline_rounded,
              label: 'Clear',
              tooltip: 'Clear progress & stream cache',
              onTap: () {
                widget.onClearProgress?.call();
                Future<void>.delayed(const Duration(milliseconds: 400), () {
                  if (!mounted) return;
                  _invalidateSimklLists();
                });
              },
            ),
          ],
        ),
        const SizedBox(width: 10),
      ]);
    }

    if (widget.trailers.isNotEmpty) {
      final idx = tvIndex++;
      children.addAll([
        HeroPillPlayButton(
          label: 'Trailer',
          icon: Icons.smart_display_outlined,
          tone: HeroPillPlayTone.secondary,
          onTap: () => _openBestTrailer(context),
          tvTabId: widget.tvTabId,
          tvRowId: widget.tvTabId != null ? MediaDetailsTv.heroRowId : null,
          tvItemIndex: idx,
        ),
        const SizedBox(width: 10),
      ]);
    }

    // Glass hero pill (same as trash/trailer) + floating Overlay menu.
    children.add(
      MyListHeroStatusPill(
        movie: widget.movie,
        tvTabId: widget.tvTabId,
        tvItemIndexStart: tvIndex++,
        onUpEdge: widget.tvFocusUp,
      ),
    );

    if (_overflowVisible) {
      children.addAll([
        const SizedBox(width: 10),
        HeroPillIconGroup(
          tvTabId: widget.tvTabId,
          tvRowId: widget.tvTabId != null ? MediaDetailsTv.heroRowId : null,
          tvItemIndexStart: tvIndex,
          onUpEdge: widget.tvFocusUp,
          slots: [
            HeroPillIconSlot(
              icon: Icons.more_vert_rounded,
              tooltip: 'More',
              onTap: () => _showOverflowMenu(context),
            ),
          ],
        ),
      ]);
    }

    return HeroPillActionRow(children: children);
  }

  @override
  Widget build(BuildContext context) {
    final row = _buildRow(context);
    final child = !widget.isStreamingExtracting || widget.statusMessage == null
        ? row
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              row,
              const SizedBox(height: 8),
              Text(
                widget.statusMessage!,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ],
          );

    final tabId = widget.tvTabId;
    if (tabId == null) return child;

    return TvCatalogRow(
      tabId: tabId,
      rowId: MediaDetailsTv.heroRowId,
      sortOrder: MediaDetailsTv.heroRowSortOrder,
      itemCount: _focusableActionCount(),
      onFocusUp: widget.tvFocusUp,
      child: child,
    );
  }
}
