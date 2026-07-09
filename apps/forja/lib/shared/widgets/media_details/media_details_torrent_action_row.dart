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
    required this.onOverflowAction,
    this.trailers = const [],
    this.trailerLanguageCode,
    this.userTraktRating,
    this.userSimklRating,
    this.isInTraktCollection = false,
    this.isExtracting = false,
    this.statusMessage,
  });

  final Movie movie;
  final bool hasResume;
  final VoidCallback onOpenSources;
  final ValueChanged<String> onOverflowAction;
  final List<MediaTrailer> trailers;
  final String? trailerLanguageCode;
  final int? userTraktRating;
  final int? userSimklRating;
  final bool isInTraktCollection;
  final bool isExtracting;
  final String? statusMessage;

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

  Widget _buildRow(BuildContext context) {
    return Row(
      children: [
        if (isExtracting)
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
        HeroPillPlayButton(
          label: isExtracting ? 'Loading' : (hasResume ? 'Resume' : 'Play'),
          icon: isExtracting ? null : Icons.play_arrow_rounded,
          onTap: isExtracting ? null : onOpenSources,
        ),
        if (trailers.isNotEmpty) ...[
          const SizedBox(width: 10),
          HeroPillPlayButton(
            label: 'Trailer',
            icon: Icons.smart_display_outlined,
            primary: false,
            onTap: () => _openBestTrailer(context),
          ),
        ],
        const SizedBox(width: 10),
        HeroPillIconGroup(
          slots: [
            HeroPillIconSlot(
              child: MyListButton.movie(
                movie: movie,
                iconColor: Colors.white,
                iconColorActive: Colors.white,
                iconSize: 20,
              ),
              tooltip: 'Add to My List',
            ),
            HeroPillIconSlot(
              icon: Icons.download_outlined,
              tooltip: 'Download',
              onTap: onOpenSources,
            ),
            HeroPillIconSlot(
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
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final row = _buildRow(context);
    if (!isExtracting || statusMessage == null) return row;

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
