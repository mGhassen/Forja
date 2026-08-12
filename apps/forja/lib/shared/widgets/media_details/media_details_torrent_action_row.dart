import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/my_list/providers/external_lists_providers.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/services/tracker/simkl_service.dart';
import 'package:forja/shared/tv/media_details_tv_scope.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';
import 'package:forja/shared/widgets/hero/hero_pill_buttons.dart';
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

  static const _simklStatuses = <({String id, String label, IconData icon, IconData selectedIcon})>[
    (id: 'plantowatch', label: 'Plan to Watch', icon: Icons.bookmark_add_outlined, selectedIcon: Icons.bookmark_rounded),
    (id: 'watching', label: 'Watching', icon: Icons.play_circle_outline_rounded, selectedIcon: Icons.play_circle_rounded),
    (id: 'hold', label: 'On Hold', icon: Icons.pause_circle_outline_rounded, selectedIcon: Icons.pause_circle_rounded),
    (id: 'completed', label: 'Completed', icon: Icons.check_circle_outline_rounded, selectedIcon: Icons.check_circle_rounded),
    (id: 'dropped', label: 'Dropped', icon: Icons.cancel_outlined, selectedIcon: Icons.cancel_rounded),
  ];

  bool _simklLoggedIn = false;
  bool _simklMenuOpen = false;
  String? _simklStatus;
  bool _simklBusy = false;

  @override
  void initState() {
    super.initState();
    _loadSimkl();
  }

  @override
  void didUpdateWidget(covariant MediaDetailsTorrentActionRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.movie.id != widget.movie.id ||
        oldWidget.movie.mediaType != widget.movie.mediaType) {
      _simklMenuOpen = false;
      _simklStatus = null;
      _loadSimkl();
    }
  }

  Future<void> _loadSimkl() async {
    await MyListService().ensureLoaded();
    final uid = MyListService.movieId(widget.movie.id, widget.movie.mediaType);
    final local = MyListService().contains(uid)
        ? MyListService().statusOf(uid)
        : null;
    final simkl = SimklService();
    final loggedIn = await simkl.isLoggedIn();
    String? remote;
    if (loggedIn) {
      remote = await simkl.getListStatus(
        tmdbId: widget.movie.id,
        mediaType: widget.movie.mediaType,
      );
    }
    if (!mounted) return;
    setState(() {
      _simklLoggedIn = loggedIn;
      _simklStatus = remote ?? local;
    });
  }

  void _invalidateSimklLists() {
    try {
      ProviderScope.containerOf(context, listen: false)
          .invalidate(simklWatchlistProvider);
    } catch (_) {}
  }

  IconData _plusIcon() {
    for (final s in _simklStatuses) {
      if (s.id == _simklStatus) return s.selectedIcon;
    }
    return Icons.add_rounded;
  }

  String _plusLabel() {
    for (final s in _simklStatuses) {
      if (s.id == _simklStatus) return s.label;
    }
    return 'My List';
  }

  Future<void> _onPlusTap() async {
    setState(() => _simklMenuOpen = !_simklMenuOpen);
  }

  Future<void> _setSimklStatus(String to) async {
    if (_simklBusy) return;
    setState(() => _simklBusy = true);
    await MyListService().upsertMovie(
      tmdbId: widget.movie.id,
      imdbId: widget.movie.imdbId,
      title: widget.movie.title,
      posterPath: widget.movie.posterPath,
      mediaType: widget.movie.mediaType,
      voteAverage: widget.movie.voteAverage,
      releaseDate: widget.movie.releaseDate,
      listStatus: to,
    );
    var ok = true;
    if (_simklLoggedIn) {
      ok = await SimklService().setListStatus(
        tmdbId: widget.movie.id,
        imdbId: widget.movie.imdbId,
        mediaType: widget.movie.mediaType,
        to: to,
      );
    }
    if (!mounted) return;
    setState(() {
      _simklBusy = false;
      _simklStatus = to;
      _simklMenuOpen = false;
    });
    _invalidateSimklLists();
    final label =
        _simklStatuses.where((s) => s.id == to).firstOrNull?.label ?? to;
    if (ok) {
      ForjaToast.success(label);
    } else {
      ForjaToast.error('Saved locally · Simkl failed');
    }
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

  int _iconGroupSlotCount() {
    var n = 1;
    if (_overflowVisible) n++;
    return n;
  }

  int _simklStatusSlotCount() =>
      _simklMenuOpen ? _simklStatuses.length : 0;

  int _focusableActionCount() {
    final canPlay = !widget.isStreamingExtracting;
    var n = 0;
    if (widget.showPlayStreaming && canPlay) n++;
    if (widget.showPlay && canPlay) n++;
    if (widget.onClearProgress != null) n++;
    if (widget.trailers.isNotEmpty) n++;
    n += _iconGroupSlotCount();
    n += _simklStatusSlotCount();
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

  HeroPillIconSlot _buildOverflowSlot(BuildContext context) {
    return HeroPillIconSlot(
      icon: Icons.more_vert_rounded,
      tooltip: 'More',
      onTap: () => _showOverflowMenu(context),
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
                Future<void>.delayed(const Duration(milliseconds: 400), () async {
                  if (!mounted) return;
                  _invalidateSimklLists();
                  await _loadSimkl();
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

    final iconStart = tvIndex;
    children.add(
      HeroPillIconGroup(
        tvTabId: widget.tvTabId,
        tvRowId: widget.tvTabId != null ? MediaDetailsTv.heroRowId : null,
        tvItemIndexStart: iconStart,
        onUpEdge: widget.tvFocusUp,
        slots: [
          HeroPillIconSlot(
            label: _plusLabel(),
            icon: _plusIcon(),
            onTap: _onPlusTap,
          ),
          if (_overflowVisible) _buildOverflowSlot(context),
        ],
      ),
    );

    if (_simklMenuOpen) {
      children.addAll([
        const SizedBox(width: 10),
        HeroPillIconGroup(
          tvTabId: widget.tvTabId,
          tvRowId: widget.tvTabId != null ? MediaDetailsTv.heroRowId : null,
          tvItemIndexStart: tvIndex,
          onUpEdge: widget.tvFocusUp,
          slots: [
            for (final s in _simklStatuses)
              HeroPillIconSlot(
                label: s.label,
                icon: s.id == _simklStatus ? s.selectedIcon : s.icon,
                onTap: _simklBusy ? null : () => _setSimklStatus(s.id),
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
    final child =
        !widget.isStreamingExtracting || widget.statusMessage == null
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
