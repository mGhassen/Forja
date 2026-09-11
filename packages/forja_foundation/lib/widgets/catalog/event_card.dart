import 'package:flutter/material.dart';
import 'package:forja_foundation/components/network_image.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/utils/cover_urls.dart';

/// Landscape schedule/event card paint — props only (RFC-106 Zone A).
class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.title,
    required this.width,
    required this.height,
    this.posterUrl = '',
    this.homeTeam,
    this.awayTeam,
    this.homeBadgeUrl = '',
    this.awayBadgeUrl = '',
    this.categoryLabel = '',
    this.scheduleLabel = '',
    this.timeLabel = '',
    this.viewers = 0,
    this.live = false,
    this.selected = false,
    this.active = false,
    this.tvDensity = false,
    this.onTap,
    this.borderRadius = 14,
    this.titleFontSize = 12,
    this.playOverlay,
  });

  final String title;
  final String posterUrl;
  final String? homeTeam;
  final String? awayTeam;
  final String homeBadgeUrl;
  final String awayBadgeUrl;
  final String categoryLabel;
  final String scheduleLabel;
  final String timeLabel;
  final int viewers;
  final bool live;
  final bool selected;
  final bool active;
  final bool tvDensity;
  final double width;
  final double height;
  final double borderRadius;
  final double titleFontSize;
  final VoidCallback? onTap;

  /// Optional play glyph (host [ShellCardPlayOverlay]).
  final Widget? playOverlay;

  bool get _hasTeams =>
      homeTeam != null &&
      homeTeam!.isNotEmpty &&
      awayTeam != null &&
      awayTeam!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final poster = resolveAbsoluteCoverUrl(posterUrl);
    final Widget card;
    if (tvDensity) {
      card = _TvCaptionBody(
        active: active || selected,
        title: title,
        schedule: scheduleLabel.isEmpty ? null : scheduleLabel,
        subtitle: viewers > 0 ? '$viewers viewers' : null,
        titleFontSize: titleFontSize,
        borderRadius: borderRadius,
        visual: _tvVisual(poster),
        overlays: [
          if (live && playOverlay != null) playOverlay!,
          if (categoryLabel.isNotEmpty)
            _CornerBadge(
              label: categoryLabel.toUpperCase(),
              live: false,
              right: null,
              left: 6,
              top: 6,
            ),
          if (live)
            const _CornerBadge(label: '● LIVE', live: true, top: 6)
          else if (timeLabel.isNotEmpty)
            _CornerBadge(label: timeLabel, live: false, top: 6),
        ],
      );
    } else {
      card = AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          color: (active || selected)
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.06),
          border: Border.all(
            color: (active || selected)
                ? ForjaShellColors.chipSelectedBorder
                : ForjaShellColors.cinematic.borderSubtle,
            width: 1.5,
          ),
          boxShadow: (active || selected)
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
          borderRadius: BorderRadius.circular(borderRadius - 1),
          child: Stack(
            children: [
              if (poster.isNotEmpty)
                Positioned.fill(
                  child: ForjaNetworkImage(
                    url: poster,
                    fit: BoxFit.cover,
                    error: const SizedBox.shrink(),
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
                      child: _hasTeams
                          ? Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _TeamBadge(
                                    badge: resolveAbsoluteCoverUrl(homeBadgeUrl),
                                    name: homeTeam!,
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
                                    badge: resolveAbsoluteCoverUrl(awayBadgeUrl),
                                    name: awayTeam!,
                                    showName: false,
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    _TitleStack(
                      title: title,
                      schedule: scheduleLabel.isEmpty ? null : scheduleLabel,
                      rightPadding: viewers > 0 ? 52 : 0,
                    ),
                  ],
                ),
              ),
              if (live && playOverlay != null) playOverlay!,
              if (categoryLabel.isNotEmpty)
                _CornerBadge(
                  label: categoryLabel.toUpperCase(),
                  live: false,
                  right: null,
                  left: 8,
                  top: 8,
                ),
              if (live)
                const _CornerBadge(label: '● LIVE', live: true, top: 8)
              else if (timeLabel.isNotEmpty)
                _CornerBadge(label: timeLabel, live: false, top: 8),
              if (viewers > 0) _ViewerBadge(viewers: viewers),
            ],
          ),
        ),
      );
    }

    final sized = SizedBox(width: width, height: height, child: card);
    if (onTap == null) return sized;
    return GestureDetector(onTap: onTap, child: sized);
  }

  Widget _tvVisual(String poster) {
    if (_hasTeams) {
      return Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _TeamBadge(
              badge: resolveAbsoluteCoverUrl(homeBadgeUrl),
              name: homeTeam!,
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
              badge: resolveAbsoluteCoverUrl(awayBadgeUrl),
              name: awayTeam!,
              showName: false,
              radius: 16,
            ),
          ],
        ),
      );
    }
    if (poster.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: ForjaNetworkImage(
          url: poster,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          error: const Center(
            child: Icon(Icons.sports_rounded, color: Colors.white38, size: 36),
          ),
        ),
      );
    }
    return const Center(
      child: Icon(Icons.sports_rounded, color: Colors.white38, size: 36),
    );
  }
}

class _TeamBadge extends StatelessWidget {
  const _TeamBadge({
    required this.badge,
    required this.name,
    this.showName = true,
    this.radius = 18,
  });

  final String badge;
  final String name;
  final bool showName;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white12,
      child: badge.isNotEmpty
          ? ForjaNetworkImage(
              url: badge,
              width: radius * 1.67,
              height: radius * 1.67,
              fit: BoxFit.contain,
              error: Text(
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
    required this.titleFontSize,
    required this.borderRadius,
    this.schedule,
    this.subtitle,
    this.overlays = const [],
  });

  final bool active;
  final Widget visual;
  final String title;
  final double titleFontSize;
  final double borderRadius;
  final String? schedule;
  final String? subtitle;
  final List<Widget> overlays;

  @override
  Widget build(BuildContext context) {
    const inset = 8.0;
    return AnimatedContainer(
      duration: Duration.zero,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: active
              ? ForjaShellColors.chipSelectedBorder
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
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
                      padding: const EdgeInsets.fromLTRB(inset, inset + 2, inset, 4),
                      child: visual,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(inset, 0, inset, inset),
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
                              fontSize: (titleFontSize - 1).clamp(9.0, 11.0),
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
                            fontSize: titleFontSize,
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
                              fontSize: (titleFontSize - 1).clamp(9.0, 11.0),
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
    final bg = live ? Colors.red.shade700 : Colors.black54;
    return Positioned(
      top: top,
      left: left,
      right: right,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
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
