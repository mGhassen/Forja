import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/shell/core/forja_shell_layout.dart';
import 'package:forja/shared/shell/focus/shell_focusable_tap.dart';
import 'package:forja/shared/engine/store/list_follow.dart';
import 'package:forja/shared/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/player/details/kit_list_status_button.dart';
import 'package:forja_foundation/widgets/catalog/poster_card.dart';

export 'package:forja_foundation/widgets/catalog/poster_card.dart'
    show PosterCard, PosterAspect, RatingBadge, RatingBadgeText;

/// Host TV/focus wrapper around [PosterCard].
enum KitPosterAspect { portrait, landscape }

class KitPosterCard extends StatefulWidget {
  const KitPosterCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.onTap,
    this.onLongPress,
    this.longPressDuration = const Duration(milliseconds: 2000),
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
  /// Desktop secondary-click / touch long-press / TV hold (~2s).
  final VoidCallback? onLongPress;
  final Duration longPressDuration;
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
  State<KitPosterCard> createState() => _KitPosterCardState();
}

class _KitPosterCardState extends State<KitPosterCard> {
  Timer? _holdTimer;
  bool _longPressFired = false;
  LogicalKeyboardKey? _holdActivateKey;

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  void _startHold() {
    if (widget.onLongPress == null) return;
    _holdTimer?.cancel();
    _longPressFired = false;
    _holdTimer = Timer(widget.longPressDuration, () {
      if (!mounted) return;
      _longPressFired = true;
      widget.onLongPress!();
    });
  }

  void _cancelHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _holdActivateKey = null;
  }

  void _onTap() {
    if (_longPressFired) {
      _longPressFired = false;
      return;
    }
    widget.onTap();
  }

  KeyEventResult _onTvKey(FocusNode node, KeyEvent event) {
    if (widget.onLongPress == null) return KeyEventResult.ignored;
    if (!shellTvIsActivateLogicalKey(event.logicalKey)) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent) {
      _holdActivateKey = event.logicalKey;
      _startHold();
      return KeyEventResult.handled;
    }
    if (event is KeyRepeatEvent && _holdActivateKey == event.logicalKey) {
      return KeyEventResult.handled;
    }
    if (event is KeyUpEvent && _holdActivateKey == event.logicalKey) {
      final fired = _longPressFired;
      _cancelHold();
      if (!fired) _onTap();
      _longPressFired = false;
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final posterAspect = widget.aspect == KitPosterAspect.landscape
        ? PosterAspect.landscape
        : PosterAspect.portrait;
    final w = KitPosterCard.cardWidth(context, aspect: widget.aspect);
    final h = KitPosterCard.cardHeight(context, aspect: widget.aspect);
    final radius = shellCardBorderRadius(context);
    final inset = shellScaled(context, 10).clamp(4.0, 10.0);
    final compact = w < 85;
    final pin = widget.listPin ??
        ((!compact && widget.listTarget != null)
            ? KitListStatusButton.follow(
                followTarget: widget.listTarget!,
                excludeFromTvTraversal: true,
                iconSize: shellScaled(context, 18).clamp(12.0, 18.0),
              )
            : null);

    final inGrid = widget.gridIndex != null && widget.gridColumns != null;
    Widget card = shellFocusableTap(
      context: context,
      onTap: widget.onLongPress != null ? _onTap : widget.onTap,
      borderRadius: radius,
      showFocusBorder: true,
      listIndex: widget.listIndex,
      gridIndex: widget.gridIndex,
      gridColumns: widget.gridColumns,
      tvTabId: widget.tvTabId,
      tvRowId: widget.tvRowId,
      tvZone: inGrid ? ShellTvZone.grid : ShellTvZone.row,
      tvItemIndex: widget.listIndex ?? widget.gridIndex,
      onUpEdge: widget.onUpEdge,
      onLeftEdge: widget.onLeftEdge,
      onRightEdge: widget.onRightEdge,
      onKeyEvent: widget.onLongPress != null ? _onTvKey : null,
      child: PosterCard(
        imageUrl: widget.imageUrl,
        title: widget.title,
        subtitle: widget.subtitle,
        rating: widget.rating,
        rank: widget.rank,
        badge: widget.badge,
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

    if (widget.onLongPress != null) {
      card = GestureDetector(
        onLongPress: () {
          _longPressFired = true;
          widget.onLongPress!();
        },
        onSecondaryTap: widget.onLongPress,
        child: card,
      );
    }
    return card;
  }
}
