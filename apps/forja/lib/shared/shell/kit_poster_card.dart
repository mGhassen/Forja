import 'package:flutter/material.dart';
import 'package:forja/shared/shell/forja_shell_layout.dart';
import 'package:forja/shared/shell/shell_focusable_tap.dart';
import 'package:forja/shared/engine/lists/list_follow.dart';
import 'package:forja/shared/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/player/details/kit_list_status_button.dart';
import 'package:forja_foundation/widgets/catalog/poster_card.dart';

export 'package:forja_foundation/widgets/catalog/poster_card.dart'
    show PosterCard, PosterAspect, RatingBadge, RatingBadgeText;

/// Host TV/focus wrapper around [PosterCard].
enum KitPosterAspect { portrait, landscape }

class KitPosterCard extends StatelessWidget {
  const KitPosterCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.rating,
    this.rank,
    this.badge,
    this.listTarget,
    this.listPin,
    this.listIndex,
    this.gridIndex,
    this.gridColumns,
    this.tvTabId,
    this.tvRowId,
    this.onUpEdge,
    this.onLeftEdge,
    this.onRightEdge,
    this.aspect = KitPosterAspect.portrait,
  });

  final String imageUrl;
  final String title;
  final String? subtitle;
  final double? rating;
  final int? rank;
  final String? badge;
  final ListFollowTarget? listTarget;
  final Widget? listPin;
  final int? listIndex;
  final int? gridIndex;
  final int? gridColumns;
  final String? tvTabId;
  final String? tvRowId;
  final VoidCallback? onUpEdge;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;
  final VoidCallback onTap;
  final KitPosterAspect aspect;

  static double cardWidth(
    BuildContext context, {
    KitPosterAspect aspect = KitPosterAspect.portrait,
  }) {
    if (aspect == KitPosterAspect.landscape) {
      return shellContinueWatchingCardWidth(context);
    }
    return shellPosterCardWidth(context);
  }

  static double cardHeight(
    BuildContext context, {
    KitPosterAspect aspect = KitPosterAspect.portrait,
  }) {
    if (aspect == KitPosterAspect.landscape) {
      return shellContinueWatchingCardHeight(context);
    }
    return shellPosterCardHeight(context);
  }

  @override
  Widget build(BuildContext context) {
    final posterAspect = aspect == KitPosterAspect.landscape
        ? PosterAspect.landscape
        : PosterAspect.portrait;
    final w = KitPosterCard.cardWidth(context, aspect: aspect);
    final h = KitPosterCard.cardHeight(context, aspect: aspect);
    final radius = shellCardBorderRadius(context);
    final inset = shellScaled(context, 10).clamp(4.0, 10.0);
    final compact = w < 85;
    final pin = listPin ??
        ((!compact && listTarget != null)
            ? KitListStatusButton.follow(
                followTarget: listTarget!,
                excludeFromTvTraversal: true,
                iconSize: shellScaled(context, 18).clamp(12.0, 18.0),
              )
            : null);

    final inGrid = gridIndex != null && gridColumns != null;
    return shellFocusableTap(
      context: context,
      onTap: onTap,
      borderRadius: radius,
      showFocusBorder: true,
      listIndex: listIndex,
      gridIndex: gridIndex,
      gridColumns: gridColumns,
      tvTabId: tvTabId,
      tvRowId: tvRowId,
      tvZone: inGrid ? ShellTvZone.grid : ShellTvZone.row,
      tvItemIndex: listIndex ?? gridIndex,
      onUpEdge: onUpEdge,
      onLeftEdge: onLeftEdge,
      onRightEdge: onRightEdge,
      child: PosterCard(
        imageUrl: imageUrl,
        title: title,
        subtitle: subtitle,
        rating: rating,
        rank: rank,
        badge: badge,
        listPin: pin,
        aspect: posterAspect,
        width: w,
        height: h,
        borderRadius: radius,
        titleFontSize: shellHubCardTitleFontSize(context),
        metaFontSize: shellScaled(context, 11).clamp(7.0, 11.0),
        inset: inset,
      ),
    );
  }
}
