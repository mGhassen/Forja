import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/hero/hero_pill_buttons.dart';
import 'package:rust/rust.dart';

class MyListButton extends StatelessWidget {
  const MyListButton.movie({
    super.key,
    required Movie this.movie,
    this.useHeartIcon = false,
    this.iconColor,
    this.iconColorActive,
    this.iconSize,
    this.excludeFromTvTraversal = false,
  }) : stremioItem = null;

  const MyListButton.stremio({
    super.key,
    required Map<String, dynamic> this.stremioItem,
    this.useHeartIcon = false,
    this.iconColor,
    this.iconColorActive,
    this.iconSize,
    this.excludeFromTvTraversal = false,
  }) : movie = null;

  final Movie? movie;
  final Map<String, dynamic>? stremioItem;
  final bool useHeartIcon;
  final Color? iconColor;
  final Color? iconColorActive;
  final double? iconSize;
  /// Row cards: keep D-pad on the poster tile, not the overlay button.
  final bool excludeFromTvTraversal;

  String get _uniqueId {
    if (movie != null) return MyListService.movieId(movie!.id, movie!.mediaType);
    return MyListService.stremioItemId(stremioItem!);
  }

  Future<void> _toggle(BuildContext context) async {
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
        ForjaToast.success(
          added ? 'Added to My List' : 'Removed from My List',
          duration: const Duration(seconds: 1),
        );
      }
    } else if (stremioItem != null) {
      final added = await MyListService().toggleStremioItem(stremioItem!);
      if (context.mounted) {
        ForjaToast.success(
          added ? 'Added to My List' : 'Removed from My List',
          duration: const Duration(seconds: 1),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.inputPolicyOf(context);
    final exclude = excludeFromTvTraversal && policy.useFocusableMoodChips;

    Widget body = ValueListenableBuilder<int>(
      valueListenable: MyListService.changeNotifier,
      builder: (context, _, _) {
        final inList = MyListService().contains(_uniqueId);
        final icon = Icon(
          useHeartIcon
              ? (inList ? Icons.favorite_rounded : Icons.favorite_border_rounded)
              : (inList ? Icons.bookmark_rounded : Icons.add_rounded),
          size: iconSize ?? (useHeartIcon ? 24 : 20),
          color: inList
              ? (iconColorActive ??
                  (useHeartIcon ? Colors.white : ForjaShellColors.iconActive))
              : (iconColor ??
                  (useHeartIcon ? Colors.white70 : ForjaShellColors.iconMuted)),
        );

        if (!policy.useFocusableMoodChips) {
          return GestureDetector(
            onTap: () => _toggle(context),
            child: icon,
          );
        }

        return FocusableControl(
          onTap: () => _toggle(context),
          borderRadius: 20,
          scaleOnFocus: ShellTokens.focusActiveScale,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Center(child: icon),
          ),
        );
      },
    );

    if (exclude) {
      body = ExcludeFocus(child: body);
    }
    return body;
  }
}

/// Dynamic icon for the grouped hero My List slice.
class MyListHeroIcon extends StatelessWidget {
  const MyListHeroIcon.movie({super.key, required this.movie}) : stremioItem = null;

  const MyListHeroIcon.stremio({
    super.key,
    required Map<String, dynamic> this.stremioItem,
  }) : movie = null;

  final Movie? movie;
  final Map<String, dynamic>? stremioItem;

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
        return Icon(
          inList ? Icons.bookmark_rounded : Icons.add_rounded,
          size: 20,
          color: Colors.white,
        );
      },
    );
  }
}

/// Hero-row My List slice inside [HeroPillIconGroup].
class MyListHeroPillButton {
  MyListHeroPillButton._();

  static Future<void> toggle(
    BuildContext context, {
    Movie? movie,
    Map<String, dynamic>? stremioItem,
  }) async {
    if (movie != null) {
      final added = await MyListService().toggleMovie(
        tmdbId: movie.id,
        imdbId: movie.imdbId,
        title: movie.title,
        posterPath: movie.posterPath,
        mediaType: movie.mediaType,
        voteAverage: movie.voteAverage,
        releaseDate: movie.releaseDate,
      );
      if (context.mounted) {
        ForjaToast.success(
          added ? 'Added to My List' : 'Removed from My List',
          duration: const Duration(seconds: 1),
        );
      }
    } else if (stremioItem != null) {
      final added = await MyListService().toggleStremioItem(stremioItem);
      if (context.mounted) {
        ForjaToast.success(
          added ? 'Added to My List' : 'Removed from My List',
          duration: const Duration(seconds: 1),
        );
      }
    }
  }

  static HeroPillIconSlot movieSlot(
    BuildContext context, {
    required Movie movie,
  }) {
    return HeroPillIconSlot(
      label: 'My List',
      iconWidget: MyListHeroIcon.movie(movie: movie),
      onTap: () => toggle(context, movie: movie),
    );
  }

  static HeroPillIconSlot stremioSlot(
    BuildContext context, {
    required Map<String, dynamic> stremioItem,
  }) {
    return HeroPillIconSlot(
      label: 'My List',
      iconWidget: MyListHeroIcon.stremio(stremioItem: stremioItem),
      onTap: () => toggle(context, stremioItem: stremioItem),
    );
  }
}
