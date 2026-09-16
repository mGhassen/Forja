import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forja_foundation/components/network_image.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/widgets/catalog/interactive_poster_card.dart';
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
    this.width,
    this.height,
    this.gridIndex,
    this.gridColumns,
    this.onTap,
    this.onInteractiveActive,
    this.favoriteBuilder,
  });

  final String title;
  final String imageUrl;
  final List<GuideEpgProgramme> programmes;

  /// Lazy short-EPG (host). Used when [programmes] is empty / for long-press refresh.
  final Future<List<GuideEpgProgramme>> Function()? loadProgrammes;
  final bool? health;

  /// Per-channel health — preferred so probe results do not rebuild sibling cards.
  final ValueListenable<bool?>? healthListenable;
  final bool highlighted;
  final double? width;
  final double? height;
  final int? gridIndex;
  final int? gridColumns;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onInteractiveActive;
  final Widget? Function({required bool active})? favoriteBuilder;

  /// Desktop ~180× aspect 0.9; TV = portrait poster cell.
  static double cardWidth(BuildContext context) {
    if (ShellPaintScope.usesTvDensityOf(context)) {
      return InteractivePosterCard.cardWidth(context);
    }
    return 180;
  }

  static double cardHeight(BuildContext context) {
    if (ShellPaintScope.usesTvDensityOf(context)) {
      return InteractivePosterCard.cardHeight(context);
    }
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
  bool _hovered = false;
  bool _focused = false;
  Future<List<GuideEpgProgramme>>? _epgFuture;

  bool get _active => ShellPaintScope.interactiveActive(
        context,
        hovered: _hovered,
        focused: _focused,
      );

  bool get _epgEnabled =>
      widget.programmes.isNotEmpty || widget.loadProgrammes != null;

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
    if (_hovered == v) return;
    setState(() => _hovered = v);
    widget.onInteractiveActive?.call(v || _focused);
  }

  void _setFocused(bool v) {
    if (_focused == v) return;
    setState(() => _focused = v);
    widget.onInteractiveActive?.call(v || _hovered);
  }

  @override
  void dispose() {
    widget.onInteractiveActive?.call(false);
    super.dispose();
  }

  Color _surface(bool? health, bool active) {
    if (health == false) {
      return const Color(0xFFEF4444).withValues(alpha: active ? 0.11 : 0.08);
    }
    return Colors.white.withValues(alpha: active ? 0.09 : 0.05);
  }

  Color _border(bool? health, bool active) {
    if (widget.highlighted && !active) {
      return ForjaShellColors.chipSelectedBorder;
    }
    if (health == null) {
      return Colors.white.withValues(alpha: active ? 0.18 : 0.08);
    }
    if (health) {
      return const Color(0xFF22C55E).withValues(alpha: active ? 0.62 : 0.45);
    }
    return const Color(0xFFEF4444).withValues(alpha: active ? 0.72 : 0.55);
  }

  Future<void> _showEpgSheet() async {
    if (!_epgEnabled) return;
    final future = _epgFuture ?? _resolveEpg();
    _epgFuture = future;
    final list = await future;
    if (!mounted || list.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: ForjaShellColors.surfaceElevated,
      builder: (_) => _ChannelEpgSheet(
        title: widget.title,
        programmes: list,
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
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final active = _active;
    final radius = tv ? InteractivePosterCard.cardBorderRadius(context) : 12.0;
    final body = tv
        ? _buildTvBody(context, active: active, health: health)
        : _buildDesktopBody(context, active: active, health: health);

    // Instant hover chrome — AnimatedContainer on every tile while sweeping
    // the mouse is the stutter (grid health rebuilds made it worse).
    Widget card = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: tv ? Colors.transparent : _surface(health, active || widget.highlighted),
        borderRadius: BorderRadius.circular(radius),
        border: tv && !active && !widget.highlighted
            ? Border.all(color: Colors.transparent)
            : Border.all(color: _border(health, active)),
      ),
      child: ShellPaintScope.focusableTap(
        context: context,
        onTap: widget.onTap,
        borderRadius: radius,
        scaleOnFocus: 1.0,
        gridIndex: widget.gridIndex,
        gridColumns: widget.gridColumns,
        tvZone: ShellPaintTvZone.grid,
        tvItemIndex: widget.gridIndex,
        onFocusChange: _setFocused,
        onHoverChange: _setHovered,
        child: body,
      ),
    );

    if (!tv && _epgEnabled) {
      card = GestureDetector(
        onLongPress: _showEpgSheet,
        child: card,
      );
    }

    return card;
  }

  Widget _buildDesktopBody(
    BuildContext context, {
    required bool active,
    required bool? health,
  }) {
    final fav = widget.favoriteBuilder?.call(active: active);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: _logoThumb(contain: true, padding: 10),
              ),
              if (active)
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0x52000000),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
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
        Padding(
          padding: const EdgeInsets.all(8),
          child: Tooltip(
            message: widget.title,
            waitDuration: const Duration(milliseconds: 600),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Text(
                  widget.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                  style: GoogleFonts.plusJakartaSans(
                    color: health == false
                        ? Colors.white54
                        : Colors.white,
                    fontSize: 12,
                    height: 1.15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
        _EpgNowFooter(future: _epgFuture),
      ],
    );
  }

  Widget _buildTvBody(
    BuildContext context, {
    required bool active,
    required bool? health,
  }) {
    final radius = InteractivePosterCard.cardBorderRadius(context);
    final inset = InteractivePosterCard.scaled(context, 8).clamp(4.0, 8.0);
    final titleSize = InteractivePosterCard.titleFontSize(context);
    final fav = widget.favoriteBuilder?.call(active: active);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: Colors.white.withValues(alpha: 0.03),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(inset, inset + 2, inset, 4),
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: _logoThumb(
                          contain: true,
                          padding: 6,
                          cacheWidth: 160,
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(inset, 0, inset, inset),
                  child: Text(
                    widget.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: health == false
                          ? Colors.white54
                          : Colors.white,
                      fontSize: titleSize,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ShellCardPlayOverlay(
            active: false,
            visible: active,
            diameter: 28,
            iconSize: 16,
          ),
          if (fav != null)
            Positioned(top: inset, left: inset, child: fav),
          if (health != null)
            Positioned(
              top: inset,
              right: inset,
              child: _healthDot(health, compact: true),
            ),
        ],
      ),
    );
  }

  Widget _logoThumb({
    required bool contain,
    double padding = 0,
    int? cacheWidth,
  }) {
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
  const _EpgNowFooter({required this.future});

  final Future<List<GuideEpgProgramme>>? future;

  @override
  State<_EpgNowFooter> createState() => _EpgNowFooterState();
}

class _EpgNowFooterState extends State<_EpgNowFooter> {
  static const _slotHeight = 22.0;
  List<GuideEpgProgramme> _last = const [];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _slotHeight,
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
                      Container(
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
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          now.title.isEmpty ? '-' : now.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white70,
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
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
  });

  final String title;
  final List<GuideEpgProgramme> programmes;

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
                  fontSize: 14,
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
                                    fontSize: 11,
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
