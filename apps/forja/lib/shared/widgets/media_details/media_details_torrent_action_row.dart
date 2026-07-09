import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/widgets/hero/hero_pill_buttons.dart';
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
        HeroPillPlayButton(
          label: hasResume ? 'Resume' : 'Play',
          onTap: onOpenSources,
        ),
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
}
