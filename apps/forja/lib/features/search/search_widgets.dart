part of 'search_screen.dart';

class _SearchFilmCard extends StatefulWidget {
  const _SearchFilmCard({
    required this.result,
    required this.selected,
    required this.onTap,
    required this.onOpen,
    this.onFocusChange,
    this.onLeftEdge,
    this.onUpEdge,
    this.gridIndex,
  });

  final _FlatSearchResult result;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onOpen;
  final ValueChanged<bool>? onFocusChange;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onUpEdge;
  final int? gridIndex;

  @override
  State<_SearchFilmCard> createState() => _SearchFilmCardState();
}

class _SearchFilmCardState extends State<_SearchFilmCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final titleSize = shellHubCardTitleFontSize(context);
    final tvActivateOpens = ShellScope.inputPolicyOf(
      context,
    ).useFocusableMoodChips;
    final grid = TvGridScope.maybeOf(context);
    final index = widget.gridIndex;
    final meta = index != null ? grid?.metaFor(index) : null;

    return shellFocusableTap(
      context: context,
      onTap: tvActivateOpens ? widget.onOpen : widget.onTap,
      borderRadius: 14,
      showFocusBorder: true,
      onLeftEdge: widget.onLeftEdge,
      onUpEdge: widget.onUpEdge,
      gridIndex: meta?.gridIndex ?? index,
      gridColumns: meta?.gridColumns,
      tvTabId: meta?.tvTabId ?? 'search',
      tvRowId: meta?.tvRowId ?? 'results',
      tvZone: meta?.tvZone ?? ShellTvZone.grid,
      tvItemIndex: meta?.tvItemIndex ?? index,
      onFocusChange: widget.onFocusChange,
      onHoverChange: (hovered) => setState(() => _hovered = hovered),
      child: GestureDetector(
        onDoubleTap: widget.onOpen,
        child: SizedBox.expand(
          child: AnimatedContainer(
            duration: ShellTokens.navSelectionAnimation,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: widget.selected
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: widget.selected ? 0.65 : 0.5,
                  ),
                  blurRadius: widget.selected ? 20 : 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: AppTheme.bgDark,
                    child: widget.result.posterUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: widget.result.posterUrl,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.medium,
                            placeholder: (_, _) =>
                                ColoredBox(color: AppTheme.bgDark),
                            errorWidget: (_, _, _) => Center(
                              child: Text(
                                widget.result.title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white24,
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              widget.result.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white24,
                              ),
                            ),
                          ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                          Colors.black.withValues(alpha: 0.95),
                        ],
                        stops: const [0.0, 0.45, 0.8, 1.0],
                      ),
                    ),
                  ),
                  if (_hovered)
                    Positioned.fill(
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: 0.35),
                        child: Center(
                          child: Material(
                            color: Colors.transparent,
                            shape: const CircleBorder(),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              hoverColor: ForjaShellColors.inkHover,
                              splashColor: ForjaShellColors.inkSplash,
                              highlightColor: ForjaShellColors.inkSplash,
                              onTap: widget.onOpen,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.info_outline_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (widget.result.rating != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 12,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              widget.result.rating!.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 10,
                    left: 10,
                    right: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.result.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: titleSize,
                            height: 1.2,
                          ),
                        ),
                        if (widget.result.year != null &&
                            widget.result.year!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.result.year!,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Result Cards
// ═════════════════════════════════════════════════════════════════════════════

class _SearchCard extends StatelessWidget {
  final Movie movie;
  final VoidCallback onTap;
  final int? listIndex;

  const _SearchCard({required this.movie, required this.onTap, this.listIndex});

  @override
  Widget build(BuildContext context) {
    final imageUrl = movie.posterPath.isNotEmpty
        ? TmdbApi.getImageUrl(movie.posterPath)
        : '';

    return shellFocusableTap(
      context: context,
      onTap: onTap,
      borderRadius: 12,
      showFocusBorder: true,
      listIndex: listIndex,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(color: AppTheme.bgCard),
                errorWidget: (_, _, _) => const Center(
                  child: Icon(Icons.broken_image, color: Colors.white24),
                ),
              )
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    movie.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),

            if (movie.voteAverage > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    movie.voteAverage.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                ),
              ),

            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                child: Text(
                  movie.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                ),
              ),
            ),

            Positioned(
              top: 6,
              left: 6,
              child: _AddToMyListButton(movie: movie),
            ),
          ],
        ),
      ),
    );
  }
}

class _StremioSearchCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final int? listIndex;

  const _StremioSearchCard({
    required this.item,
    required this.onTap,
    this.listIndex,
  });

  @override
  Widget build(BuildContext context) {
    final poster = item['poster']?.toString() ?? '';
    final name = item['name']?.toString() ?? 'Unknown';
    final rating = item['imdbRating']?.toString() ?? '';
    final type = item['type']?.toString() ?? '';

    return shellFocusableTap(
      context: context,
      onTap: onTap,
      borderRadius: 12,
      showFocusBorder: true,
      listIndex: listIndex,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (poster.isNotEmpty)
              CachedNetworkImage(
                imageUrl: poster,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(color: AppTheme.bgCard),
                errorWidget: (_, _, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white38,
                      ),
                    ),
                  ),
                ),
              )
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, color: Colors.white38),
                  ),
                ),
              ),

            if (type.isNotEmpty)
              Positioned(
                top: 5,
                left: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: type == 'series'
                        ? Colors.blue.withValues(alpha: 0.7)
                        : AppTheme.current.primaryColor.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    type.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

            if (rating.isNotEmpty)
              Positioned(
                top: 5,
                right: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, size: 9, color: Colors.amber),
                      const SizedBox(width: 2),
                      Text(
                        rating,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                ),
              ),
            ),

            Positioned(
              bottom: 30,
              right: 5,
              child: _AddToMyListStremioButton(item: item),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// My List button helpers for search cards
// ─────────────────────────────────────────────────────────────────────────────

class _AddToMyListButton extends StatelessWidget {
  final Movie movie;
  const _AddToMyListButton({required this.movie});

  @override
  Widget build(BuildContext context) {
    final uid = MyListService.movieId(movie.id, movie.mediaType);
    return ValueListenableBuilder<int>(
      valueListenable: MyListService.changeNotifier,
      builder: (context, _, _) {
        final inList = MyListService().contains(uid);
        return GestureDetector(
          onTap: () async {
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
          },
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              inList ? Icons.bookmark : Icons.add,
              size: 16,
              color: inList ? AppTheme.primaryColor : Colors.white70,
            ),
          ),
        );
      },
    );
  }
}

class _AddToMyListStremioButton extends StatelessWidget {
  final Map<String, dynamic> item;
  const _AddToMyListStremioButton({required this.item});

  @override
  Widget build(BuildContext context) {
    final uid = MyListService.stremioItemId(item);
    return ValueListenableBuilder<int>(
      valueListenable: MyListService.changeNotifier,
      builder: (context, _, _) {
        final inList = MyListService().contains(uid);
        return GestureDetector(
          onTap: () async {
            final added = await MyListService().toggleStremioItem(item);
            if (context.mounted) {
              ForjaToast.success(
                added ? 'Added to My List' : 'Removed from My List',
                duration: const Duration(seconds: 1),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              inList ? Icons.bookmark : Icons.add,
              size: 16,
              color: inList ? AppTheme.primaryColor : Colors.white70,
            ),
          ),
        );
      },
    );
  }
}
