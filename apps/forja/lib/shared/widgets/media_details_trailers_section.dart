import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/design/src/shell_section_title.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/widgets/horizontal_scroller.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:forja/shell/app_router.dart';
import 'package:rust/rust.dart';

const _kTrailerCardWidth = 200.0;

class MediaDetailsTrailersSection extends StatefulWidget {
  const MediaDetailsTrailersSection({
    super.key,
    required this.trailers,
    this.movie,
    this.languageCode,
    this.outdentHorizontal = 0,
    this.tvTabId,
    this.tvRowId,
    this.tvRowOrder = 0,
    this.tvFocusUp,
  });

  final List<MediaTrailer> trailers;
  final Movie? movie;
  final String? languageCode;
  final double outdentHorizontal;
  final String? tvTabId;
  final String? tvRowId;
  final int tvRowOrder;
  final VoidCallback? tvFocusUp;

  @override
  State<MediaDetailsTrailersSection> createState() =>
      _MediaDetailsTrailersSectionState();
}

class _MediaDetailsTrailersSectionState
    extends State<MediaDetailsTrailersSection> {
  String get _rowId => widget.tvRowId ?? 'trailers';

  @override
  void dispose() {
    final tabId = widget.tvTabId ?? ShellTvFocus.currentNavTabId;
    if (tabId != null && widget.tvRowId != null) {
      shellTvUnregisterRow(tabId: tabId, rowId: _rowId);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.trailers.isEmpty) return const SizedBox.shrink();

    final tabId = widget.tvTabId ?? ShellTvFocus.currentNavTabId;
    if (tabId != null && widget.tvRowId != null) {
      shellTvRegisterRow(
        tabId: tabId,
        rowId: _rowId,
        sortOrder: widget.tvRowOrder,
        itemCount: widget.trailers.length,
        onFocusUp: widget.tvFocusUp,
      );
    }

    final outdent = widget.outdentHorizontal;
    final useHomeInsets = outdent > 0;
    final homePad = ShellTokens.homeSectionHorizontalPadding;

    final row = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (useHomeInsets)
          ShellSectionTitle(
            title: 'Trailers',
            padding: EdgeInsets.fromLTRB(homePad, 0, homePad, 12),
          )
        else ...[
          Text('Trailers', style: ShellSectionTitle.titleStyle),
          const SizedBox(height: 12),
        ],
        FocusTraversalGroup(
          child: HorizontalScroller(
            height: 156,
            padding: useHomeInsets ? EdgeInsets.only(left: homePad) : EdgeInsets.zero,
            itemCount: widget.trailers.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) => _TrailerCard(
              trailers: widget.trailers,
              index: index,
              movie: widget.movie,
              languageCode: widget.languageCode,
              tvTabId: tabId,
              tvRowId: widget.tvRowId != null ? _rowId : null,
            ),
          ),
        ),
      ],
    );

    if (outdent <= 0) return row;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth + outdent * 2,
          child: Transform.translate(
            offset: Offset(-outdent, 0),
            child: row,
          ),
        );
      },
    );
  }
}

class _TrailerCard extends StatelessWidget {
  const _TrailerCard({
    required this.trailers,
    required this.index,
    this.movie,
    this.languageCode,
    this.tvTabId,
    this.tvRowId,
  });

  final List<MediaTrailer> trailers;
  final int index;
  final Movie? movie;
  final String? languageCode;
  final String? tvTabId;
  final String? tvRowId;

  MediaTrailer get trailer => trailers[index];

  void _open(BuildContext context) {
    AppRouter.openTrailerPlayer(
      context,
      trailers: trailers,
      initialIndex: index,
      movie: movie,
      languageCode: languageCode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final thumbHeight = _kTrailerCardWidth * 9 / 16;

    return shellFocusableTap(
      context: context,
      onTap: () => _open(context),
      borderRadius: 10,
      listIndex: index,
      tvTabId: tvTabId,
      tvRowId: tvRowId,
      tvItemIndex: index,
      child: SizedBox(
        width: _kTrailerCardWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: _kTrailerCardWidth,
                height: thumbHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: trailer.youtubeThumbnail,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => ColoredBox(
                        color: Colors.white.withValues(alpha: 0.06),
                        child: const Icon(Icons.movie_outlined, color: Colors.white24),
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.45),
                          ],
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.black,
                          size: 26,
                        ),
                      ),
                    ),
                    if (trailer.official)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Official',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              trailer.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
