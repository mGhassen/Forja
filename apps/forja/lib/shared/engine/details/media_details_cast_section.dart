import 'package:flutter/material.dart';
import 'package:forja/shell/focus/shell_focusable_tap.dart';
import 'package:forja/shell/tv/shell_tv_focus.dart';
import 'package:forja/shell/tv/tv_focus_graph.dart';
import 'package:forja_foundation/tokens/forja_details_tokens.dart';
import 'package:forja_foundation/tokens/forja_motion_theme.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja_foundation/widgets/details/cast_section.dart';

/// Host wire — TV row registration around foundation cast / crew paint.
class MediaDetailsCastSection extends StatelessWidget {
  const MediaDetailsCastSection({
    super.key,
    required this.cast,
    this.title = 'Cast',
    this.outdentHorizontal = 0,
    this.tvTabId,
    this.tvRowId,
    this.tvRowOrder = 0,
    this.tvFocusUp,
  });

  final List<Map<String, String>> cast;
  final String title;
  final double outdentHorizontal;
  final String? tvTabId;
  final String? tvRowId;
  final int tvRowOrder;
  final VoidCallback? tvFocusUp;

  @override
  Widget build(BuildContext context) {
    if (cast.isEmpty) return const SizedBox.shrink();

    final tabId = tvTabId ?? ShellTvFocus.currentNavTabId;
    final rowId = tvRowId ?? 'cast';
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final avatarSize =
        tv ? DetailsTokens.castAvatarSizeTv : DetailsTokens.castAvatarSize;
    final focusScale = ForjaMotionTheme.of(context)
        .resolve(ForjaMotionPreset.cardLift)
        .focusScale;

    final paint = DetailsCastSection(
      cast: cast,
      title: title,
      outdentHorizontal: outdentHorizontal,
      itemBuilder: (context, {required index, required child}) {
        return shellFocusableTap(
          context: context,
          borderRadius: avatarSize / 2,
          showFocusBorder: true,
          showFocusFill: false,
          scaleOnFocus: focusScale,
          listIndex: index,
          tvTabId: tabId,
          tvRowId: tvRowId != null ? rowId : null,
          tvItemIndex: index,
          child: child,
        );
      },
    );

    if (tabId == null || tvRowId == null) return paint;

    return TvKitRow(
      tabId: tabId,
      rowId: rowId,
      sortOrder: tvRowOrder,
      itemCount: cast.length,
      onFocusUp: tvFocusUp,
      child: paint,
    );
  }
}
