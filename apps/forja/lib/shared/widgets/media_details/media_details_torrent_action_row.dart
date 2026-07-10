import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/widgets/hero/hero_pill_buttons.dart';
import 'package:forja/shared/widgets/my_list_button.dart';
import 'package:forja/shell/app_router.dart';
import 'package:rust/rust.dart';

/// Hero actions shared by torrent and direct-streaming details.
class MediaDetailsTorrentActionRow extends StatelessWidget {
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

  void _openBestTrailer(BuildContext context) {
    if (trailers.isEmpty) return;
    AppRouter.openTrailerPlayer(
      context,
      trailers: trailers,
      initialIndex: 0,
      movie: movie,
      languageCode: trailerLanguageCode,
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
                userTraktRating != null
                    ? 'Trakt rating: $userTraktRating'
                    : 'Rate on Trakt',
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, 'simkl_rate'),
              child: Text(
                userSimklRating != null
                    ? 'Simkl rating: $userSimklRating'
                    : 'Rate on Simkl',
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, 'collect'),
              child: Text(
                isInTraktCollection
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
    if (value != null) onOverflowAction(value);
  }

  HeroPillPlayButton _playButton({
    required String label,
    IconData? icon,
    required HeroPillPlayTone tone,
    VoidCallback? onTap,
    required bool attachFocus,
  }) {
    return HeroPillPlayButton(
      label: label,
      icon: icon,
      tone: tone,
      onTap: onTap,
      focusNode: attachFocus ? playFocusNode : null,
      onKeyEvent: attachFocus ? onPlayKeyEvent : null,
    );
  }

  HeroPillIconSlot _buildOverflowSlot(BuildContext context) {
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    if (tv) {
      return HeroPillIconSlot(
        icon: Icons.more_vert_rounded,
        tooltip: 'More',
        onTap: () => _showOverflowMenu(context),
      );
    }
    return HeroPillIconSlot(
      tooltip: 'More',
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        color: ForjaShellColors.cinematic.menuSurface,
        onSelected: onOverflowAction,
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'trakt_rate',
            child: Text(userTraktRating != null
                ? 'Trakt rating: $userTraktRating'
                : 'Rate on Trakt'),
          ),
          PopupMenuItem(
            value: 'simkl_rate',
            child: Text(userSimklRating != null
                ? 'Simkl rating: $userSimklRating'
                : 'Rate on Simkl'),
          ),
          PopupMenuItem(
            value: 'collect',
            child: Text(isInTraktCollection
                ? 'Remove from collection'
                : 'Add to collection'),
          ),
          const PopupMenuItem(
            value: 'checkin',
            child: Text('Trakt check-in'),
          ),
          const PopupMenuItem(
            value: 'trakt_list',
            child: Text('Add to Trakt list'),
          ),
        ],
        child: const Icon(
          Icons.more_vert_rounded,
          size: 20,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context) {
    final playLabel = hasResume ? 'Resume' : 'Play';
    var attachNextPlayFocus = playFocusNode != null;
    final canPlay = !isStreamingExtracting;
    final children = <Widget>[];

    if (isStreamingExtracting) {
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

    if (showPlayStreaming) {
      children.addAll([
        _playButton(
          label: isStreamingExtracting ? 'Loading' : playLabel,
          icon: isStreamingExtracting ? null : Icons.play_arrow_rounded,
          tone: HeroPillPlayTone.primary,
          onTap: canPlay ? onPlayStreaming : null,
          attachFocus: attachNextPlayFocus && canPlay,
        ),
        const SizedBox(width: 10),
      ]);
      if (attachNextPlayFocus && canPlay) attachNextPlayFocus = false;
    }

    if (showPlay) {
      children.addAll([
        _playButton(
          label: playLabel,
          icon: Icons.link_rounded,
          tone: showPlayStreaming
              ? HeroPillPlayTone.streaming
              : HeroPillPlayTone.primary,
          onTap: canPlay ? onOpenSources : null,
          attachFocus: attachNextPlayFocus && canPlay,
        ),
        const SizedBox(width: 10),
      ]);
      if (attachNextPlayFocus && canPlay) attachNextPlayFocus = false;
    }

    if (hasResume && onClearProgress != null) {
      children.addAll([
        HeroPillIconGroup(
          slots: [
            HeroPillIconSlot(
              icon: Icons.delete_outline_rounded,
              tooltip: 'Clear progress',
              onTap: onClearProgress,
            ),
          ],
        ),
        const SizedBox(width: 10),
      ]);
    }

    if (trailers.isNotEmpty) {
      children.addAll([
        HeroPillPlayButton(
          label: 'Trailer',
          icon: Icons.smart_display_outlined,
          tone: HeroPillPlayTone.secondary,
          onTap: () => _openBestTrailer(context),
        ),
        const SizedBox(width: 10),
      ]);
    }

    children.add(
      HeroPillIconGroup(
        slots: [
          HeroPillIconSlot(
            child: MyListButton.movie(
              movie: movie,
              iconColor: Colors.white,
              iconColorActive: Colors.white,
              iconSize: 20,
              heroPillSlot: true,
            ),
            tooltip: 'Add to My List',
          ),
          if (showPlay)
            HeroPillIconSlot(
              icon: Icons.download_outlined,
              tooltip: 'Download',
              onTap: onDownload ?? onOpenSources,
            ),
          _buildOverflowSlot(context),
        ],
      ),
    );

    return Row(children: children);
  }

  @override
  Widget build(BuildContext context) {
    final row = _buildRow(context);
    if (!isStreamingExtracting || statusMessage == null) return row;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row,
        const SizedBox(height: 8),
        Text(
          statusMessage!,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
