import 'package:flutter/material.dart';
import 'package:forja/shared/design/src/forja_shell_colors.dart';
import 'package:rust/rust.dart';

class MyListButton extends StatelessWidget {
  const MyListButton.movie({
    super.key,
    required Movie this.movie,
    this.useHeartIcon = false,
  }) : stremioItem = null;

  const MyListButton.stremio({
    super.key,
    required Map<String, dynamic> this.stremioItem,
    this.useHeartIcon = false,
  }) : movie = null;

  final Movie? movie;
  final Map<String, dynamic>? stremioItem;
  final bool useHeartIcon;

  String get _uniqueId {
    if (movie != null) return MyListService.movieId(movie!.id, movie!.mediaType);
    return MyListService.stremioItemId(stremioItem!);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: MyListService.changeNotifier,
      builder: (context, _, _) {
        final inList = MyListService().contains(_uniqueId);
        return GestureDetector(
          onTap: () async {
            if (movie != null) {
              final added = await MyListService().toggleMovie(
                tmdbId: movie!.id,
                imdbId: movie!.imdbId,
                title: movie!.title,
                posterPath: movie!.posterPath,
                mediaType: movie!.mediaType,
                voteAverage: movie!.voteAverage,
                releaseDate: movie!.releaseDate,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(added ? 'Added to My List' : 'Removed from My List'),
                  duration: const Duration(seconds: 1),
                ));
              }
            } else if (stremioItem != null) {
              final added = await MyListService().toggleStremioItem(stremioItem!);
              if (context.mounted) {
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(added ? 'Added to My List' : 'Removed from My List'),
                  duration: const Duration(seconds: 1),
                ));
              }
            }
          },
          child: Icon(
            useHeartIcon
                ? (inList ? Icons.favorite_rounded : Icons.favorite_border_rounded)
                : (inList ? Icons.bookmark_rounded : Icons.add_rounded),
            size: useHeartIcon ? 24 : 20,
            color: inList
                ? (useHeartIcon ? Colors.white : ForjaShellColors.iconActive)
                : (useHeartIcon ? Colors.white70 : ForjaShellColors.iconMuted),
          ),
        );
      },
    );
  }
}
