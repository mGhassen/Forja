import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja_foundation/components/crossfade_swap.dart';
import 'package:forja_foundation/components/network_image.dart';
import 'package:forja_foundation/tokens/channel_card_tokens.dart';
import 'package:forja_foundation/tokens/forja_motion_theme.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja_foundation/widgets/feedback/card_play_overlay.dart';
import 'package:forja_foundation/widgets/guide/guide_epg_programme.dart';
import 'package:google_fonts/google_fonts.dart';

/// Pre-wipe IPTV live channel tile (logo + title + NOW/NEXT EPG strip).
///
/// Props-only paint — host supplies [health] / [healthListenable], probe via
/// [onInteractiveActive], favorite via [favoriteBuilder], programmes for
/// footer + long-press sheet.
class CatalogChannelCard extends StatefulWidget {
  const CatalogChannelCard({
    super.key,
    required this.title,
    required this.imageUrl,
    this.programmes = const [],
    this.loadProgrammes,
    this.health,
    this.healthListenable,
    this.highlighted = false,
    this.emphasize = false,
    this.showLogo = true,
    this.listLayout = false,
    this.width,
    this.height,
    this.radius,
    this.epgSlotHeight,
    this.titleFontSize,
    this.metaFontSize,
    this.badgeFontSize,
    this.gridIndex,
    this.gridColumns,
    this.onTap,
    this.onInteractiveActive,
    this.onHoldJumpToCategory,
    this.onTvFocusGained,
    this.favoriteBuilder,
    this.onLeftEdge,
    this.onRightEdge,
    this.onUpEdge,
  });

  final String title;
  final String imageUrl;
  final List<GuideEpgProgramme> programmes;

  /// Lazy short-EPG (host). Used when [programmes] is empty / for long-press refresh.
  final Future<List<GuideEpgProgramme>> Function()? loadProgrammes;
  final bool? health;

  /// Per-channel health — preferred so probe results do not rebuild sibling cards.
  final ValueListenable<bool?>? healthListenable;
  /// Sticky last-played / panel id — SoT only; does **not** paint alone.
  final bool highlighted;

  /// Letter-jump / local select lit — same chrome as focus/hover (single owner).
  final bool emphasize;

  /// Leanback lazy logos — false until settle / focus reveal.
  final bool showLogo;

  /// Narrow phone list row (logo + title) instead of grid card.
  final bool listLayout;
  final double? width;
  final double? height;

  /// Pack overrides — omit → [ChannelCardTokens].
  final double? radius;
  final double? epgSlotHeight;
  final double? titleFontSize;
  final double? metaFontSize;
  final double? badgeFontSize;
  final int? gridIndex;
  final int? gridColumns;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onInteractiveActive;

  /// TV: hold OK ~1s (Favorites / Already watched) — no play.
  final VoidCallback? onHoldJumpToCategory;
  final VoidCallback? onTvFocusGained;
  final Widget? Function({required bool active})? favoriteBuilder;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;
  final VoidCallback? onUpEdge;

  /// Desktop/TV live channel tile — leanback uses [ChannelCardTokens.widthTv]
  /// (hand-tuned logo face; denser than film posters).
  static double cardWidth(BuildContext context) {
    if (ShellPaintScope.usesTvDensityOf(context)) {
      return ChannelCardTokens.widthTv;
    }
    return ShellTokens.posterCardWidthMobile;
  }

  static double cardHeight(BuildContext context) {
    return (cardWidth(context) / 0.9).roundToDouble();
  }

  static List<GuideEpgProgramme> programmesFromRaw(dynamic raw) {
    if (raw is! List) return const [];
    final out = <GuideEpgProgramme>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final title = (e['title'] ?? e['name'] ?? '').toString().trim();
      if (title.isEmpty) continue;
      final startMs = _ms(e['startMs'] ?? e['start_timestamp'] ?? e['start']);
      final endMs = _ms(e['endMs'] ?? e['stop_timestamp'] ?? e['end'] ?? e['stop']);
      if (startMs == null || endMs == null || endMs <= startMs) continue;
      out.add(
        GuideEpgProgramme(
          title: title,
          description: (e['description'] ?? '').toString(),
          start: DateTime.fromMillisecondsSinceEpoch(startMs),
          stop: DateTime.fromMillisecondsSinceEpoch(endMs),
        ),
      );
    }
    return out;
  }

  static int? _ms(dynamic v) {
    if (v is! num) return null;
    final n = v.toInt();
    if (n <= 0) return null;
    return n < 100000000000 ? n * 1000 : n;
  }

  @override
  State<CatalogChannelCard> createState() => _CatalogChannelCardState();
}

class _CatalogChannelCardState extends State<CatalogChannelCard> {
  /// Never setState on hover — rebuilding focusableTap mid-hit-test sticks /
  /// freezes the grid (same class as category rail).
  final ValueNotifier<bool> _hoveredN = ValueNotifier(false);
  final ValueNotifier<bool> _focusedN = ValueNotifier(false);
  static _CatalogChannelCardState? _hoverOwner;
  Future<List<GuideEpgProgramme>>? _epgFuture;
  Timer? _okHoldTimer;
  bool _okHoldFired = false;
  static const _okHoldDelay = Duration(seconds: 1);

  bool _activeFor({required bool hovered, required bool focused}) =>
      ShellPaintScope.interactiveActive(
        context,
        hovered: hovered,
        focused: focused,
      ) ||
      widget.emphasize;

  bool get _epgEnabled =>
      widget.programmes.isNotEmpty || widget.loadProgrammes != null;

  bool get _leanbackOnly =>
      ShellPaintScope.usesTvDensityOf(context) &&
      !ShellPaintScope.scaleOnHoverOf(context);

  @override
  void initState() {
    super.initState();
    _epgFuture = _resolveEpg();
  }

  @override
  void didUpdateWidget(covariant CatalogChannelCard previous) {
    super.didUpdateWidget(previous);
    // Ignore loadProgrammes identity — grid rebuilds pass a new closure every
    // frame and would restart every card's FutureBuilder (blank → fill waves).
    if (previous.imageUrl != widget.imageUrl ||
        previous.title != widget.title ||
        (previous.loadProgrammes == null) != (widget.loadProgrammes == null) ||
        (!identical(previous.programmes, widget.programmes) &&
            widget.programmes.isNotEmpty)) {
      _epgFuture = _resolveEpg();
    }
    if (previous.emphasize != widget.emphasize) {
      widget.onInteractiveActive?.call(
        widget.emphasize || _hoveredN.value || _focusedN.value,
      );
    }
  }

  Future<List<GuideEpgProgramme>> _resolveEpg() async {
    if (widget.programmes.isNotEmpty) return widget.programmes;
    final load = widget.loadProgrammes;
    if (load == null) return const [];
    try {
      return await load();
    } catch (_) {
      return const [];
    }
  }

  void _setHovered(bool v) {
    if (v) {
      final prev = _hoverOwner;
      if (prev != null && prev != this && prev.mounted) {
        prev._hoveredN.value = false;
        prev.widget.onInteractiveActive?.call(prev._focusedN.value);
      }
      _hoverOwner = this;
      if (_hoveredN.value) return;
      _hoveredN.value = true;
      widget.onInteractiveActive?.call(true);
      return;
    }
    if (_hoverOwner == this) _hoverOwner = null;
    if (!_hoveredN.value) return;
    _hoveredN.value = false;
    widget.onInteractiveActive?.call(_focusedN.value);
  }

  void _setFocused(bool v) {
    if (_focusedN.value == v) return;
    if (!v) {
      _okHoldTimer?.cancel();
      _okHoldTimer = null;
      _okHoldFired = false;
    }
    _focusedN.value = v;
    widget.onInteractiveActive?.call(v || _hoveredN.value);
    if (v) widget.onTvFocusGained?.call();
  }

  @override
  void dispose() {
    _okHoldTimer?.cancel();
    if (_hoverOwner == this) _hoverOwner = null;
    widget.onInteractiveActive?.call(false);
    _hoveredN.dispose();
    _focusedN.dispose();
    super.dispose();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    final jump = widget.onHoldJumpToCategory;
    if (jump == null || !_leanbackOnly) return KeyEventResult.ignored;
    final activate = ShellPaintScope.maybeOf(context)?.isActivateKey;
    final isActivate = activate != null
        ? activate(event)
        : (event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter ||
            event.logicalKey == LogicalKeyboardKey.space);
    if (!isActivate) return KeyEventResult.ignored;
    if (event is KeyDownEvent) {
      _okHoldFired = false;
      _okHoldTimer?.cancel();
      _okHoldTimer = Timer(_okHoldDelay, () {
        if (!mounted) return;
        _okHoldFired = true;
        jump();
      });
      return KeyEventResult.handled;
    }
    if (event is KeyUpEvent) {
      _okHoldTimer?.cancel();
      _okHoldTimer = null;
      if (_okHoldFired) {
        _okHoldFired = false;
        return KeyEventResult.handled;
      }
      widget.onTap?.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Color _surface(bool? health, bool active) {
    if (health == false) {
      return const Color(0xFFEF4444).withValues(alpha: active ? 0.11 : 0.08);
    }
    return Colors.white.withValues(alpha: active ? 0.09 : 0.05);
  }

  Color _border(bool? health, bool active) {
    // Single chrome owner: focus / hover / letter-jump lit only.
    // Sticky [highlighted] is land/scroll SoT — never a second border.
    if (health == null) {
      return Colors.white.withValues(alpha: active ? 0.18 : 0.08);
    }
    if (health) {
      return const Color(0xFF22C55E).withValues(alpha: active ? 0.62 : 0.45);
    }
    return const Color(0xFFEF4444).withValues(alpha: active ? 0.72 : 0.55);
  }

  /// Sources / Portals list chrome (bordered rect + inner left probe bar).
  Color _listBackground(bool active) {
    if (active) return ForjaShellColors.chipSelectedBg;
    return Colors.white.withValues(alpha: 0.04);
  }

  Color _listBorder(bool active) {
    if (active) return ForjaShellColors.chipSelectedBorder;
    return Colors.white.withValues(alpha: 0.07);
  }

  double _listBorderWidth(bool active) {
    if (active) return 1.5;
    return 1;
  }

  Color _listLeftBar(bool? health, bool active) {
    if (active) return ForjaShellColors.brandGreen;
    return switch (health) {
      true => const Color(0xFF22C55E),
      false => const Color(0xFFEF4444),
      null => Colors.transparent,
    };
  }

  Future<void> _showEpgSheet() async {
    if (!_epgEnabled) return;
    final future = _epgFuture ?? _resolveEpg();
    _epgFuture = future;
    final list = await future;
    if (!mounted || list.isEmpty) return;
    final tv = ShellPaintScope.usesTvDensityOf(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: ForjaShellColors.surfaceElevated,
      builder: (_) => _ChannelEpgSheet(
        title: widget.title,
        programmes: list,
        titleFontSize: widget.titleFontSize ??
            ChannelCardTokens.titleFontSizeOf(tv),
        metaFontSize: widget.metaFontSize ??
            ChannelCardTokens.metaFontSizeOf(tv),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listenable = widget.healthListenable;
    if (listenable != null) {
      return ValueListenableBuilder<bool?>(
        valueListenable: listenable,
        builder: (context, health, _) => _buildCard(context, health: health),
      );
    }
    return _buildCard(context, health: widget.health);
  }

  Widget _buildCard(BuildContext context, {required bool? health}) {
    final holdJump =
        widget.onHoldJumpToCategory != null && _leanbackOnly;
    final radius = widget.radius ?? ChannelCardTokens.radius;

    final painted = ListenableBuilder(
      listenable: Listenable.merge([_hoveredN, _focusedN]),
      builder: (context, _) {
        final active = _activeFor(
          hovered: _hoveredN.value,
          focused: _focusedN.value,
        );
        if (widget.listLayout) {
          return _buildSourcesListRow(
            context,
            active: active,
            health: health,
          );
        }
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: _surface(health, active),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: _border(health, active)),
          ),
          child: _buildDesktopBody(context, active: active, health: health),
        );
      },
    );

    Widget card = ShellPaintScope.focusableTap(
      context: context,
      onTap: holdJump ? null : widget.onTap,
      borderRadius: widget.listLayout ? 0 : radius,
      motion: ForjaMotionPreset.fillOnly,
      gridIndex: widget.gridIndex,
      gridColumns: widget.gridColumns,
      listIndex: widget.listLayout ? widget.gridIndex : null,
      tvZone: widget.listLayout ? ShellPaintTvZone.row : ShellPaintTvZone.grid,
      tvItemIndex: widget.gridIndex,
      onLeftEdge: widget.onLeftEdge,
      onRightEdge: widget.onRightEdge,
      onUpEdge: widget.onUpEdge,
      onFocusChange: _setFocused,
      onKeyEvent: holdJump ? _onKeyEvent : null,
      child: MouseRegion(
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        child: painted,
      ),
    );

    if (!_leanbackOnly && _epgEnabled) {
      card = GestureDetector(
        onLongPress: _showEpgSheet,
        child: card,
      );
    }

    // Sticky last-played stays in semantics only — not a second paint border.
    return Semantics(
      selected: widget.highlighted,
      child: card,
    );
  }

  /// Flat Sources-panel row — bordered rect + inner left health/selection bar.
  Widget _buildSourcesListRow(
    BuildContext context, {
    required bool active,
    required bool? health,
  }) {
    final fav = widget.favoriteBuilder?.call(active: active);
    final titleColor = active
        ? ForjaShellColors.brandGreen
        : health == false
            ? Colors.white54
            : ForjaShellColors.cinematic.textPrimary;

    return SizedBox(
      width: widget.width,
      height: widget.height ?? 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _listBackground(active),
          border: Border.all(
            color: _listBorder(active),
            width: _listBorderWidth(active),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredBox(
              color: _listLeftBar(health, active),
              child: const SizedBox(width: 4),
            ),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: _logoThumb(
                          contain: true,
                          padding: 2,
                          cacheWidth: 72,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CrossfadeSwap(
                        child: Text(
                          widget.title,
                          key: ValueKey(widget.title),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: titleColor,
                            fontSize: 13,
                            height: 1.25,
                            fontWeight:
                                active ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    if (fav != null) ...[const SizedBox(width: 8), fav],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopBody(
    BuildContext context, {
    required bool active,
    required bool? health,
  }) {
    final fav = widget.favoriteBuilder?.call(active: active);
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final radius = widget.radius ?? ChannelCardTokens.radiusOf(tv);
    final topRadius = BorderRadius.vertical(top: Radius.circular(radius));
    final titleBarH = ChannelCardTokens.titleBarHeightOf(tv);
    final titleSize = widget.titleFontSize ??
        ChannelCardTokens.cardTitleFontSizeOf(tv);
    final logoPad = ChannelCardTokens.logoPadOf(tv);
    final titlePadH = ChannelCardTokens.titleBarPadHOf(tv);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Full logo band = remaining card face (title + EPG are fixed height).
        // No inset AspectRatio square — that painted a second surface that only
        // showed on focus/hover when the card face lightened.
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: topRadius,
                  child: _logoThumb(
                    contain: true,
                    padding: logoPad,
                  ),
                ),
              ),
              if (active)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0x52000000),
                      borderRadius: topRadius,
                    ),
                  ),
                ),
              ShellCardPlayOverlay(active: false, visible: active),
              if (fav != null)
                Positioned(top: 4, left: 4, child: fav),
              if (health != null)
                Positioned(
                  top: 6,
                  right: 6,
                  child: _healthDot(health),
                ),
            ],
          ),
        ),
        SizedBox(
          height: titleBarH,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: titlePadH),
            // No Tooltip — hover overlay steals MouseRegion and freezes the grid.
            child: Align(
              alignment: Alignment.centerLeft,
              child: CrossfadeSwap(
                child: Text(
                  widget.title,
                  key: ValueKey(widget.title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: health == false
                        ? Colors.white54
                        : Colors.white,
                    fontSize: titleSize,
                    height: 1.15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
        _EpgNowFooter(
          future: _epgFuture,
          epgSlotHeight: widget.epgSlotHeight ??
              ChannelCardTokens.epgSlotHeightOf(tv),
          badgeFontSize: widget.badgeFontSize ??
              ChannelCardTokens.badgeFontSizeOf(tv),
        ),
      ],
    );
  }

  Widget _logoThumb({
    required bool contain,
    double padding = 0,
    int? cacheWidth,
  }) {
    if (!widget.showLogo) {
      return const SizedBox.expand(child: _ChannelPlaceholder());
    }
    final icon = widget.imageUrl.trim();
    if (icon.isEmpty) {
      return const SizedBox.expand(child: _ChannelPlaceholder());
    }
    final image = ForjaNetworkImage(
      key: ValueKey(icon),
      url: icon,
      fit: contain ? BoxFit.contain : BoxFit.cover,
      alignment: Alignment.center,
      memCacheWidth: cacheWidth,
      filterQuality:
          cacheWidth != null ? FilterQuality.low : FilterQuality.medium,
      useOldImageOnUrlChange: false,
      // Card face is the underlay — no elevated square that only shows on focus.
      paintUnderlay: false,
      placeholder: const _ChannelPlaceholder(),
      error: const _ChannelPlaceholder(),
    );
    if (!contain) return SizedBox.expand(child: image);
    return Padding(
      padding: EdgeInsets.all(padding),
      child: SizedBox.expand(child: image),
    );
  }

  Widget _healthDot(bool ok, {bool compact = false}) {
    final size = compact ? 8.0 : 10.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ok ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
        border: Border.all(color: Colors.black54, width: 1),
      ),
    );
  }
}

class _EpgNowFooter extends StatefulWidget {
  const _EpgNowFooter({
    required this.future,
    required this.epgSlotHeight,
    required this.badgeFontSize,
  });

  final Future<List<GuideEpgProgramme>>? future;
  final double epgSlotHeight;
  final double badgeFontSize;

  @override
  State<_EpgNowFooter> createState() => _EpgNowFooterState();
}

class _EpgNowFooterState extends State<_EpgNowFooter> {
  List<GuideEpgProgramme> _last = const [];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.epgSlotHeight,
      child: widget.future == null
          ? const SizedBox.shrink()
          : FutureBuilder<List<GuideEpgProgramme>>(
              future: widget.future,
              builder: (context, snap) {
                final programmes = snap.data;
                if (programmes != null && programmes.isNotEmpty) {
                  _last = programmes;
                }
                final show = (programmes != null && programmes.isNotEmpty)
                    ? programmes
                    : _last;
                if (show.isEmpty) {
                  return const SizedBox.shrink();
                }
                var now = show.first;
                for (final e in show) {
                  if (e.isNow) {
                    now = e;
                    break;
                  }
                }
                return Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                  child: Row(
                    children: [
                      CrossfadeSwap(
                        child: Container(
                          key: ValueKey(now.isNow ? 'now' : 'next'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: now.isNow
                                ? const Color(0xFFEF4444)
                                : ForjaShellColors.chipSelectedBorder
                                    .withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            now.isNow ? 'NOW' : 'NEXT',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: widget.badgeFontSize,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: CrossfadeSwap(
                          child: Text(
                            now.title.isEmpty ? '-' : now.title,
                            key: ValueKey(now.title),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white70,
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _ChannelEpgSheet extends StatelessWidget {
  const _ChannelEpgSheet({
    required this.title,
    required this.programmes,
    required this.titleFontSize,
    required this.metaFontSize,
  });

  final String title;
  final List<GuideEpgProgramme> programmes;
  final double titleFontSize;
  final double metaFontSize;

  String _fmt(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final e in programmes)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 86,
                                child: Text(
                                  '${_fmt(e.start)}–${_fmt(e.stop)}',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: e.isNow
                                        ? const Color(0xFFEF4444)
                                        : Colors.white60,
                                    fontSize: metaFontSize,
                                    fontWeight: e.isNow
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.title.isEmpty ? '-' : e.title,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (e.description.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          e.description,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.plusJakartaSans(
                                            color: Colors.white60,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelPlaceholder extends StatelessWidget {
  const _ChannelPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.tv_rounded, color: Colors.white24, size: 36),
    );
  }
}
