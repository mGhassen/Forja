import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/engine/runtime/open/catalog_open.dart';
import 'package:forja/shared/engine/runtime/open/meta_surface_open.dart';
import 'package:forja/shared/engine/store/list_follow.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/feedback/forja_toast.dart';
import 'package:forja/shell/tv/tv_card_quick_menu.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja_foundation/widgets/catalog/card_quick_menu.dart';
import 'package:rust/rust.dart';

/// Quick actions for a pack catalog card, derived only from the card's own
/// meta (`open` route, id, list membership). No pack ids, no product
/// branches — a card that cannot be opened gets no menu; a card whose
/// `open.surface` has a host handler (stream / live / offline routes) gets a
/// single **Open** row because that handler is the only outcome; a title
/// that is not playable (collection) gets no Play.
abstract final class KitCardQuickActions {
  KitCardQuickActions._();

  static const String openId = 'open';
  static const String playId = 'play';
  static const String detailsId = 'details';
  static const String listId = 'list';

  static const String openLabel = 'Open';
  static const String playLabel = 'Play';
  static const String detailsLabel = 'Details';
  static const String addToListLabel = 'Add to My List';
  static const String removeFromListLabel = 'Remove from My List';

  /// `MetaItem.type` is a free pack string; this is best-effort for the one
  /// generic shape that opens a details page but never plays itself.
  static const Set<String> _nonPlayableTypes = {'collection', 'collections'};

  static bool canOpen(MetaItem item) => item.id.isNotEmpty || item.open != null;

  /// `open.surface` resolved by a registered host handler: `openMetaItem`
  /// runs that handler and returns — `autoPlay` is never read, so Play and
  /// Details would be the same action with two labels.
  static bool opensViaSurfaceHandler(MetaItem item) {
    final surface = item.open?.surface.trim() ?? '';
    return surface.isNotEmpty && MetaSurfaceOpen.resolve(surface) != null;
  }

  static bool isPlayable(MetaItem item) =>
      canOpen(item) &&
      !opensViaSurfaceHandler(item) &&
      !_nonPlayableTypes.contains(item.type.trim().toLowerCase());

  /// In My List right now (bookmark store, then pack-emitted status).
  static bool inList(ListFollowTarget target, {String? knownStatus}) {
    final stored = BookmarkStore().resolvedStatus(
      uniqueId: target.uniqueId,
      tmdbId: target.tmdbId,
      mediaType: target.tmdbMediaType ?? target.resolvedMediaType,
    );
    if (stored != null) return stored.isNotEmpty;
    return (knownStatus ?? '').trim().isNotEmpty;
  }

  /// Actions for [item] in display order. Empty when the card cannot open.
  static List<CardQuickMenuAction> build(
    BuildContext context, {
    required String pluginId,
    required MetaItem item,
    String? knownStatus,
  }) {
    if (!canOpen(item)) return const [];
    final actions = <CardQuickMenuAction>[];
    if (opensViaSurfaceHandler(item)) {
      actions.add(
        CardQuickMenuAction(
          id: openId,
          label: openLabel,
          icon: Icons.open_in_new_rounded,
          onTap: () => openMetaItem(context, pluginId: pluginId, item: item),
        ),
      );
    } else if (isPlayable(item)) {
      actions.add(
        CardQuickMenuAction(
          id: playId,
          label: playLabel,
          icon: Icons.play_arrow_rounded,
          onTap: () => openMetaItem(
            context,
            pluginId: pluginId,
            item: item,
            autoPlay: true,
          ),
        ),
      );
    }
    if (!opensViaSurfaceHandler(item)) {
      actions.add(
        CardQuickMenuAction(
          id: detailsId,
          label: detailsLabel,
          icon: Icons.info_outline_rounded,
          onTap: () => openMetaItem(context, pluginId: pluginId, item: item),
        ),
      );
    }
    final target = ListFollowTarget.fromMeta(pluginId: pluginId, meta: item);
    if (target != null) {
      final listed = inList(target, knownStatus: knownStatus);
      actions.add(
        CardQuickMenuAction(
          id: listId,
          label: listed ? removeFromListLabel : addToListLabel,
          icon: listed
              ? Icons.bookmark_remove_rounded
              : Icons.bookmark_add_outlined,
          onTap: () => _toggleList(context, target, remove: listed),
        ),
      );
    }
    return actions;
  }

  /// Hold / MENU opener for a card, or null when the menu would be empty or
  /// this input profile has no hold gesture (desktop keeps pointer-down tap).
  static VoidCallback? openerFor(
    BuildContext context, {
    required String pluginId,
    required MetaItem? item,
    String? knownStatus,
  }) {
    if (item == null || !canOpen(item)) return null;
    final policy = ShellScope.maybeOf(context)?.inputPolicy;
    if (policy == null || !policy.leanbackOnly) return null;
    return () {
      // Resolve at open time so list membership is current.
      final actions = build(
        context,
        pluginId: pluginId,
        item: item,
        knownStatus: knownStatus,
      );
      ShellTvCardQuickMenu.show(context, actions: actions, title: item.name);
    };
  }

  static Future<void> _toggleList(
    BuildContext context,
    ListFollowTarget target, {
    required bool remove,
  }) async {
    ProviderContainer? container;
    try {
      container = ProviderScope.containerOf(context, listen: false);
    } catch (_) {}
    final ok = await ListFollow.setStatus(
      target,
      remove ? '' : BookmarkStore.defaultStatus,
      container: container,
    );
    if (ok) {
      ForjaToast.success(
        remove ? 'Removed from My List' : 'Added to My List',
        duration: const Duration(seconds: 1),
      );
    } else {
      ForjaToast.error(
        remove
            ? 'Removed locally · Simkl failed'
            : 'Saved locally · Simkl failed',
      );
    }
  }
}
