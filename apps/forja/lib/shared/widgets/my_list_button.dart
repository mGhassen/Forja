import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:rust/rust.dart';

class MyListButton extends StatelessWidget {
  const MyListButton.movie({
    super.key,
    required Movie this.movie,
    this.useHeartIcon = false,
    this.iconColor,
    this.iconColorActive,
    this.iconSize,
    this.heroPillSlot = false,
  }) : stremioItem = null;

  const MyListButton.stremio({
    super.key,
    required Map<String, dynamic> this.stremioItem,
    this.useHeartIcon = false,
    this.iconColor,
    this.iconColorActive,
    this.iconSize,
    this.heroPillSlot = false,
  }) : movie = null;

  final Movie? movie;
  final Map<String, dynamic>? stremioItem;
  final bool useHeartIcon;
  final Color? iconColor;
  final Color? iconColorActive;
  final double? iconSize;
  final bool heroPillSlot;

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
    return ValueListenableBuilder<int>(
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

        if (heroPillSlot) {
          return ForjaInteractive(
            onTap: () => _toggle(context),
            hoverScale: 1.06,
            pressScale: 0.94,
            onKeyEvent: (node, event) =>
                shellTrapTvFocusHorizontalEdge(node, event, trapRight: true),
            builder: (active, pressed) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOutCubic,
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (active || pressed)
                      ? Colors.white.withValues(alpha: pressed ? 0.12 : 0.08)
                      : Colors.transparent,
                ),
                child: icon,
              );
            },
          );
        }

        if (!ShellScope.inputPolicyOf(context).useFocusableMoodChips) {
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
  }
}
