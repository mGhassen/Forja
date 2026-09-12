import 'package:flutter/material.dart';
import 'package:forja/shared/engine/hub/kit_event_paint.dart';
import 'package:forja/shared/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/shell/forja_shell_layout.dart';
import 'package:forja/shared/shell/forja_shell_scope.dart';
import 'package:forja/shared/shell/forja_shell_input_policy.dart';
import 'package:forja/shared/shell/shell_focusable_tap.dart';
import 'package:forja/shared/shell/shell_card_play_overlay.dart';
import 'package:forja_foundation/widgets/catalog/event_card.dart';

export 'package:forja_foundation/widgets/catalog/event_card.dart' show EventCard;

/// Host TV/focus wrapper around [EventCard].
class KitEventCard extends StatefulWidget {
  const KitEventCard({
    super.key,
    required this.event,
    required this.onTap,
    this.gridIndex,
    this.gridColumns,
    this.onUpEdge,
    this.onLeftEdge,
    this.onRightEdge,
    this.selected = false,
    this.tvTabId = 'kit_cards',
    this.tvRowId = 'schedule',
    this.tvZone = ShellTvZone.grid,
    this.viewersOverride,
    this.width,
    this.height,
  });

  final KitEventPaint event;
  final VoidCallback onTap;
  final int? gridIndex;
  final int? gridColumns;
  final VoidCallback? onUpEdge;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;
  final bool selected;
  final String tvTabId;
  final String tvRowId;
  final ShellTvZone tvZone;
  final int? viewersOverride;
  final double? width;
  final double? height;

  static const widthScale = 1.15;
  static const heightScale = 1.32;

  static double tvCaptionBand(BuildContext context) =>
      shellScaled(context, 40).clamp(32.0, 48.0);

  static double cardWidth(BuildContext context) {
    if (ShellScope.metricsOf(context).usesTvDensity) {
      return shellContinueWatchingCardWidth(context);
    }
    return shellContinueWatchingCardWidth(context) * widthScale;
  }

  static double cardHeight(BuildContext context) {
    if (ShellScope.metricsOf(context).usesTvDensity) {
      return shellContinueWatchingCardHeight(context) + tvCaptionBand(context);
    }
    final height = shellContinueWatchingCardHeight(context) * heightScale;
    return height.clamp(190.0, 230.0);
  }

  static double gridGap(BuildContext context) =>
      shellPosterCardRowGap(context).clamp(8.0, 12.0);

  @override
  State<KitEventCard> createState() => _KitEventCardState();
}

class _KitEventCardState extends State<KitEventCard> {
  bool _hovered = false;
  bool _focused = false;

  int get _viewers => widget.viewersOverride ?? widget.event.viewers;

  @override
  Widget build(BuildContext context) {
    final m = widget.event;
    final live = m.isLive;
    final policy = ShellScope.inputPolicyOf(context);
    final tv = ShellScope.metricsOf(context).usesTvDensity;
    final active = ShellInputPolicy.interactiveActive(
          policy,
          hovered: _hovered,
          focused: _focused,
          context: context,
        ) ||
        widget.selected;
    final w = widget.width ?? KitEventCard.cardWidth(context);
    final h = widget.height ?? KitEventCard.cardHeight(context);
    final radius = tv ? shellCardBorderRadius(context) : 14.0;

    return shellFocusableTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: radius,
      scaleOnFocus: 1.0,
      gridIndex: widget.tvZone == ShellTvZone.grid ? widget.gridIndex : null,
      gridColumns:
          widget.tvZone == ShellTvZone.grid ? widget.gridColumns : null,
      listIndex: widget.tvZone == ShellTvZone.row ? widget.gridIndex : null,
      onUpEdge: widget.onUpEdge,
      onLeftEdge: widget.onLeftEdge,
      onRightEdge: widget.onRightEdge,
      tvTabId: widget.tvTabId,
      tvRowId: widget.tvRowId,
      tvZone: widget.tvZone,
      tvItemIndex: widget.gridIndex,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onHoverChange: (hovered) => setState(() => _hovered = hovered),
      child: EventCard(
        title: m.title,
        posterUrl: kitEventImageUrl(m.poster),
        homeTeam: m.homeTeam,
        awayTeam: m.awayTeam,
        homeBadgeUrl: kitEventImageUrl(m.homeBadge ?? ''),
        awayBadgeUrl: kitEventImageUrl(m.awayBadge ?? ''),
        categoryLabel: m.categoryLabel,
        scheduleLabel: kitEventScheduleLabel(m),
        timeLabel: kitEventTimeLabel(m),
        viewers: _viewers,
        live: live,
        selected: widget.selected,
        active: active,
        tvDensity: tv,
        width: w,
        height: h,
        borderRadius: radius,
        titleFontSize: shellHubCardTitleFontSize(context),
        playOverlay: live
            ? ShellCardPlayOverlay(
                active: tv ? true : active,
                visible: true,
                diameter: tv ? 28 : 48,
                iconSize: tv ? 16 : 28,
              )
            : null,
      ),
    );
  }
}
