import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/my_list/providers/external_lists_providers.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/services/hub_list_follow.dart';
import 'package:forja/shared/services/tracker/simkl_service.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/media_details_tv_scope.dart';
import 'package:forja/shared/widgets/hero/hero_pill_buttons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rust/rust.dart';

const _listStatuses =
    <({String id, String label, IconData icon, IconData selectedIcon, Color color})>[
      (
        id: 'plantowatch',
        label: 'Plan to Watch',
        icon: Icons.bookmark_add_outlined,
        selectedIcon: Icons.bookmark_rounded,
        color: Color(0xFFFBBF24), // amber
      ),
      (
        id: 'watching',
        label: 'Watching',
        icon: Icons.play_circle_outline_rounded,
        selectedIcon: Icons.play_circle_rounded,
        color: ForjaShellColors.brandGreen,
      ),
      (
        id: 'hold',
        label: 'On Hold',
        icon: Icons.pause_circle_outline_rounded,
        selectedIcon: Icons.pause_circle_rounded,
        color: Color(0xFFFB923C), // orange
      ),
      (
        id: 'completed',
        label: 'Completed',
        icon: Icons.check_circle_outline_rounded,
        selectedIcon: Icons.check_circle_rounded,
        color: Color(0xFF38BDF8), // sky
      ),
      (
        id: 'dropped',
        label: 'Dropped',
        icon: Icons.cancel_outlined,
        selectedIcon: Icons.cancel_rounded,
        color: Color(0xFFF87171), // rose
      ),
    ];

Color _statusPinColor(String? status) {
  if (status == null) return ForjaShellColors.iconMuted;
  for (final s in _listStatuses) {
    if (s.id == status) return s.color;
  }
  return ForjaShellColors.iconActive;
}

class MyListButton extends StatelessWidget {
  const MyListButton.movie({
    super.key,
    required Movie this.movie,
    this.useHeartIcon = false,
    this.iconColor,
    this.iconColorActive,
    this.iconSize,
    this.excludeFromTvTraversal = false,
  })  : stremioItem = null,
        hubTarget = null;

  const MyListButton.hub({
    super.key,
    required HubListFollowTarget this.hubTarget,
    this.iconSize,
    this.iconColor,
    this.iconColorActive,
    this.excludeFromTvTraversal = false,
  })  : movie = null,
        stremioItem = null,
        useHeartIcon = false;

  const MyListButton.stremio({
    super.key,
    required Map<String, dynamic> this.stremioItem,
    this.useHeartIcon = false,
    this.iconColor,
    this.iconColorActive,
    this.iconSize,
    this.excludeFromTvTraversal = false,
  })  : movie = null,
        hubTarget = null;

  final Movie? movie;
  final Map<String, dynamic>? stremioItem;
  final HubListFollowTarget? hubTarget;
  final bool useHeartIcon;
  final Color? iconColor;
  final Color? iconColorActive;
  final double? iconSize;

  /// Row cards: keep D-pad on the poster tile, not the overlay button.
  final bool excludeFromTvTraversal;

  @override
  Widget build(BuildContext context) {
    if (hubTarget != null) {
      return _StatusPin(
        uniqueId: hubTarget!.uniqueId,
        iconSize: iconSize,
        iconColor: iconColor,
        iconColorActive: iconColorActive,
        excludeFromTvTraversal: excludeFromTvTraversal,
        onSetStatus: (to) async {
          ProviderContainer? container;
          try {
            container = ProviderScope.containerOf(context, listen: false);
          } catch (_) {}
          return HubListFollow.setStatus(
            hubTarget!,
            to,
            container: container,
          );
        },
      );
    }
    if (movie != null && !useHeartIcon) {
      return _StatusPin(
        uniqueId: MyListService.movieId(movie!.id, movie!.mediaType),
        iconSize: iconSize,
        iconColor: iconColor,
        iconColorActive: iconColorActive,
        excludeFromTvTraversal: excludeFromTvTraversal,
        onSetStatus: (to) => _setMovieStatus(context, movie!, to),
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

  static Future<bool> _setMovieStatus(
    BuildContext context,
    Movie movie,
    String to,
  ) async {
    await MyListService().upsertMovie(
      tmdbId: movie.id,
      imdbId: movie.imdbId,
      title: movie.title,
      posterPath: movie.posterPath,
      mediaType: movie.mediaType,
      voteAverage: movie.voteAverage,
      releaseDate: movie.releaseDate,
      listStatus: to,
    );
    var ok = true;
    if (await SimklService().isLoggedIn()) {
      ok = await SimklService().setListStatus(
        tmdbId: movie.id,
        imdbId: movie.imdbId,
        mediaType: movie.mediaType,
        to: to,
      );
      if (context.mounted) {
        try {
          ProviderScope.containerOf(
            context,
            listen: false,
          ).invalidate(simklWatchlistProvider);
        } catch (_) {}
      }
    }
    return ok;
  }
}

class _StatusPin extends StatefulWidget {
  const _StatusPin({
    required this.uniqueId,
    required this.onSetStatus,
    this.iconSize,
    this.iconColor,
    this.iconColorActive,
    this.excludeFromTvTraversal = false,
  });

  final String uniqueId;
  final Future<bool> Function(String to) onSetStatus;
  final double? iconSize;
  final Color? iconColor;
  final Color? iconColorActive;
  final bool excludeFromTvTraversal;

  @override
  State<_StatusPin> createState() => _StatusPinState();
}

class _StatusPinState extends State<_StatusPin> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;
  bool _busy = false;

  bool get _open => _entry != null;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    final entry = _entry;
    if (entry == null) return;
    _entry = null;
    entry.remove();
  }

  void _close() {
    if (_entry == null) return;
    _removeOverlay();
    if (mounted) setState(() {});
  }

  IconData _pinIcon(String? status) {
    for (final s in _listStatuses) {
      if (s.id == status) return s.selectedIcon;
    }
    // Same bookmark as Home / Plan to Watch (muted via color when not listed).
    return Icons.bookmark_rounded;
  }

  Future<void> _setStatus(String to) async {
    if (_busy) return;
    setState(() => _busy = true);
    _entry?.markNeedsBuild();
    final ok = await widget.onSetStatus(to);
    if (!mounted) return;
    setState(() => _busy = false);
    _close();
    final label =
        _listStatuses.where((s) => s.id == to).firstOrNull?.label ?? to;
    if (ok) {
      ForjaToast.success(label, duration: const Duration(seconds: 1));
    } else {
      ForjaToast.error('Saved locally · Simkl failed');
    }
  }

  void _openMenu() {
    if (_entry != null || _busy) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    final policy = ShellScope.inputPolicyOf(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _close,
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
            CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              offset: const Offset(0, 28),
              child: Material(
                color: Colors.transparent,
                child: ValueListenableBuilder<int>(
                  valueListenable: MyListService.changeNotifier,
                  builder: (context, _, _) {
                    final inList = MyListService().contains(widget.uniqueId);
                    final status = inList
                        ? MyListService().statusOf(widget.uniqueId)
                        : null;
                    return IntrinsicWidth(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
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
                                  icon: s.id == status
                                      ? s.selectedIcon
                                      : s.icon,
                                  label: s.label,
                                  statusColor: s.color,
                                  onTap: _busy
                                      ? null
                                      : () => _setStatus(s.id),
                                  tvFocus: policy.useFocusableMoodChips,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
    _entry = entry;
    overlay.insert(entry);
    setState(() {});
  }

  void _toggle() {
    if (_open) {
      _close();
    } else {
      _openMenu();
    }
  }

  @override
  Widget build(BuildContext context) {
    final policy = ShellScope.inputPolicyOf(context);
    final exclude =
        widget.excludeFromTvTraversal && policy.useFocusableMoodChips;
    final size = widget.iconSize ?? 18.0;

    Widget body = CompositedTransformTarget(
      link: _link,
      child: ValueListenableBuilder<int>(
        valueListenable: MyListService.changeNotifier,
        builder: (context, _, _) {
          final inList = MyListService().contains(widget.uniqueId);
          final status = inList ? MyListService().statusOf(widget.uniqueId) : null;
          return _pinHit(
            policy: policy,
            onTap: _busy ? null : _toggle,
            child: Icon(
              _pinIcon(status),
              size: size,
              color: status != null
                  ? _statusPinColor(status)
                  : (widget.iconColor ?? ForjaShellColors.iconMuted),
            ),
          );
        },
      ),
    );

    if (exclude) body = ExcludeFocus(child: body);
    return body;
  }

  Widget _pinHit({
    required ShellInputPolicy policy,
    required VoidCallback? onTap,
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

/// Always shows icon + label. Hover = background; selected = status color.
class _StatusRow extends StatefulWidget {
  const _StatusRow({
    required this.selected,
    required this.icon,
    required this.label,
    required this.statusColor,
    required this.tvFocus,
    this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final Color statusColor;
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
        ? widget.statusColor
        : (widget.selected
            ? widget.statusColor
            : Colors.white);
    final row = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: _active
          ? widget.statusColor.withValues(alpha: 0.12)
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
              : Icons.bookmark_rounded,
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
        IconData icon = Icons.bookmark_rounded;
        if (status != null) {
          for (final s in _listStatuses) {
            if (s.id == status) {
              icon = s.selectedIcon;
              break;
            }
          }
        }
        return Icon(icon, size: 20, color: _statusPinColor(status));
      },
    );
  }
}

/// Glass hero **+** pill; status menu floats in an [Overlay] (no row reflow).
class ListStatusHeroControl extends StatefulWidget {
  const ListStatusHeroControl({
    super.key,
    required this.uniqueId,
    required this.onSetStatus,
    this.tvTabId,
    this.tvItemIndexStart = 0,
    this.onUpEdge,
    this.onMenuOpenChanged,
  });

  final String uniqueId;
  final Future<bool> Function(String status) onSetStatus;
  final String? tvTabId;
  final int tvItemIndexStart;
  final VoidCallback? onUpEdge;
  final ValueChanged<bool>? onMenuOpenChanged;

  /// Overlay menu is not in the hero focus row.
  static int extraFocusSlots(bool menuOpen) => 0;

  @override
  State<ListStatusHeroControl> createState() => _ListStatusHeroControlState();
}

class _ListStatusHeroControlState extends State<ListStatusHeroControl> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;
  bool _busy = false;

  bool get _open => _entry != null;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    final entry = _entry;
    if (entry == null) return;
    _entry = null;
    entry.remove();
  }

  void _close() {
    if (_entry == null) return;
    _removeOverlay();
    widget.onMenuOpenChanged?.call(false);
    if (mounted) setState(() {});
  }

  void _openMenu() {
    if (_entry != null || _busy) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    final policy = ShellScope.inputPolicyOf(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _close,
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
            CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              offset: const Offset(0, 46),
              child: Material(
                color: Colors.transparent,
                child: ValueListenableBuilder<int>(
                  valueListenable: MyListService.changeNotifier,
                  builder: (context, _, _) {
                    final inList = MyListService().contains(widget.uniqueId);
                    final status = inList
                        ? MyListService().statusOf(widget.uniqueId)
                        : null;
                    return IntrinsicWidth(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
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
                                  icon: s.id == status
                                      ? s.selectedIcon
                                      : s.icon,
                                  label: s.label,
                                  statusColor: s.color,
                                  onTap: _busy
                                      ? null
                                      : () => _setStatus(s.id),
                                  tvFocus: policy.useFocusableMoodChips,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
    _entry = entry;
    overlay.insert(entry);
    widget.onMenuOpenChanged?.call(true);
    setState(() {});
  }

  void _toggle() {
    if (_open) {
      _close();
    } else {
      _openMenu();
    }
  }

  Future<void> _setStatus(String to) async {
    if (_busy) return;
    setState(() => _busy = true);
    _entry?.markNeedsBuild();
    final ok = await widget.onSetStatus(to);
    if (!mounted) return;
    setState(() => _busy = false);
    _close();
    final label =
        _listStatuses.where((s) => s.id == to).firstOrNull?.label ?? to;
    if (ok) {
      ForjaToast.success(label, duration: const Duration(seconds: 1));
    } else {
      ForjaToast.error('Saved locally · Simkl failed');
    }
  }

  IconData _icon(String? status) {
    for (final s in _listStatuses) {
      if (s.id == status) return s.selectedIcon;
    }
    return Icons.bookmark_rounded;
  }

  String _label(String? status) {
    for (final s in _listStatuses) {
      if (s.id == status) return s.label;
    }
    return 'My List';
  }

  @override
  Widget build(BuildContext context) {
    final tv = widget.tvTabId;
    return CompositedTransformTarget(
      link: _link,
      child: ValueListenableBuilder<int>(
        valueListenable: MyListService.changeNotifier,
        builder: (context, _, _) {
          final inList = MyListService().contains(widget.uniqueId);
          final status =
              inList ? MyListService().statusOf(widget.uniqueId) : null;
          return HeroPillIconGroup(
            tvTabId: tv,
            tvRowId: tv != null ? MediaDetailsTv.heroRowId : null,
            tvItemIndexStart: widget.tvItemIndexStart,
            onUpEdge: widget.onUpEdge,
            slots: [
              HeroPillIconSlot(
                label: _label(status),
                iconWidget: Icon(
                  _icon(status),
                  size: 20,
                  color: _statusPinColor(status),
                ),
                onTap: _busy ? null : _toggle,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Movie details hero — glass **+** + floating status menu.
class MyListHeroStatusPill extends StatelessWidget {
  const MyListHeroStatusPill({
    super.key,
    required this.movie,
    this.tvTabId,
    this.tvItemIndexStart = 0,
    this.onUpEdge,
    this.onMenuOpenChanged,
  });

  final Movie movie;
  final String? tvTabId;
  final int tvItemIndexStart;
  final VoidCallback? onUpEdge;
  final ValueChanged<bool>? onMenuOpenChanged;

  Future<bool> _setStatus(BuildContext context, String to) async {
    await MyListService().upsertMovie(
      tmdbId: movie.id,
      imdbId: movie.imdbId,
      title: movie.title,
      posterPath: movie.posterPath,
      mediaType: movie.mediaType,
      voteAverage: movie.voteAverage,
      releaseDate: movie.releaseDate,
      listStatus: to,
    );
    var ok = true;
    if (await SimklService().isLoggedIn()) {
      ok = await SimklService().setListStatus(
        tmdbId: movie.id,
        imdbId: movie.imdbId,
        mediaType: movie.mediaType,
        to: to,
      );
      if (context.mounted) {
        try {
          ProviderScope.containerOf(
            context,
            listen: false,
          ).invalidate(simklWatchlistProvider);
        } catch (_) {}
      }
    }
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    return ListStatusHeroControl(
      uniqueId: MyListService.movieId(movie.id, movie.mediaType),
      onSetStatus: (to) => _setStatus(context, to),
      tvTabId: tvTabId,
      tvItemIndexStart: tvItemIndexStart,
      onUpEdge: onUpEdge,
      onMenuOpenChanged: onMenuOpenChanged,
    );
  }
}

/// Hero-row My List slice inside [HeroPillIconGroup] (toggle only — Stremio).
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
