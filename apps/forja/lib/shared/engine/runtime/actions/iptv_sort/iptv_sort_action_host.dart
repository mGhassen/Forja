import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/shared/engine/portals/models.dart';
import 'package:forja/shared/engine/runtime/actions/iptv_sort/iptv_live_sort_menu.dart';
import 'package:forja/shared/engine/runtime/actions/iptv_sort/iptv_live_sort_providers.dart';
import 'package:forja/shared/engine/runtime/nav/feed_chrome.dart';
import 'package:forja/shared/player/controls/menus/player_popup_panel.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/widgets/chrome/action_chip.dart';
import 'package:forja_foundation/widgets/chrome/layout_scope.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

/// IPTV top-bar Sort — exact pre-wipe PlayerPopupPanel (Categories + Channels).
abstract final class IptvSortActionHost {
  IptvSortActionHost._();

  static Widget buildSortChip(
    BuildContext context,
    WidgetRef ref, {
    required String tabId,
    String label = 'Sort',
    IconData icon = Icons.filter_list_rounded,
    String? tvRowId,
    int? tvItemIndex,
  }) {
    return _IptvSortChip(
      tabId: tabId,
      label: label,
      icon: icon,
      tvRowId: tvRowId,
      tvItemIndex: tvItemIndex,
    );
  }
}

class _IptvSortChip extends ConsumerStatefulWidget {
  const _IptvSortChip({
    required this.tabId,
    required this.label,
    required this.icon,
    this.tvRowId,
    this.tvItemIndex,
  });

  final String tabId;
  final String label;
  final IconData icon;
  final String? tvRowId;
  final int? tvItemIndex;

  @override
  ConsumerState<_IptvSortChip> createState() => _IptvSortChipState();
}

class _IptvSortChipState extends ConsumerState<_IptvSortChip> {
  final GlobalKey _anchorKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    unawaited(_hydrate());
  }

  Future<void> _hydrate() async {
    await hydrateIptvLiveSortProviders(ref);
    if (!mounted) return;
    final content = ref.read(iptvLiveContentSortProvider);
    _applyContentToChrome(content);
  }

  void _applyContentToChrome(PortalCatalogSort sort) {
    final scope = LayoutScope.maybeOf(context);
    scope?.onSelect('sort', sort.prefsValue, toggle: false);
    final key = kitChromeKeyForTab(widget.tabId);
    if (key.isNotEmpty) {
      ref.read(kitFeedSortPrefProvider(key).notifier).state = sort.prefsValue;
    }
  }

  void _openMenu() {
    final category = ref.read(iptvLiveCategorySortProvider);
    final content = ref.read(iptvLiveContentSortProvider);
    // Leanback chrome is × tvChromeScale (~0.62); keep the panel tight to the
    // short labels (Playlist Order / Name) instead of the 280 desktop width.
    final tv = ShellPaintScope.usesTvDensityOf(context);
    PlayerPopupPanel.show(
      context: context,
      title: 'Sort',
      showHeader: false,
      anchorContext: _anchorKey.currentContext,
      alignment: Alignment.topRight,
      margin: const EdgeInsets.only(right: 12, top: 56),
      width: tv ? 200 : 280,
      maxHeight: 420,
      shellBg: ForjaShellColors.surfaceElevated,
      child: IptvLiveSortMenu(
        categorySort: category,
        contentSort: content,
        onCategorySort: (sort) {
          unawaited(setIptvLiveCategorySort(ref, sort));
        },
        onContentSort: (sort) {
          unawaited(setIptvLiveContentSort(ref, sort));
          if (!mounted) return;
          _applyContentToChrome(sort);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final category = ref.watch(iptvLiveCategorySortProvider);
    final content = ref.watch(iptvLiveContentSortProvider);
    final custom = category != PortalCatalogSort.playlist ||
        content != PortalCatalogSort.playlist;
    final chip = ForjaActionChip(
      label: widget.label,
      icon: widget.icon,
      iconOnly: true,
      selected: custom,
      tvItemIndex: widget.tvItemIndex,
      onTap: _openMenu,
    );
    final tab = widget.tabId.trim();
    final row = (widget.tvRowId ?? '').trim();
    return KeyedSubtree(
      key: _anchorKey,
      child: tab.isEmpty || row.isEmpty
          ? chip
          : ShellPaintTvRowScope(
              tabId: tab,
              rowId: row,
              child: chip,
            ),
    );
  }
}
