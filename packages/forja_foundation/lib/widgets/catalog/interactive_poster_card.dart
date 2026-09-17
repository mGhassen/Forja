import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/catalog/poster_card.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

export 'package:forja_foundation/widgets/catalog/poster_card.dart'
    show PosterCard, PosterAspect, RatingBadge, RatingBadgeText;

/// Poster card with [ShellPaintScope.focusableTap] + optional long-press hold.
///
/// Host supplies [listPin] (e.g. list-status button). No Riverpod / MetaItem.
class InteractivePosterCard extends StatefulWidget {
  const InteractivePosterCard({
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
    this.listPin,
    this.listPinBuilder,
    this.listIndex,
    this.gridIndex,
    this.gridColumns,
    this.tvTabId,
    this.tvRowId,
    this.onUpEdge,
    this.onLeftEdge,
    this.onRightEdge,
    this.aspect = PosterAspect.portrait,
    this.width,
    this.height,
  });

  final String imageUrl;
  final String title;
  final String? subtitle;
  final double? rating;
  final int? rank;
  final String? badge;
  final Widget? listPin;

  /// Prefer over [listPin] when the pin should react to hover/focus.
  final Widget? Function({required bool active})? listPinBuilder;
  final int? listIndex;
  final int? gridIndex;
  final int? gridColumns;
  final String? tvTabId;
  final String? tvRowId;
  final VoidCallback? onUpEdge;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Duration longPressDuration;
  final PosterAspect aspect;
  final double? width;
  final double? height;

  static double cardWidth(
    BuildContext context, {
    PosterAspect aspect = PosterAspect.portrait,
  }) {
    if (aspect == PosterAspect.landscape) {
      return _continueWidth(context);
    }
    return _posterWidth(context);
  }

  static double cardHeight(
    BuildContext context, {
    PosterAspect aspect = PosterAspect.portrait,
  }) {
    if (aspect == PosterAspect.landscape) {
      return _continueHeight(context);
    }
    return (_posterWidth(context) * ShellTokens.posterCardAspectRatio)
        .roundToDouble();
  }

  static double _posterWidth(BuildContext context) {
    if (ShellPaintScope.usesTvDensityOf(context)) {
      return ShellTokens.posterCardWidthTv;
    }
    final w = MediaQuery.sizeOf(context).width;
    if (w <= ShellTokens.shellGridTabletMinWidth) {
      return ShellTokens.posterCardWidthMobile;
    }
    return ShellTokens.posterCardWidthDesktop;
  }

  static double _continueWidth(BuildContext context) {
    if (ShellPaintScope.usesTvDensityOf(context)) {
      return ShellTokens.continueWatchingCardWidthTv;
    }
    return ShellTokens.shellContinueWatchingCardWidthDesktop;
  }

  static double _continueHeight(BuildContext context) {
    if (ShellPaintScope.usesTvDensityOf(context)) {
      return ShellTokens.continueWatchingCardWidthTv * 9 / 16;
    }
    return ShellTokens.shellContinueWatchingCardHeightDesktop;
  }

  static double _layoutScale(BuildContext context) {
    if (!ShellPaintScope.usesTvDensityOf(context)) return 1.0;
    final raw =
        _posterWidth(context) / ShellTokens.posterCardWidthDesktop;
    return math.max(ShellTokens.tvLayoutScaleFloor, raw);
  }

  static double scaled(BuildContext context, double value) =>
      value * _layoutScale(context);

  static double cardBorderRadius(BuildContext context) => scaled(
        context,
        ShellTokens.posterCardRadius,
      ).clamp(ShellTokens.posterCardRadiusMin, ShellTokens.posterCardRadius);

  static double titleFontSize(BuildContext context) {
    if (ShellPaintScope.usesTvDensityOf(context)) {
      return ShellTokens.posterTitleFontSizeTv;
    }
    return MediaQuery.sizeOf(context).width <= 600
        ? ShellTokens.posterTitleFontSizeMobile
        : ShellTokens.posterTitleFontSizeDesktop;
  }

  @override
  State<InteractivePosterCard> createState() => _InteractivePosterCardState();
}

class _InteractivePosterCardState extends State<InteractivePosterCard> {
  Timer? _holdTimer;
  bool _longPressFired = false;
  LogicalKeyboardKey? _holdActivateKey;
  bool _hovered = false;
  bool _focused = false;

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
    final key = event.logicalKey;
    final activate = key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space;
    if (!activate) return KeyEventResult.ignored;
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
    final w = widget.width ??
        InteractivePosterCard.cardWidth(context, aspect: widget.aspect);
    final h = widget.height ??
        InteractivePosterCard.cardHeight(context, aspect: widget.aspect);
    final radius = InteractivePosterCard.cardBorderRadius(context);
    final inset = InteractivePosterCard.scaled(context, 10).clamp(4.0, 10.0);
    final inGrid = widget.gridIndex != null && widget.gridColumns != null;
    final active = ShellPaintScope.interactiveActive(
      context,
      hovered: _hovered,
      focused: _focused,
    );
    final pin = widget.listPinBuilder?.call(active: active) ?? widget.listPin;

    Widget card = ShellPaintScope.focusableTap(
      context: context,
      onTap: widget.onLongPress != null ? _onTap : widget.onTap,
      borderRadius: radius,
      showFocusBorder: true,
      listIndex: widget.listIndex,
      gridIndex: widget.gridIndex,
      gridColumns: widget.gridColumns,
      tvTabId: widget.tvTabId,
      tvRowId: widget.tvRowId,
      tvZone: inGrid ? ShellPaintTvZone.grid : ShellPaintTvZone.row,
      tvItemIndex: widget.listIndex ?? widget.gridIndex,
      onUpEdge: widget.onUpEdge,
      onLeftEdge: widget.onLeftEdge,
      onRightEdge: widget.onRightEdge,
      onFocusChange: (f) => setState(() => _focused = f),
      onHoverChange: (h) => setState(() => _hovered = h),
      onKeyEvent: widget.onLongPress != null ? _onTvKey : null,
      child: PosterCard(
        imageUrl: widget.imageUrl,
        title: widget.title,
        subtitle: widget.subtitle,
        rating: widget.rating,
        rank: widget.rank,
        badge: widget.badge,
        listPin: pin,
        aspect: widget.aspect,
        width: w,
        height: h,
        borderRadius: radius,
        titleFontSize: InteractivePosterCard.titleFontSize(context),
        metaFontSize:
            InteractivePosterCard.scaled(context, 11).clamp(7.0, 11.0),
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
