import 'package:flutter/material.dart';
import 'package:forja/shared/casting/casting.dart';
import 'package:forja/shared/design/src/forja_shell_colors.dart';
import 'package:forja/shared/widgets/desktop_window_chrome.dart';
import 'package:forja/shared/widgets/hero/hero_meta_line.dart';
import 'package:forja/shared/widgets/hero_overview_text.dart';
import 'package:forja/shared/widgets/hero/hero_title.dart';
import 'package:forja/shared/widgets/watch_progress_bar.dart';
import 'package:rust/rust.dart';

class PlayerFlatIconButton extends StatelessWidget {
  const PlayerFlatIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.onPressedWithContext,
    this.label,
    this.tooltip,
    this.active = false,
    this.size = 40,
    this.iconSize = 22,
  }) : assert(onPressed != null || onPressedWithContext != null);

  final IconData icon;
  final VoidCallback? onPressed;
  final ValueChanged<BuildContext>? onPressedWithContext;
  final String? label;
  final String? tooltip;
  final bool active;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final child = Material(
      color: active ? Colors.white.withValues(alpha: 0.18) : Colors.transparent,
      shape: label == null ? const CircleBorder() : RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: onPressedWithContext != null
            ? () => onPressedWithContext!(context)
            : onPressed,
        customBorder: label == null ? const CircleBorder() : RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: SizedBox(
          width: label == null ? size : null,
          height: size,
          child: label == null
              ? Icon(icon, color: Colors.white, size: iconSize)
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: Colors.white, size: iconSize - 2),
                      const SizedBox(width: 6),
                      Text(label!, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
        ),
      ),
    );
    if (tooltip == null) return child;
    return Tooltip(message: tooltip!, child: child);
  }
}

class PlayerTopBar extends StatelessWidget {
  const PlayerTopBar({
    super.key,
    required this.title,
    this.season,
    this.episode,
    required this.onBack,
    this.trailing,
  });

  final String title;
  final int? season;
  final int? episode;
  final VoidCallback onBack;
  final Widget? trailing;

  String? get _episodeLine {
    if (season == null || episode == null) return null;
    return 'S$season E$episode';
  }

  static double topPadding(BuildContext context) {
    if (DesktopWindowChrome.isDesktop) {
      return DesktopWindowChrome.topInset(context) + 6;
    }
    return MediaQuery.paddingOf(context).top + 6;
  }

  static double totalHeight(BuildContext context) => topPadding(context) + 44 + 6;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(8, topPadding(context), 8, 6),
      child: Row(
          children: [
            PlayerFlatIconButton(
              icon: Icons.arrow_back_rounded,
              onPressed: onBack,
              size: 44,
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_episodeLine != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _episodeLine!,
                      style: TextStyle(
                        color: ForjaShellColors.cinematic.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else
              const SizedBox(width: 44),
          ],
        ),
    );
  }
}

class PlayerTopBarActions extends StatelessWidget {
  const PlayerTopBarActions({
    super.key,
    this.onCast,
    this.showCast = false,
    this.onPip,
    this.showPip = false,
    this.pipActive = false,
  });

  final VoidCallback? onCast;
  final bool showCast;
  final VoidCallback? onPip;
  final bool showPip;
  final bool pipActive;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showCast && onCast != null)
          PlayerFlatIconButton(
            icon: Icons.cast_rounded,
            tooltip: 'Cast',
            onPressed: onCast!,
            size: 44,
          ),
        if (showPip && onPip != null)
          PlayerFlatIconButton(
            icon: pipActive
                ? Icons.picture_in_picture_alt_rounded
                : Icons.picture_in_picture_rounded,
            tooltip: 'Picture in Picture',
            onPressed: onPip!,
            size: 44,
          ),
      ],
    );
  }
}

Future<void> showPlayerCastPicker(
  BuildContext context, {
  required String? streamUrl,
  required String title,
  Map<String, String>? headers,
}) async {
  final casting = CastingService.instance;
  final canCast = casting.isAirPlayAvailable || casting.isChromecastAvailable;
  if (!canCast) return;

  if (streamUrl == null || streamUrl.isEmpty) {
    return;
  }

  CastTarget? target;
  if (casting.isAirPlayAvailable && casting.isChromecastAvailable) {
    target = await showMenu<CastTarget>(
      context: context,
      position: const RelativeRect.fromLTRB(9999, 56, 16, 0),
      items: [
        const PopupMenuItem(
          value: CastTarget.airplay,
          child: Text('AirPlay'),
        ),
        const PopupMenuItem(
          value: CastTarget.chromecast,
          child: Text('Chromecast'),
        ),
      ],
    );
    if (target == null || !context.mounted) return;
  } else if (casting.isAirPlayAvailable) {
    target = CastTarget.airplay;
  } else {
    target = CastTarget.chromecast;
  }

  await casting.castUrl(
    url: streamUrl,
    target: target,
    headers: headers,
    title: title,
  );
}

class PlayerTitleMeta extends StatelessWidget {
  const PlayerTitleMeta({
    super.key,
    required this.title,
    this.movie,
    this.season,
    this.episode,
  });

  final String title;
  final Movie? movie;
  final int? season;
  final int? episode;

  String? _metaLine() {
    if (season != null && episode != null) return 'S$season E$episode';
    final m = movie;
    if (m == null) return null;
    final parts = <String>[];
    if (m.genres.isNotEmpty) parts.add(m.genres.take(2).join(' | '));
    if (m.runtime > 0) {
      parts.add(WatchProgressBar.formatMinutes(m.runtime * 60000));
    }
    if (m.releaseDate.length >= 4) parts.add(m.releaseDate.substring(0, 4));
    return parts.isEmpty ? null : parts.join(' | ');
  }

  @override
  Widget build(BuildContext context) {
    final meta = _metaLine();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (meta != null) ...[
          const SizedBox(height: 4),
          Text(
            meta,
            style: TextStyle(
              color: ForjaShellColors.textSecondary,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

class PlayerPausedHero extends StatelessWidget {
  const PlayerPausedHero({
    super.key,
    required this.movie,
    this.season,
    this.episode,
    this.episodeOverview,
  });

  final Movie movie;
  final int? season;
  final int? episode;
  final String? episodeOverview;

  @override
  Widget build(BuildContext context) {
    final overview = (episodeOverview?.trim().isNotEmpty == true)
        ? episodeOverview!
        : movie.overview;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            HeroTitle(
              movie: movie,
              logoUrl: movie.logoPath.isNotEmpty
                  ? TmdbApi.getImageUrl(movie.logoPath)
                  : null,
              style: HeroTitleStyle.details,
            ),
            const SizedBox(height: 10),
            HeroMetaLine(movie: movie, style: HeroMetaStyle.details),
            if (season != null && episode != null) ...[
              const SizedBox(height: 6),
              Text(
                'S$season E$episode',
                style: TextStyle(
                  color: ForjaShellColors.cinematic.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
            if (overview.isNotEmpty) ...[
              const SizedBox(height: 10),
              HeroOverviewText(
                overview: overview,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.45,
                ),
                maxLines: 3,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class PlayerTimeRange extends StatelessWidget {
  const PlayerTimeRange({
    super.key,
    required this.position,
    required this.duration,
    this.fontSize = 12,
  });

  final Duration position;
  final Duration duration;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${_fmt(position)} / ${_fmt(duration)}',
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.9),
        fontSize: fontSize,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class PlayerCenterActionButton extends StatefulWidget {
  const PlayerCenterActionButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 64,
    this.iconSize = 32,
    this.showSpinner = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final double iconSize;
  final bool showSpinner;

  @override
  State<PlayerCenterActionButton> createState() =>
      _PlayerCenterActionButtonState();
}

class _PlayerCenterActionButtonState extends State<PlayerCenterActionButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTap: widget.onPressed,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.9 : (_hovered ? 1.06 : 1.0),
          duration: const Duration(milliseconds: 100),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: _hovered ? 0.22 : 0.14),
              border: Border.all(
                color: Colors.white.withValues(alpha: _hovered ? 0.35 : 0.2),
              ),
            ),
            child: widget.showSpinner
                ? Center(
                    child: SizedBox(
                      width: widget.iconSize,
                      height: widget.iconSize,
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    ),
                  )
                : Icon(
                    widget.icon,
                    color: Colors.white,
                    size: widget.iconSize,
                  ),
          ),
        ),
      ),
    );
  }
}

class PlayerOverlayGradient extends StatelessWidget {
  const PlayerOverlayGradient({super.key, required this.isTop});

  final bool isTop;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: isTop ? 120 : 160,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
            end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: isTop ? 0.72 : 0.85),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}
