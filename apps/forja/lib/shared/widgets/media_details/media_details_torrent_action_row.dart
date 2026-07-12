import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/widgets/hero/hero_pill_buttons.dart';
import 'package:forja/shared/widgets/my_list_button.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:forja/shared/tv/media_details_tv_scope.dart';
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
    this.onDownload,
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
  final VoidCallback? onDownload;
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
  @override
  void dispose() {
    final tabId = widget.tvTabId;
    if (tabId != null) {
      shellTvUnregisterRow(tabId: tabId, rowId: MediaDetailsTv.heroRowId);
    }
    super.dispose();
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
    if (widget.showPlay) n++;
    n++;
    return n;
  }

  int _focusableActionCount() {
    final canPlay = !widget.isStreamingExtracting;
    var n = 0;
    if (widget.showPlayStreaming && canPlay) n++;
    if (widget.showPlay && canPlay) n++;
    if (widget.hasResume && widget.onClearProgress != null) n++;
    if (widget.trailers.isNotEmpty) n++;
    n += _iconGroupSlotCount();
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

    if (widget.hasResume && widget.onClearProgress != null) {
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
              tooltip: 'Clear progress',
              onTap: widget.onClearProgress,
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
          MyListHeroPillButton.movieSlot(context, movie: widget.movie),
          if (widget.showPlay)
            HeroPillIconSlot(
              icon: Icons.download_outlined,
              tooltip: 'Download',
              onTap: widget.onDownload ?? widget.onOpenSources,
            ),
          _buildOverflowSlot(context),
        ],
      ),
    );

    return HeroPillActionRow(children: children);
  }

  @override
  Widget build(BuildContext context) {
    final tabId = widget.tvTabId;
    if (tabId != null) {
      shellTvRegisterRow(
        tabId: tabId,
        rowId: MediaDetailsTv.heroRowId,
        sortOrder: MediaDetailsTv.heroRowSortOrder,
        itemCount: _focusableActionCount(),
        onFocusUp: widget.tvFocusUp,
      );
    }

    final row = _buildRow(context);
    if (!widget.isStreamingExtracting || widget.statusMessage == null) {
      return row;
    }

    return Column(
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
  }
}
