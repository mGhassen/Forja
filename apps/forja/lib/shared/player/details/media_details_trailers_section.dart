import 'package:flutter/material.dart';
import 'package:forja/shared/player/platform/youtube_stream_service.dart';
import 'package:forja/shell/focus/shell_focusable_tap.dart';
import 'package:forja/shell/tv/shell_tv_focus.dart';
import 'package:forja/shell/tv/tv_focus_graph.dart';
import 'package:forja/shell/routing/app_router.dart';
import 'package:forja_foundation/widgets/details/trailers_section.dart';
import 'package:rust/rust.dart';

/// Host wire — prefetch + trailer player open around foundation trailers paint.
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
  @override
  void initState() {
    super.initState();
    _prefetch();
  }

  @override
  void didUpdateWidget(covariant MediaDetailsTrailersSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameKeys(oldWidget.trailers, widget.trailers)) {
      _prefetch();
    }
  }

  void _prefetch() {
    YoutubeStreamService.prefetch(widget.trailers.map((t) => t.key));
  }

  bool _sameKeys(List<MediaTrailer> a, List<MediaTrailer> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].key != b[i].key) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final trailers = widget.trailers;
    if (trailers.isEmpty) return const SizedBox.shrink();

    final tabId = widget.tvTabId ?? ShellTvFocus.currentNavTabId;
    final rowId = widget.tvRowId ?? 'trailers';
    final items = [
      for (final t in trailers)
        DetailsTrailerItem(
          key: t.key,
          name: t.name,
          thumbnailUrl: t.youtubeThumbnail,
          official: t.official,
        ),
    ];

    final paint = DetailsTrailersSection(
      trailers: items,
      outdentHorizontal: widget.outdentHorizontal,
      onTap: (index) {
        AppRouter.openTrailerPlayer(
          context,
          trailers: trailers,
          initialIndex: index,
          movie: widget.movie,
          languageCode: widget.languageCode,
        );
      },
      itemBuilder: (context, {required index, required child}) {
        return shellFocusableTap(
          context: context,
          onTap: () {
            AppRouter.openTrailerPlayer(
              context,
              trailers: trailers,
              initialIndex: index,
              movie: widget.movie,
              languageCode: widget.languageCode,
            );
          },
          borderRadius: 10,
          showFocusBorder: true,
          focusBleedWidth: DetailsTrailersSection.cardWidth,
          listIndex: index,
          tvTabId: tabId,
          tvRowId: widget.tvRowId != null ? rowId : null,
          tvItemIndex: index,
          child: child,
        );
      },
    );

    if (tabId == null || widget.tvRowId == null) return paint;

    return TvKitRow(
      tabId: tabId,
      rowId: rowId,
      sortOrder: widget.tvRowOrder,
      itemCount: trailers.length,
      onFocusUp: widget.tvFocusUp,
      child: paint,
    );
  }
}
