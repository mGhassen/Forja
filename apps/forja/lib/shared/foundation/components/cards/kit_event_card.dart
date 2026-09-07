import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/foundation/lib/match_event.dart';
import 'package:forja/shared/foundation/primitives/primitives.dart';
import 'package:forja/shared/foundation/tv/shell_tv_coordinator.dart';

/// Landscape schedule/event card (Continue-Watching proportions) — cards pack grid.
class KitEventCard extends StatefulWidget {
  const KitEventCard({
    super.key,
    required this.match,
    required this.onTap,
    this.gridIndex,
    this.gridColumns,
    this.onUpEdge,
    this.onLeftEdge,
    this.onRightEdge,
    this.tvTabId = 'kit_cards',
    this.tvRowId = 'schedule',
    this.tvZone = ShellTvZone.grid,
    this.viewersOverride,
  });

  final MatchEvent match;
  final VoidCallback onTap;
  final int? gridIndex;
  final int? gridColumns;
  final VoidCallback? onUpEdge;
  final VoidCallback? onLeftEdge;
  final VoidCallback? onRightEdge;
  final String tvTabId;
  final String tvRowId;
  final ShellTvZone tvZone;
  final int? viewersOverride;

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
    final height =
        shellContinueWatchingCardHeight(context) * heightScale;
    return height.clamp(190.0, 230.0);
  }

  static double gridGap(BuildContext context) =>
      shellMovieCardRowGap(context).clamp(8.0, 12.0);

  @override
  State<KitEventCard> createState() => _KitEventCardState();
}

class _KitEventCardState extends State<KitEventCard> {
  bool _hovered = false;
  bool _focused = false;

  int get _viewers => widget.viewersOverride ?? widget.match.viewers;

  @override
  Widget build(BuildContext context) {
    final m = widget.match;
    final hasTeams = m.homeTeam != null && m.awayTeam != null;
    final live = m.isLive;
    final policy = ShellScope.inputPolicyOf(context);
    final tv = ShellScope.metricsOf(context).usesTvDensity;
    final active = ShellInputPolicy.interactiveActive(
      policy,
      hovered: _hovered,
      focused: _focused,
      context: context,
    );
    final viewers = _viewers;
    final posterUrl = kitEventImageUrl(m.poster);
    final time = kitEventTimeLabel(m);
    final schedule = liveMatchScheduleLabel(m);

    final Widget card;
    if (tv) {
      final Widget visual;
      if (hasTeams) {
        visual = Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _TeamBadge(
                badge: kitEventImageUrl(m.homeBadge ?? ''),
                name: m.homeTeam!,
                showName: false,
                radius: 16,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  'VS',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _TeamBadge(
                badge: kitEventImageUrl(m.awayBadge ?? ''),
                name: m.awayTeam!,
                showName: false,
                radius: 16,
              ),
            ],
          ),
        );
      } else if (posterUrl.isNotEmpty) {
        visual = ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: CachedNetworkImage(
            imageUrl: posterUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorWidget: (_, _, _) => const Center(
              child: Icon(
                Icons.sports_rounded,
                color: Colors.white38,
                size: 36,
              ),
            ),
          ),
        );
      } else {
        visual = const Center(
          child: Icon(Icons.sports_rounded, color: Colors.white38, size: 36),
        );
      }
      card = _TvCaptionBody(
        active: active,
        title: m.title,
        schedule: schedule.isEmpty ? null : schedule,
        subtitle: viewers > 0 ? '$viewers viewers' : null,
        visual: visual,
        overlays: [
          if (live)
            const ShellCardPlayOverlay(
              active: true,
              visible: true,
              diameter: 28,
              iconSize: 16,
            ),
          _CornerBadge(
            label: m.categoryLabel.toUpperCase(),
            live: false,
            right: null,
            left: 6,
            top: 6,
          ),
          if (live)
            const _CornerBadge(label: '● LIVE', live: true, top: 6)
          else if (time.isNotEmpty)
            _CornerBadge(label: time, live: false, top: 6),
        ],
      );
    } else {
      card = AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: active
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.06),
          border: Border.all(
            color: active
                ? ForjaShellColors.chipSelectedBorder
                : ForjaShellColors.cinematic.borderSubtle,
            width: 1.5,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Stack(
            children: [
              if (posterUrl.isNotEmpty)
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: posterUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.45),
                        Colors.black.withValues(alpha: 0.90),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: hasTeams
                          ? Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _TeamBadge(
                                    badge: kitEventImageUrl(m.homeBadge ?? ''),
                                    name: m.homeTeam!,
                                    showName: false,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: Text(
                                      'VS',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ),
                                  _TeamBadge(
                                    badge: kitEventImageUrl(m.awayBadge ?? ''),
                                    name: m.awayTeam!,
                                    showName: false,
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    _TitleStack(
                      title: m.title,
                      schedule: schedule.isEmpty ? null : schedule,
                      rightPadding: viewers > 0 ? 52 : 0,
                    ),
                  ],
                ),
              ),
              if (live)
                ShellCardPlayOverlay(
                  active: active,
                  visible: true,
                  diameter: 48,
                  iconSize: 28,
                ),
              _CornerBadge(
                label: m.categoryLabel.toUpperCase(),
                live: false,
                right: null,
                left: 8,
                top: 8,
              ),
              if (live)
                const _CornerBadge(label: '● LIVE', live: true, top: 8)
              else if (time.isNotEmpty)
                _CornerBadge(label: time, live: false, top: 8),
              if (viewers > 0) _ViewerBadge(viewers: viewers),
            ],
          ),
        ),
      );
    }

    return shellFocusableTap(
      context: context,
      onTap: widget.onTap,
      borderRadius: tv ? shellCardBorderRadius(context) : 14,
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
      child: SizedBox(
        width: KitEventCard.cardWidth(context),
        height: KitEventCard.cardHeight(context),
        child: card,
      ),
    );
  }
}

/// Resolve relative Streamed / pack badge paths to absolute URLs.
String kitEventImageUrl(String path) {
  if (path.isEmpty) return '';
  if (path.startsWith('http')) return path;
  const base = 'https://streamed.pk';
  if (path.startsWith('/')) return '$base$path';
  return '$base/api/images/badge/$path.webp';
}

String kitEventTimeLabel(MatchEvent m) {
  if (m.isLive) return 'live';
  if (m.dateMs <= 0) return '';
  final dt = DateTime.fromMillisecondsSinceEpoch(m.dateMs);
  if (dt.isAfter(DateTime.now())) {
    return _clockHm(dt);
  }
  return '';
}

String liveMatchScheduleLabel(MatchEvent m) {
  if (m.isAlwaysOn) return '';
  if (m.dateMs <= 0) return '';
  return _clockHm(DateTime.fromMillisecondsSinceEpoch(m.dateMs));
}

String _clockHm(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

class _TeamBadge extends StatelessWidget {
  const _TeamBadge({
    required this.badge,
    required this.name,
    this.showName = true,
    this.radius = 18,
  });

  final String? badge;
  final String name;
  final bool showName;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white12,
      child: badge != null && badge!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: badge!,
              width: radius * 1.67,
              height: radius * 1.67,
              fit: BoxFit.contain,
              errorWidget: (_, _, _) => Text(
                name.isNotEmpty ? name[0] : '?',
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : Text(
              name.isNotEmpty ? name[0] : '?',
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
    if (!showName) return avatar;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        avatar,
        const SizedBox(height: 3),
        SizedBox(
          width: 50,
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 8.5),
          ),
        ),
      ],
    );
  }
}

class _TvCaptionBody extends StatelessWidget {
  const _TvCaptionBody({
    required this.active,
    required this.visual,
    required this.title,
    this.schedule,
    this.subtitle,
    this.overlays = const [],
  });

  final bool active;
  final Widget visual;
  final String title;
  final String? schedule;
  final String? subtitle;
  final List<Widget> overlays;

  @override
  Widget build(BuildContext context) {
    final radius = shellCardBorderRadius(context);
    final inset = shellScaled(context, 8).clamp(4.0, 8.0);
    final titleSize = shellHubCardTitleFontSize(context);
    return AnimatedContainer(
      duration: Duration.zero,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: active
              ? ForjaShellColors.chipSelectedBorder
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: ClipRRect(
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
                      child: visual,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(inset, 0, inset, inset),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (schedule != null && schedule!.isNotEmpty) ...[
                          Text(
                            schedule!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: (titleSize - 1).clamp(9.0, 11.0),
                              height: 1.1,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                        ],
                        Text(
                          title,
                          maxLines: subtitle == null ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: titleSize,
                            height: 1.15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: (titleSize - 1).clamp(9.0, 11.0),
                              height: 1.1,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ...overlays,
          ],
        ),
      ),
    );
  }
}

class _CornerBadge extends StatelessWidget {
  const _CornerBadge({
    required this.label,
    required this.live,
    this.top = 8,
    this.left,
    this.right = 8,
  });

  final String label;
  final bool live;
  final double top;
  final double? left;
  final double? right;

  @override
  Widget build(BuildContext context) {
    final fontSize = shellScaled(context, 10).clamp(9.0, 12.0);
    final padH = shellScaled(context, 8).clamp(6.0, 10.0);
    final padV = shellScaled(context, 3).clamp(2.0, 4.0);
    final radius = shellScaled(context, 6).clamp(4.0, 8.0);
    final verticalInset = shellScaled(context, top).clamp(6.0, 10.0);
    final bg = live ? Colors.red.shade700 : Colors.black54;

    return Positioned(
      top: verticalInset,
      left: left,
      right: right,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _ViewerBadge extends StatelessWidget {
  const _ViewerBadge({required this.viewers});

  final int viewers;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 8,
      bottom: 8,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 7, color: Colors.red.shade400),
              const SizedBox(width: 4),
              Text(
                '$viewers',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TitleStack extends StatelessWidget {
  const _TitleStack({
    required this.title,
    this.schedule,
    this.rightPadding = 0,
  });

  final String title;
  final String? schedule;
  final double rightPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: rightPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (schedule != null && schedule!.isNotEmpty) ...[
            Text(
              schedule!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 3),
          ],
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
