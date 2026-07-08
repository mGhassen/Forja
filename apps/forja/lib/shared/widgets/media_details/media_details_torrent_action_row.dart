import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/widgets/my_list_button.dart';
import 'package:rust/rust.dart';

/// Play / My List / download / overflow actions on torrent details hero.
class MediaDetailsTorrentActionRow extends StatelessWidget {
  const MediaDetailsTorrentActionRow({
    super.key,
    required this.movie,
    required this.hasResume,
    required this.onOpenSources,
    required this.onOverflowAction,
    this.userTraktRating,
    this.userSimklRating,
    this.isInTraktCollection = false,
  });

  final Movie movie;
  final bool hasResume;
  final VoidCallback onOpenSources;
  final ValueChanged<String> onOverflowAction;
  final int? userTraktRating;
  final int? userSimklRating;
  final bool isInTraktCollection;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ForjaGhostButton(
          label: hasResume ? 'Resume' : 'Play',
          icon: Icons.play_arrow_rounded,
          onTap: onOpenSources,
        ),
        const SizedBox(width: 16),
        ForjaPlainIcon(
          icon: Icons.add,
          tooltip: 'Add to My List',
          child: MyListButton.movie(movie: movie),
        ),
        ForjaPlainIcon(
          icon: Icons.download_outlined,
          tooltip: 'Download',
          onTap: onOpenSources,
        ),
        PopupMenuButton<String>(
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
              child: Text(
                  isInTraktCollection ? 'Remove from collection' : 'Add to collection'),
            ),
            const PopupMenuItem(value: 'checkin', child: Text('Trakt check-in')),
            const PopupMenuItem(value: 'trakt_list', child: Text('Add to Trakt list')),
          ],
          child: const ForjaPlainIcon(
            icon: Icons.more_vert_rounded,
            tooltip: 'More',
          ),
        ),
      ],
    );
  }
}
