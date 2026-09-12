import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/player/details/kit_list_status_pin.dart';
import 'package:forja/shared/shell/hero_pill_buttons.dart';

import 'package:forja/shared/engine/lists/external_list_providers.dart';
import 'package:forja/shared/engine/lists/list_follow.dart';
import 'package:forja/shared/engine/lists/list_providers.dart';
import 'package:forja/shared/shell/tv/media_details_tv_scope.dart';
import 'package:forja/shared/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/shell/tv/tv_focus_graph.dart';
import 'package:forja/shared/services/tracker/simkl_service.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:rust/rust.dart';
import 'package:forja/shared/shell/forja_toast.dart';
import 'package:forja/shared/shell/forja_shell_scope.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

void _toastStatusWrite(bool ok, String to) {
  if (to.isEmpty) {
    if (ok) {
      ForjaToast.success(
        'Removed from My List',
        duration: const Duration(seconds: 1),
      );
    } else {
      ForjaToast.error('Removed locally · Simkl failed');
    }
    return;
  }
  final label = kitListStatusLabel(to, fallback: to);
  if (ok) {
    ForjaToast.success(label, duration: const Duration(seconds: 1));
  } else {
    ForjaToast.error('Saved locally · Simkl failed');
  }
}

/// Wired bookmark status pin — Riverpod / Simkl / [ListFollow].
///
/// Presentational chrome: [KitListStatusPin].
class KitListStatusButton extends StatelessWidget {
  const KitListStatusButton.movie({
    super.key,
    required Movie this.movie,
    this.useHeartIcon = false,
    this.iconColor,
    this.iconColorActive,
    this.iconSize,
    this.excludeFromTvTraversal = false,
    this.knownStatus,
  }) : stremioItem = null,
       followTarget = null;

  const KitListStatusButton.follow({
    super.key,
    required ListFollowTarget this.followTarget,
    this.iconSize,
    this.iconColor,
    this.iconColorActive,
    this.excludeFromTvTraversal = false,
    this.knownStatus,
  }) : movie = null,
       stremioItem = null,
       useHeartIcon = false;

  const KitListStatusButton.stremio({
    super.key,
    required Map<String, dynamic> this.stremioItem,
    this.useHeartIcon = false,
    this.iconColor,
    this.iconColorActive,
    this.iconSize,
    this.excludeFromTvTraversal = false,
  }) : movie = null,
       followTarget = null,
       knownStatus = null;

  final Movie? movie;
  final Map<String, dynamic>? stremioItem;
  final ListFollowTarget? followTarget;
  final bool useHeartIcon;
  final Color? iconColor;
  final Color? iconColorActive;
  final double? iconSize;

  /// Row cards: keep D-pad on the poster tile, not the overlay button.
  final bool excludeFromTvTraversal;

  /// When local bookmarks have no row yet (e.g. Simkl-only Watching tab), use this
  /// status for the pin icon/color until a write lands.
  final String? knownStatus;

  @override
  Widget build(BuildContext context) {
    if (followTarget != null) {
      return _WiredStatusPin(
        uniqueId: followTarget!.uniqueId,
        iconSize: iconSize,
        iconColor: iconColor,
        excludeFromTvTraversal: excludeFromTvTraversal,
        knownStatus: knownStatus,
        onSetStatus: (to) async {
          ProviderContainer? container;
          try {
            container = ProviderScope.containerOf(context, listen: false);
          } catch (_) {}
          return ListFollow.setStatus(followTarget!, to, container: container);
        },
      );
    }
    if (movie != null && !useHeartIcon) {
      return _WiredStatusPin(
        uniqueId: BookmarkStore.movieId(movie!.id, movie!.mediaType),
        iconSize: iconSize,
        iconColor: iconColor,
        excludeFromTvTraversal: excludeFromTvTraversal,
        knownStatus: knownStatus,
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
    ProviderContainer? container;
    try {
      container = ProviderScope.containerOf(context, listen: false);
    } catch (_) {}
    if (to.isEmpty) {
      final uid = BookmarkStore.movieId(movie.id, movie.mediaType);
      container?.read(bookmarkHiddenKeysProvider.notifier).addAll({uid});
      await BookmarkStore().remove(uid);
      var ok = true;
      if (await SimklService().isLoggedIn()) {
        ok = await SimklService().removeFromWatchlist(
          tmdbId: movie.id,
          imdbId: movie.imdbId,
          mediaType: movie.mediaType,
        );
      }
      container?.invalidate(simklWatchlistProvider);
      return ok;
    }
    await BookmarkStore().upsertMovie(
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
      container?.invalidate(simklWatchlistProvider);
    }
    return ok;
  }
}

/// Listens to [BookmarkStore] and fills [KitListStatusPin] props.
class _WiredStatusPin extends StatelessWidget {
  const _WiredStatusPin({
    required this.uniqueId,
    required this.onSetStatus,
    this.iconSize,
    this.iconColor,
    this.excludeFromTvTraversal = false,
    this.knownStatus,
  });

  final String uniqueId;
  final Future<bool> Function(String to) onSetStatus;
  final double? iconSize;
  final Color? iconColor;
  final bool excludeFromTvTraversal;
  final String? knownStatus;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: BookmarkStore.changeNotifier,
      builder: (context, _, _) {
        final inList = BookmarkStore().contains(uniqueId);
        final status = inList
            ? BookmarkStore().statusOf(uniqueId)
            : knownStatus;
        return KitListStatusPin(
          currentStatus: status,
          iconSize: iconSize,
          iconColor: iconColor,
          excludeFromTvTraversal: excludeFromTvTraversal,
          onSelect: (to) async {
            final ok = await onSetStatus(to);
            _toastStatusWrite(ok, to);
          },
        );
      },
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
      return BookmarkStore.movieId(movie!.id, movie!.mediaType);
    }
    return BookmarkStore.stremioItemId(stremioItem!);
  }

  Future<void> _toggle(BuildContext context) async {
    if (movie != null) {
      final added = await BookmarkStore().toggleMovie(
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
      final added = await BookmarkStore().toggleStremioItem(stremioItem!);
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
    // Same leanback-only hide as [KitListStatusPin] — keep pins on desktop hover.
    if (excludeFromTvTraversal &&
        policy.useFocusableMoodChips &&
        !policy.scaleOnHover) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<int>(
      valueListenable: BookmarkStore.changeNotifier,
      builder: (context, _, _) {
        final inList = BookmarkStore().contains(_uniqueId);
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

        // Card overlays: compact hit target so pin tops align with score badge.
        if (!policy.useFocusableMoodChips || excludeFromTvTraversal) {
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
  }
}

/// Dynamic icon for the grouped hero bookmark slice.
class BookmarkHeroIcon extends StatelessWidget {
  const BookmarkHeroIcon.movie({super.key, required this.movie})
    : stremioItem = null;

  const BookmarkHeroIcon.stremio({
    super.key,
    required Map<String, dynamic> this.stremioItem,
  }) : movie = null;

  final Movie? movie;
  final Map<String, dynamic>? stremioItem;

  String get _uniqueId {
    if (movie != null) {
      return BookmarkStore.movieId(movie!.id, movie!.mediaType);
    }
    return BookmarkStore.stremioItemId(stremioItem!);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: BookmarkStore.changeNotifier,
      builder: (context, _, _) {
        final inList = BookmarkStore().contains(_uniqueId);
        final status = inList ? BookmarkStore().statusOf(_uniqueId) : null;
        return Icon(
          kitListStatusPinIcon(status),
          size: 20,
          color: kitListStatusPinColor(status),
        );
      },
    );
  }
}

/// Glass hero **+** pill; status menu floats in an [Overlay] (no row reflow).
class KitListStatusControl extends StatefulWidget {
  const KitListStatusControl({
    super.key,
    required this.uniqueId,
    required this.onSetStatus,
    this.tvTabId,
    this.tvItemIndexStart = 0,
    this.onUpEdge,
    this.onRightEdge,
    this.onMenuOpenChanged,
    this.enabled = true,
  });

  final String uniqueId;
  final Future<bool> Function(String status) onSetStatus;
  final String? tvTabId;
  final int tvItemIndexStart;
  final VoidCallback? onUpEdge;
  final VoidCallback? onRightEdge;
  final ValueChanged<bool>? onMenuOpenChanged;
  /// Inactive hero carousel slides: visual only (no FocusNode / onTap).
  final bool enabled;

  /// Overlay menu is not in the hero focus row.
  static int extraFocusSlots(bool menuOpen) => 0;

  @override
  State<KitListStatusControl> createState() => _KitListStatusControlState();
}

class _KitListStatusControlState extends State<KitListStatusControl> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;
  FocusNode? _returnFocus;
  bool _restoreFocusOnClose = false;
  bool _busy = false;

  bool get _open => _entry != null;

  @override
  void dispose() {
    _clearTvDismiss();
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    final entry = _entry;
    if (entry == null) return;
    _entry = null;
    entry.remove();
  }

  void _registerTvDismiss() {
    ShellTvFocusCoordinator.setTransientOverlayDismiss(() {
      if (_entry == null) return false;
      _close();
      return true;
    });
  }

  void _clearTvDismiss() {
    ShellTvFocusCoordinator.setTransientOverlayDismiss(null);
  }

  void _close() {
    if (_entry == null) return;
    _clearTvDismiss();
    _removeOverlay();
    widget.onMenuOpenChanged?.call(false);
    final back = _restoreFocusOnClose ? _returnFocus : null;
    _returnFocus = null;
    _restoreFocusOnClose = false;
    if (mounted) setState(() {});
    if (back == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (back.canRequestFocus) back.requestFocus();
    });
  }

  void _openMenu() {
    if (_entry != null || _busy) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    final policy = ShellScope.inputPolicyOf(context);
    _returnFocus = FocusManager.instance.primaryFocus;
    // Leanback: restore pin focus when the menu closes. Desktop: don't —
    // the click gesture re-focuses the pin after sync unfocus; we clear it
    // post-frame and keep suppressActive while open.
    _restoreFocusOnClose = !policy.scaleOnHover;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) {
        return ShellScope.rehost(
          context,
          TvOverlayScope(
            enabled: policy.useFocusableMoodChips,
            linear: true,
            onDismiss: _close,
            debugLabel: 'list-status-menu',
            child: Stack(
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
                      valueListenable: BookmarkStore.changeNotifier,
                      builder: (context, _, _) {
                        final inList = BookmarkStore().contains(
                          widget.uniqueId,
                        );
                        final status = inList
                            ? BookmarkStore().statusOf(widget.uniqueId)
                            : null;
                        return KitListStatusPopupPanel(
                          currentStatus: status,
                          busy: _busy,
                          // Desktop hybrid has mood chips too — menu is mouse
                          // hover only. D-pad autofocus is leanback-only.
                          tvFocus: policy.leanbackOnly,
                          autoFocusSelected: policy.leanbackOnly,
                          onSelect: _setStatus,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    _entry = entry;
    overlay.insert(entry);
    if (policy.useFocusableMoodChips) _registerTvDismiss();
    widget.onMenuOpenChanged?.call(true);
    setState(() {});
    // Beat GestureDetector / Focus re-claim after the opening tap.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_open) return;
      final focus = FocusManager.instance.primaryFocus;
      if (focus == null) return;
      // Don't steal focus from the menu panel on TV.
      if (!policy.scaleOnHover) return;
      focus.unfocus();
    });
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
    _toastStatusWrite(ok, to);
  }

  @override
  Widget build(BuildContext context) {
    final tv = widget.tvTabId;
    // Always idle while the menu is open — including desktop hybrid where
    // the opening tap re-focuses the pin after GestureDetector settles.
    final suppressActive = _open;
    return CompositedTransformTarget(
      link: _link,
      child: ValueListenableBuilder<int>(
        valueListenable: BookmarkStore.changeNotifier,
        builder: (context, _, _) {
          final inList = BookmarkStore().contains(widget.uniqueId);
          final status = inList
              ? BookmarkStore().statusOf(widget.uniqueId)
              : null;
          return HeroPillIconGroup(
            tvTabId: tv,
            tvRowId: tv != null ? MediaDetailsTv.heroRowId : null,
            tvItemIndexStart: widget.tvItemIndexStart,
            onUpEdge: widget.onUpEdge,
            onRightEdge: widget.onRightEdge,
            slots: [
              HeroPillIconSlot(
                label: kitListStatusLabel(status),
                iconWidget: Icon(
                  kitListStatusPinIcon(status),
                  size: 20,
                  color: kitListStatusPinColor(status),
                ),
                onTap: (!widget.enabled || _busy) ? null : _toggle,
                suppressActive: suppressActive,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Movie details hero — glass **+** + floating status menu.
class BookmarkHeroStatusPill extends StatelessWidget {
  const BookmarkHeroStatusPill({
    super.key,
    required this.movie,
    this.tvTabId,
    this.tvItemIndexStart = 0,
    this.onUpEdge,
    this.onRightEdge,
    this.onMenuOpenChanged,
    this.enabled = true,
  });

  final Movie movie;
  final String? tvTabId;
  final int tvItemIndexStart;
  final VoidCallback? onUpEdge;
  final VoidCallback? onRightEdge;
  final ValueChanged<bool>? onMenuOpenChanged;
  final bool enabled;

  Future<bool> _setStatus(BuildContext context, String to) async {
    ProviderContainer? container;
    try {
      container = ProviderScope.containerOf(context, listen: false);
    } catch (_) {}
    if (to.isEmpty) {
      final uid = BookmarkStore.movieId(movie.id, movie.mediaType);
      container?.read(bookmarkHiddenKeysProvider.notifier).addAll({uid});
      await BookmarkStore().remove(uid);
      var ok = true;
      if (await SimklService().isLoggedIn()) {
        ok = await SimklService().removeFromWatchlist(
          tmdbId: movie.id,
          imdbId: movie.imdbId,
          mediaType: movie.mediaType,
        );
      }
      container?.invalidate(simklWatchlistProvider);
      return ok;
    }
    await BookmarkStore().upsertMovie(
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
      container?.invalidate(simklWatchlistProvider);
    }
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    return KitListStatusControl(
      uniqueId: BookmarkStore.movieId(movie.id, movie.mediaType),
      onSetStatus: (to) => _setStatus(context, to),
      tvTabId: tvTabId,
      tvItemIndexStart: tvItemIndexStart,
      onUpEdge: onUpEdge,
      onRightEdge: onRightEdge,
      onMenuOpenChanged: onMenuOpenChanged,
      enabled: enabled,
    );
  }
}

/// Hero-row bookmark slice inside [HeroPillIconGroup] (toggle only — Stremio).
class BookmarkHeroPillButton {
  BookmarkHeroPillButton._();

  static Future<void> toggle(
    BuildContext context, {
    Movie? movie,
    Map<String, dynamic>? stremioItem,
  }) async {
    if (movie != null) {
      final added = await BookmarkStore().toggleMovie(
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
      final added = await BookmarkStore().toggleStremioItem(stremioItem);
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
      iconWidget: BookmarkHeroIcon.movie(movie: movie),
      onTap: () => toggle(context, movie: movie),
    );
  }

  static HeroPillIconSlot stremioSlot(
    BuildContext context, {
    required Map<String, dynamic> stremioItem,
  }) {
    return HeroPillIconSlot(
      label: 'My List',
      iconWidget: BookmarkHeroIcon.stremio(stremioItem: stremioItem),
      onTap: () => toggle(context, stremioItem: stremioItem),
    );
  }
}
