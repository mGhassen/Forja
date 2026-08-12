import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/my_list/providers/external_lists_providers.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/services/tracker/simkl_service.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/hero/hero_pill_buttons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rust/rust.dart';

const _listStatuses =
    <({String id, String label, IconData icon, IconData selectedIcon})>[
      (
        id: 'plantowatch',
        label: 'Plan to Watch',
        icon: Icons.bookmark_add_outlined,
        selectedIcon: Icons.bookmark_rounded,
      ),
      (
        id: 'watching',
        label: 'Watching',
        icon: Icons.play_circle_outline_rounded,
        selectedIcon: Icons.play_circle_rounded,
      ),
      (
        id: 'hold',
        label: 'On Hold',
        icon: Icons.pause_circle_outline_rounded,
        selectedIcon: Icons.pause_circle_rounded,
      ),
      (
        id: 'completed',
        label: 'Completed',
        icon: Icons.check_circle_outline_rounded,
        selectedIcon: Icons.check_circle_rounded,
      ),
      (
        id: 'dropped',
        label: 'Dropped',
        icon: Icons.cancel_outlined,
        selectedIcon: Icons.cancel_rounded,
      ),
    ];

class MyListButton extends StatelessWidget {
  const MyListButton.movie({
    super.key,
    required Movie this.movie,
    this.useHeartIcon = false,
    this.iconColor,
    this.iconColorActive,
    this.iconSize,
    this.excludeFromTvTraversal = false,
  }) : stremioItem = null;

  const MyListButton.stremio({
    super.key,
    required Map<String, dynamic> this.stremioItem,
    this.useHeartIcon = false,
    this.iconColor,
    this.iconColorActive,
    this.iconSize,
    this.excludeFromTvTraversal = false,
  }) : movie = null;

  final Movie? movie;
  final Map<String, dynamic>? stremioItem;
  final bool useHeartIcon;
  final Color? iconColor;
  final Color? iconColorActive;
  final double? iconSize;

  /// Row cards: keep D-pad on the poster tile, not the overlay button.
  final bool excludeFromTvTraversal;

  @override
  Widget build(BuildContext context) {
    if (movie != null && !useHeartIcon) {
      return _MovieStatusPin(
        movie: movie!,
        iconSize: iconSize,
        excludeFromTvTraversal: excludeFromTvTraversal,
      );
    }
    return _LegacyTogglePin(
      movie: movie,
      stremioItem: stremioItem,
      useHeartIcon: useHeartIcon,
      iconColor: iconColor,
      iconColorActive: iconColorActive,
      iconSize: iconSize,
      excludeFromTvTraversal: excludeFromTvTraversal,
    );
  }
}

class _MovieStatusPin extends StatefulWidget {
  const _MovieStatusPin({
    required this.movie,
    this.iconSize,
    this.excludeFromTvTraversal = false,
  });

  final Movie movie;
  final double? iconSize;
  final bool excludeFromTvTraversal;

  @override
  State<_MovieStatusPin> createState() => _MovieStatusPinState();
}

class _MovieStatusPinState extends State<_MovieStatusPin> {
  bool _open = false;
  bool _busy = false;

  String get _uid =>
      MyListService.movieId(widget.movie.id, widget.movie.mediaType);

  IconData _pinIcon(String? status) {
    for (final s in _listStatuses) {
      if (s.id == status) return s.selectedIcon;
    }
    return Icons.add_rounded;
  }

  Future<void> _setStatus(String to) async {
    if (_busy) return;
    setState(() => _busy = true);
    await MyListService().upsertMovie(
      tmdbId: widget.movie.id,
      imdbId: widget.movie.imdbId,
      title: widget.movie.title,
      posterPath: widget.movie.posterPath,
      mediaType: widget.movie.mediaType,
      voteAverage: widget.movie.voteAverage,
      releaseDate: widget.movie.releaseDate,
      listStatus: to,
    );
    var ok = true;
    if (await SimklService().isLoggedIn()) {
      ok = await SimklService().setListStatus(
        tmdbId: widget.movie.id,
        imdbId: widget.movie.imdbId,
        mediaType: widget.movie.mediaType,
        to: to,
      );
      if (mounted) {
        try {
          ProviderScope.containerOf(
            context,
            listen: false,
          ).invalidate(simklWatchlistProvider);
        } catch (_) {}
      }
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _open = false;
    });
    final label =
        _listStatuses.where((s) => s.id == to).firstOrNull?.label ?? to;
    if (ok) {
      ForjaToast.success(label, duration: const Duration(seconds: 1));
    } else {
      ForjaToast.error('Saved locally · Simkl failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.inputPolicyOf(context);
    final exclude =
        widget.excludeFromTvTraversal && policy.useFocusableMoodChips;
    final size = widget.iconSize ?? 18.0;

    Widget body = ValueListenableBuilder<int>(
      valueListenable: MyListService.changeNotifier,
      builder: (context, _, _) {
        final inList = MyListService().contains(_uid);
        final status = inList ? MyListService().statusOf(_uid) : null;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _pinHit(
              policy: policy,
              onTap: () => setState(() => _open = !_open),
              child: Icon(
                _pinIcon(status),
                size: size,
                color: status != null
                    ? ForjaShellColors.iconActive
                    : ForjaShellColors.iconMuted,
              ),
            ),
            if (_open) ...[
              SizedBox(height: shellScaled(context, 6).clamp(4.0, 6.0)),
              IntrinsicWidth(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final s in _listStatuses)
                          _StatusRow(
                            selected: s.id == status,
                            icon: s.id == status ? s.selectedIcon : s.icon,
                            label: s.label,
                            onTap: _busy ? null : () => _setStatus(s.id),
                            tvFocus: policy.useFocusableMoodChips,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );

    if (exclude) body = ExcludeFocus(child: body);
    return body;
  }

  Widget _pinHit({
    required ShellInputPolicy policy,
    required VoidCallback onTap,
    required Widget child,
  }) {
    if (!policy.useFocusableMoodChips) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: child,
      );
    }
    return FocusableControl(
      onTap: onTap,
      borderRadius: 20,
      scaleOnFocus: ShellTokens.focusActiveScale,
      child: SizedBox(width: 40, height: 40, child: Center(child: child)),
    );
  }
}

/// Always shows icon + label. Hover = background + green.
class _StatusRow extends StatefulWidget {
  const _StatusRow({
    required this.selected,
    required this.icon,
    required this.label,
    required this.tvFocus,
    this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final bool tvFocus;
  final VoidCallback? onTap;

  @override
  State<_StatusRow> createState() => _StatusRowState();
}

class _StatusRowState extends State<_StatusRow> {
  bool _hovered = false;
  bool _focused = false;

  bool get _active => _hovered || _focused;

  @override
  Widget build(BuildContext context) {
    final accent = _active
        ? ForjaShellColors.brandGreen
        : (widget.selected
            ? ForjaShellColors.brandGreen.withValues(alpha: 0.75)
            : Colors.white);
    final row = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: _active
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.transparent,
      child: Row(
        children: [
          Icon(widget.icon, size: 16, color: accent),
          const SizedBox(width: 8),
          Text(
            widget.label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: widget.selected || _active
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: accent,
            ),
          ),
        ],
      ),
    );

    if (!widget.tvFocus) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: row,
        ),
      );
    }

    return FocusableControl(
      onTap: widget.onTap,
      borderRadius: 0,
      scaleOnFocus: 1.0,
      onFocusChange: (f) => setState(() => _focused = f),
      onHoverChange: (h) => setState(() => _hovered = h),
      child: row,
    );
  }
}

class _LegacyTogglePin extends StatelessWidget {
  const _LegacyTogglePin({
    this.movie,
    this.stremioItem,
    this.useHeartIcon = false,
    this.iconColor,
    this.iconColorActive,
    this.iconSize,
    this.excludeFromTvTraversal = false,
  });

  final Movie? movie;
  final Map<String, dynamic>? stremioItem;
  final bool useHeartIcon;
  final Color? iconColor;
  final Color? iconColorActive;
  final double? iconSize;
  final bool excludeFromTvTraversal;

  String get _uniqueId {
    if (movie != null) {
      return MyListService.movieId(movie!.id, movie!.mediaType);
    }
    return MyListService.stremioItemId(stremioItem!);
  }

  Future<void> _toggle(BuildContext context) async {
    if (movie != null) {
      final added = await MyListService().toggleMovie(
        tmdbId: movie!.id,
        imdbId: movie!.imdbId,
        title: movie!.title,
        posterPath: movie!.posterPath,
        mediaType: movie!.mediaType,
        voteAverage: movie!.voteAverage,
        releaseDate: movie!.releaseDate,
      );
      if (context.mounted) {
        ForjaToast.success(
          added ? 'Added to My List' : 'Removed from My List',
          duration: const Duration(seconds: 1),
        );
      }
    } else if (stremioItem != null) {
      final added = await MyListService().toggleStremioItem(stremioItem!);
      if (context.mounted) {
        ForjaToast.success(
          added ? 'Added to My List' : 'Removed from My List',
          duration: const Duration(seconds: 1),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.inputPolicyOf(context);
    final exclude = excludeFromTvTraversal && policy.useFocusableMoodChips;

    Widget body = ValueListenableBuilder<int>(
      valueListenable: MyListService.changeNotifier,
      builder: (context, _, _) {
        final inList = MyListService().contains(_uniqueId);
        final icon = Icon(
          useHeartIcon
              ? (inList
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded)
              : (inList ? Icons.bookmark_rounded : Icons.add_rounded),
          size: iconSize ?? (useHeartIcon ? 24 : 20),
          color: inList
              ? (iconColorActive ??
                    (useHeartIcon ? Colors.white : ForjaShellColors.iconActive))
              : (iconColor ??
                    (useHeartIcon
                        ? Colors.white70
                        : ForjaShellColors.iconMuted)),
        );

        if (!policy.useFocusableMoodChips) {
          return GestureDetector(onTap: () => _toggle(context), child: icon);
        }

        return FocusableControl(
          onTap: () => _toggle(context),
          borderRadius: 20,
          scaleOnFocus: ShellTokens.focusActiveScale,
          child: SizedBox(width: 40, height: 40, child: Center(child: icon)),
        );
      },
    );

    if (exclude) {
      body = ExcludeFocus(child: body);
    }
    return body;
  }
}

/// Dynamic icon for the grouped hero My List slice.
class MyListHeroIcon extends StatelessWidget {
  const MyListHeroIcon.movie({super.key, required this.movie})
    : stremioItem = null;

  const MyListHeroIcon.stremio({
    super.key,
    required Map<String, dynamic> this.stremioItem,
  }) : movie = null;

  final Movie? movie;
  final Map<String, dynamic>? stremioItem;

  String get _uniqueId {
    if (movie != null) {
      return MyListService.movieId(movie!.id, movie!.mediaType);
    }
    return MyListService.stremioItemId(stremioItem!);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: MyListService.changeNotifier,
      builder: (context, _, _) {
        final inList = MyListService().contains(_uniqueId);
        final status = inList ? MyListService().statusOf(_uniqueId) : null;
        IconData icon = Icons.add_rounded;
        if (status != null) {
          for (final s in _listStatuses) {
            if (s.id == status) {
              icon = s.selectedIcon;
              break;
            }
          }
        }
        return Icon(icon, size: 20, color: Colors.white);
      },
    );
  }
}

/// Hero-row My List slice inside [HeroPillIconGroup].
class MyListHeroPillButton {
  MyListHeroPillButton._();

  static Future<void> toggle(
    BuildContext context, {
    Movie? movie,
    Map<String, dynamic>? stremioItem,
  }) async {
    if (movie != null) {
      final added = await MyListService().toggleMovie(
        tmdbId: movie.id,
        imdbId: movie.imdbId,
        title: movie.title,
        posterPath: movie.posterPath,
        mediaType: movie.mediaType,
        voteAverage: movie.voteAverage,
        releaseDate: movie.releaseDate,
      );
      if (context.mounted) {
        ForjaToast.success(
          added ? 'Added to My List' : 'Removed from My List',
          duration: const Duration(seconds: 1),
        );
      }
    } else if (stremioItem != null) {
      final added = await MyListService().toggleStremioItem(stremioItem);
      if (context.mounted) {
        ForjaToast.success(
          added ? 'Added to My List' : 'Removed from My List',
          duration: const Duration(seconds: 1),
        );
      }
    }
  }

  static HeroPillIconSlot movieSlot(
    BuildContext context, {
    required Movie movie,
  }) {
    return HeroPillIconSlot(
      label: 'My List',
      iconWidget: MyListHeroIcon.movie(movie: movie),
      onTap: () => toggle(context, movie: movie),
    );
  }

  static HeroPillIconSlot stremioSlot(
    BuildContext context, {
    required Map<String, dynamic> stremioItem,
  }) {
    return HeroPillIconSlot(
      label: 'My List',
      iconWidget: MyListHeroIcon.stremio(stremioItem: stremioItem),
      onTap: () => toggle(context, stremioItem: stremioItem),
    );
  }
}
