import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Switch;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rust/rust.dart';
import 'package:forja/features/settings/providers/settings_panel_providers.dart';
import 'package:forja/features/settings/ui/settings_ui.dart';
import 'package:forja/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shell/tv/shell_tv_focus.dart';
import 'package:forja/shell/tv/tv_focus_graph.dart';
import 'package:forja/shell/nav/nav_config.dart';
import 'package:forja/shared/engine/runtime/nav/plugin_nav.dart';
import 'package:forja/shared/engine/packs/registry/plugin_registry.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shared/sync/sync.dart';
import 'package:forja_foundation/components/switch.dart';
import 'package:forja/shell/focus/shell_focusable_tap.dart';
import 'package:forja_foundation/tokens/forja_settings_tokens.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

class SettingsNavigationPageBody extends ConsumerStatefulWidget {
  const SettingsNavigationPageBody({super.key});

  @override
  ConsumerState<SettingsNavigationPageBody> createState() =>
      _SettingsNavigationPageBodyState();
}

class _SettingsNavigationPageBodyState
    extends ConsumerState<SettingsNavigationPageBody> {
  final SettingsService _settings = SettingsService();
  final FocusNode _firstTabFocus = FocusNode(
    debugLabel: 'settings-features-tab-0',
  );
  List<String> _navbarVisible = [];
  // Hub rows from pack nav; addon-gated host tabs arrive after Addons ON /
  // provider hydrate (not pre-seeded as activatable Features).
  List<String> _navbarOrder = [
    for (final id in PluginNavRegistry.featureTabIds())
      if (!archivedNavIds.contains(id)) id,
  ];
  String _defaultNavTab = 'settings';
  bool _loaded = false;
  int _handledEnterToken = 0;
  /// Skip provider hydrate while a Features write is in flight (stale snap
  /// was wiping OK enables — 224).
  int _saveEpoch = 0;
  int _writesInFlight = 0;
  /// Visible set after the latest Features toggle/save — ignore provider
  /// snaps until they match. Stale richer snaps were re-enabling a just-hidden
  /// tab; then the drop-guard blocked the correct thinner snap (first OFF no-op).
  List<String>? _pendingVisible;
  Future<void> _saveChain = Future<void>.value();

  bool get _featuresWriteInFlight => _writesInFlight > 0;

  @override
  void initState() {
    super.initState();
    // Features is the edit surface — push only on toggle/reorder.
    // Soft-pull lives on Settings/Addons open + resume (not here); pulling
    // while editing crushed the upsert the user just made (224).
  }

  @override
  void dispose() {
    _firstTabFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _focusFirstTabIfEntered();
  }

  /// Features loads tab rows async — land on the first tab after OK / → enter.
  void _focusFirstTabIfEntered() {
    if (!mounted) return;
    if (!ShellScope.metricsOf(context).usesTvDensity) return;
    final token = SettingsDetailEnter.tokenOf(context);
    if (token <= 0 || token == _handledEnterToken) return;
    if (!_loaded || _navbarOrder.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (SettingsDetailEnter.tokenOf(context) != token) return;
      // Only while the detail pane owns focus (not when ↑/↓ only selected Features).
      if (!FocusScope.of(context).hasFocus) return;
      _handledEnterToken = token;
      final firstId = _navbarOrder.first;
      // Column 0 = tab label (not the star). Reading-order land can miss hover.
      if (ShellTvFocusCoordinator.focusRowItem(
        'settings',
        'feat-$firstId',
        0,
      )) {
        return;
      }
      if (_firstTabFocus.canRequestFocus) {
        _firstTabFocus.requestFocus();
      }
    });
  }

  void _hydrate(SettingsNavigationSnapshot snap) {
    _navbarVisible = List.of(snap.visible);
    _navbarOrder = List.of(snap.order);
    _defaultNavTab = snap.defaultTab;
    _loaded = true;
    _focusFirstTabIfEntered();
  }

  List<String> _startupTabOptionsFor(List<String> order, List<String> visible) {
    final seen = <String>{};
    final options = <String>[];
    for (final id in order) {
      if (visible.contains(id) && seen.add(id)) {
        options.add(id);
      }
    }
    if (seen.add('settings')) {
      options.add('settings');
    }
    return options;
  }

  List<String> _startupTabOptions() =>
      _startupTabOptionsFor(_navbarOrder, _navbarVisible);

  Future<void> _saveNavbarConfig() async {
    final epoch = ++_saveEpoch;
    _writesInFlight++;
    final visible = _navbarOrder
        .where((id) => _navbarVisible.contains(id))
        .toList();
    _pendingVisible = List<String>.from(visible);
    // Dirty before KV so soft pull cannot wipe a mid-edit enable (224).
    noteNavigationDirty();
    try {
      // Await KV write before scheduling push — otherwise syncFromCloud can
      // flush a pending navigation overlay that still reads the old empty
      // visibleIds and snap Features toggles back off (issue 221).
      await _settings.setNavbarConfig(visible, tabOrder: _navbarOrder);
      if (!mounted || epoch != _saveEpoch) return;
      await scheduleNavigationSyncPush();
      if (!mounted || epoch != _saveEpoch) return;
      final startupOptions = _startupTabOptions();
      if (!startupOptions.contains(_defaultNavTab)) {
        final resolved = startupOptions.isNotEmpty
            ? startupOptions.first
            : 'settings';
        if (mounted) setState(() => _defaultNavTab = resolved);
        await _settings.setDefaultNavTab(resolved);
        await scheduleNavigationSyncPush();
      }
    } finally {
      _writesInFlight--;
    }
  }

  /// Queue full order writes so an older empty snapshot cannot finish after a
  /// newer enable and wipe KV (224 — Features OK then Addons next=[live] only).
  void _enqueueFullSave() {
    _saveChain = _saveChain.then((_) async {
      if (!mounted) return;
      await _saveNavbarConfig();
    });
    unawaited(_saveChain);
  }

  Future<void> _setDefaultNavTab(String id) async {
    setState(() => _defaultNavTab = id);
    await _settings.setDefaultNavTab(id);
    await scheduleNavigationSyncPush();
  }

  Future<void> _toggleNavbarVisible(String id, {bool? enable}) async {
    final next = enable ?? !_navbarVisible.contains(id);
    if (_navbarVisible.contains(id) == next) return;
    setState(() {
      if (next) {
        if (!_navbarVisible.contains(id)) _navbarVisible.add(id);
      } else {
        _navbarVisible.remove(id);
      }
    });
    final epoch = ++_saveEpoch;
    _writesInFlight++;
    _pendingVisible = List<String>.from(_navbarVisible);
    noteNavigationDirty();
    debugPrint('[Features] toggle $id → $next');
    try {
      final updated = await _settings.setNavbarTabVisible(id, next);
      debugPrint('[Features] navbar next=$updated');
      if (!mounted || epoch != _saveEpoch) return;
      setState(() => _navbarVisible = List.of(updated));
      _pendingVisible = List<String>.from(updated);
      // Rail first — do not await cloud push before the shell reloads.
      SettingsService.navbarChangeNotifier.value++;
      if (!mounted || epoch != _saveEpoch) return;
      final verify = await _settings.getNavbarConfig();
      debugPrint('[Features] navbar verify=$verify');
      if (next && !verify.contains(id)) {
        debugPrint('[Features] heal re-enable $id after strip race');
        final healed = await _settings.setNavbarTabVisible(id, true);
        if (!mounted || epoch != _saveEpoch) return;
        setState(() => _navbarVisible = List.of(healed));
        _pendingVisible = List<String>.from(healed);
        SettingsService.navbarChangeNotifier.value++;
      }
      if (!mounted || epoch != _saveEpoch) return;
      final startupOptions = _startupTabOptions();
      if (!startupOptions.contains(_defaultNavTab)) {
        final resolved = startupOptions.isNotEmpty
            ? startupOptions.first
            : 'settings';
        setState(() => _defaultNavTab = resolved);
        await _settings.setDefaultNavTab(resolved);
      }
      // Cloud after local rail is stable — await so logs show upsert before
      // any concurrent soft-pull grace kicks in.
      await scheduleNavigationSyncPush();
    } catch (e, st) {
      debugPrint('[Features] toggle $id failed: $e\n$st');
    } finally {
      _writesInFlight--;
    }
  }

  void _moveNavbarItem(int from, int to) {
    if (from == to || from < 0 || to < 0 || to >= _navbarOrder.length) {
      return;
    }
    setState(() {
      final item = _navbarOrder.removeAt(from);
      _navbarOrder.insert(to, item);
    });
    _enqueueFullSave();
  }

  Widget _defaultNavStar(
    BuildContext context,
    String id, {
    required bool enabled,
    required bool tv,
    required String tvRowId,
    required int tvItemIndex,
  }) {
    final isDefault = _defaultNavTab == id;
    final iconSize = SettingsTokens.iconButtonIconSizeOf(context);
    final hit = SettingsTokens.iconButtonHitSizeOf(context);
    final icon = Icon(
      isDefault ? Icons.star_rounded : Icons.star_border_rounded,
      color: isDefault
          ? ForjaShellColors.brandGreen
          : enabled
          ? ForjaShellColors.iconMuted
          : ForjaShellColors.borderSubtle,
      size: iconSize,
    );
    if (!tv) {
      return IconButton(
        tooltip: isDefault ? 'Default menu' : 'Set as default menu',
        onPressed: enabled ? () => unawaited(_setDefaultNavTab(id)) : null,
        icon: icon,
      );
    }
    // TV: shellFocusableTap (not IconButton) so the focus graph owns the node.
    return shellFocusableTap(
      context: context,
      onTap: enabled ? () => unawaited(_setDefaultNavTab(id)) : null,
      borderRadius: hit / 2,
      scaleOnFocus: 1.0,
      showFocusRail: false,
      showFocusFill: true,
      showFocusBorder: true,
      tvTabId: 'settings',
      tvZone: ShellTvZone.row,
      tvRowId: tvRowId,
      tvItemIndex: tvItemIndex,
      ensureVisibleMode: ShellPaintEnsureVisible.item,
      child: SizedBox(width: hit, height: hit, child: Center(child: icon)),
    );
  }

  Widget _navMoveChip(
    BuildContext context, {
    required IconData icon,
    required bool enabled,
    required VoidCallback? onTap,
    required String tvRowId,
    required int tvItemIndex,
  }) {
    final chevron = SettingsTokens.expandChevronSizeOf(context);
    final hitW = SettingsTokens.expandChevronHitSizeOf(context) * 0.7;
    final hitH = SettingsTokens.iconButtonHitSizeOf(context) * 0.9;
    return shellFocusableTap(
      context: context,
      onTap: enabled ? onTap : null,
      borderRadius: 6,
      scaleOnFocus: ShellTokens.focusActiveScale,
      showFocusRail: false,
      showFocusFill: true,
      showFocusBorder: true,
      tvTabId: 'settings',
      tvZone: ShellTvZone.row,
      tvRowId: tvRowId,
      tvItemIndex: tvItemIndex,
      ensureVisibleMode: ShellPaintEnsureVisible.item,
      child: SizedBox(
        width: hitW,
        height: hitH,
        child: Icon(
          icon,
          size: chevron,
          color: enabled
              ? ForjaShellColors.textPrimary
              : ForjaShellColors.iconMuted,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(settingsNavigationProvider);
    ref.listen<
      AsyncValue<SettingsNavigationSnapshot>
    >(settingsNavigationProvider, (previous, next) {
      final snap = next.valueOrNull;
      if (snap == null) return;
      // In-flight Features write — stale provider snap must not wipe OK state.
      if (_featuresWriteInFlight) return;
      final pending = _pendingVisible;
      if (pending != null) {
        final pendingSet = pending.toSet();
        final snapSet = snap.visible.toSet();
        if (pendingSet.length != snapSet.length ||
            !pendingSet.containsAll(snapSet)) {
          debugPrint(
            '[Features] skip hydrate until pending visible matches '
            'pending=$pending snap=${snap.visible}',
          );
          return;
        }
        _pendingVisible = null;
      }
      // Cloud pull often re-emits the same nav — skip setState so focus stays.
      if (_loaded &&
          listEquals(_navbarVisible, snap.visible) &&
          listEquals(_navbarOrder, snap.order) &&
          _defaultNavTab == snap.defaultTab) {
        return;
      }
      setState(() => _hydrate(snap));
    });
    if (!_loaded) {
      final snap = async.valueOrNull;
      if (snap != null) _hydrate(snap);
    }
    final policy = ShellScope.inputPolicyOf(context);
    final tv = policy.useFocusableMoodChips;
    final leanback = tv && !policy.scaleOnHover;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueListenableBuilder<String>(
          valueListenable: SettingsService.shellWritingDirection,
          builder: (context, direction, _) {
            final rightToLeft =
                direction == SettingsService.shellWritingRtl;
            return SettingsSelectRow(
              title: 'Navbar side',
              subtitle: 'Choose which side the navbar sits on.',
              value: rightToLeft ? 'Right to left' : 'Left to right',
              options: const ['Left to right', 'Right to left'],
              onChanged: (picked) {
                if (picked == null) return;
                unawaited(
                  _settings.setShellWritingDirection(
                    picked == 'Right to left'
                        ? SettingsService.shellWritingRtl
                        : SettingsService.shellWritingLtr,
                  ),
                );
              },
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            leanback
                ? 'OK toggles a tab. Star sets the default menu. ↑/↓ on arrows reorder. ↓ stays in the same column.'
                : 'Show, hide, and reorder tabs. Drag to reorder. Settings stays visible.',
            style: TextStyle(
              color: ForjaShellColors.textSecondary.withValues(alpha: 0.9),
              fontSize: SettingsTokens.typeSizeOf(context, 13),
              height: 1.4,
            ),
          ),
        ),
        SettingsGroup(
          children: [
            Builder(
              builder: (context) {
                final list = ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: _navbarOrder.length,
                  proxyDecorator: (child, index, animation) {
                    return Material(color: Colors.transparent, child: child);
                  },
                  onReorderItem: (oldIndex, newIndex) {
                    setState(() {
                      final item = _navbarOrder.removeAt(oldIndex);
                      _navbarOrder.insert(newIndex, item);
                    });
                    _enqueueFullSave();
                  },
                  itemBuilder: (context, index) {
                    final id = _navbarOrder[index];
                    // Same as rail: keep a focusable row even when the hub pack
                    // has not contributed nav yet (lean / missing install).
                    final dest = navDestinationFor(id) ??
                        NavDestination(
                          id: id,
                          icon: Icons.apps_outlined,
                          activeIcon: Icons.apps,
                          label: PluginRegistry.hubSlotLabel(id) ?? id,
                        );
                    final isVisible = _navbarVisible.contains(id);
                    final rowId = 'feat-$id';
                    // Columns: 0=tab, 1=star, 2=up, 3=down — ↓ keeps column.
                    final itemCount = leanback ? 4 : (tv ? 2 : 0);

                    final controls = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _defaultNavStar(
                          context,
                          id,
                          enabled: isVisible,
                          tv: tv,
                          tvRowId: rowId,
                          tvItemIndex: 1,
                        ),
                        // Switch is pointer/desktop; on TV OK on the label toggles.
                        ExcludeFocus(
                          excluding: leanback,
                          child: Switch(
                            value: isVisible,
                            scale: Switch.settingsScale,
                            onChanged: (val) {
                              unawaited(
                                _toggleNavbarVisible(id, enable: val),
                              );
                            },
                          ),
                        ),
                        if (leanback)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _navMoveChip(
                                context,
                                icon: Icons.keyboard_arrow_up_rounded,
                                enabled: index > 0,
                                onTap: () =>
                                    _moveNavbarItem(index, index - 1),
                                tvRowId: rowId,
                                tvItemIndex: 2,
                              ),
                              _navMoveChip(
                                context,
                                icon: Icons.keyboard_arrow_down_rounded,
                                enabled: index < _navbarOrder.length - 1,
                                onTap: () =>
                                    _moveNavbarItem(index, index + 1),
                                tvRowId: rowId,
                                tvItemIndex: 3,
                              ),
                            ],
                          )
                        else
                          ReorderableDragStartListener(
                            index: index,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.drag_handle,
                                color: ForjaShellColors.iconMuted,
                                size: SettingsTokens.iconButtonIconSizeOf(
                                  context,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );

                    Widget row = Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: shellFocusableTap(
                              context: context,
                              focusNode: index == 0 ? _firstTabFocus : null,
                              onTap: () => unawaited(_toggleNavbarVisible(id)),
                              borderRadius: SettingsTokens.categoryTileRadius,
                              scaleOnFocus: 1.0,
                              showFocusRail: true,
                              tvTabId: 'settings',
                              tvZone: ShellTvZone.row,
                              tvRowId: rowId,
                              tvItemIndex: 0,
                              ensureVisibleMode:
                                  ShellPaintEnsureVisible.item,
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: SettingsTokens.rowMinHeightOf(
                                        context,
                                      ) *
                                      0.18,
                                ),
                                child: Row(
                                  children: [
                                    NavDestinationIcon(
                                      destination: dest,
                                      selected: isVisible,
                                      color: isVisible
                                          ? ForjaShellColors.textPrimary
                                          : ForjaShellColors.iconMuted,
                                      size: SettingsTokens
                                          .categoryIconSizeOf(context),
                                    ),
                                    SizedBox(
                                      width: SettingsTokens.pagePaddingOf(
                                            context,
                                          ) *
                                          0.8,
                                    ),
                                    Expanded(
                                      child: Text(
                                        dest.label,
                                        style: TextStyle(
                                          color: isVisible
                                              ? ForjaShellColors.textPrimary
                                              : ForjaShellColors
                                                    .textSecondary,
                                          fontSize: SettingsTokens.typeSizeOf(
                                            context,
                                            14,
                                          ),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          controls,
                        ],
                      ),
                    );

                    if (tv && itemCount > 0) {
                      // Column stickiness: pass the *current* column into the
                      // next/prev feature row. moveVerticalInTab would restore
                      // that row's lastFocusedIndex (often the star) instead.
                      // First-row ↑ must trap — otherwise focusHero jumps to the
                      // category rail ("menu settings").
                      int currentColumn() {
                        final h = ShellTvFocusCoordinator.rowHandle(
                          'settings',
                          rowId,
                        );
                        return (h?.lastFocusedIndex ?? 0)
                            .clamp(0, itemCount - 1);
                      }

                      void focusFeatureAt(int rowIndex, int column) {
                        if (rowIndex < 0 || rowIndex >= _navbarOrder.length) {
                          return;
                        }
                        final targetId = _navbarOrder[rowIndex];
                        final targetRow = 'feat-$targetId';
                        final targetCount = leanback ? 4 : 2;
                        final c = column.clamp(0, targetCount - 1);
                        ShellTvFocusCoordinator.focusRowItem(
                          'settings',
                          targetRow,
                          c,
                        );
                      }

                      row = TvKitRow(
                        tabId: 'settings',
                        rowId: rowId,
                        // Keep clear of settings-categories (sortOrder 0).
                        sortOrder: 100 + index,
                        itemCount: itemCount,
                        onFocusUp: () {
                          final column = currentColumn();
                          if (index <= 0) {
                            focusFeatureAt(0, column);
                            return;
                          }
                          focusFeatureAt(index - 1, column);
                        },
                        onFocusDown: () {
                          final column = currentColumn();
                          if (index >= _navbarOrder.length - 1) {
                            ShellTvFocusCoordinator.focusRowItem(
                              'settings',
                              'feat-settings',
                              0,
                            );
                            return;
                          }
                          focusFeatureAt(index + 1, column);
                        },
                        child: row,
                      );
                    }

                    return Container(
                      key: ValueKey(id),
                      color: Colors.transparent,
                      child: row,
                    );
                  },
                );
                if (!tv) return list;
                return ShellTvDisableLinearFocus(child: list);
              },
            ),
            Builder(
              builder: (context) {
                Widget footer = Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.settings,
                        color: ForjaShellColors.brandGreen,
                        size: SettingsTokens.categoryIconSizeOf(context),
                      ),
                      SizedBox(
                        width: SettingsTokens.pagePaddingOf(context) * 0.8,
                      ),
                      Expanded(
                        child: Text(
                          'Settings',
                          style: TextStyle(
                            color: ForjaShellColors.brandGreen,
                            fontSize: SettingsTokens.typeSizeOf(context, 14),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      _defaultNavStar(
                        context,
                        'settings',
                        enabled: true,
                        tv: tv,
                        tvRowId: 'feat-settings',
                        tvItemIndex: 0,
                      ),
                      Icon(
                        Icons.lock_outline,
                        color: ForjaShellColors.iconMuted.withValues(alpha: 0.5),
                        size: SettingsTokens.expandChevronSizeOf(context),
                      ),
                      SizedBox(
                        width: SettingsTokens.pagePaddingOf(context) * 0.4,
                      ),
                      Text(
                        'Always visible',
                        style: TextStyle(
                          color: ForjaShellColors.textSecondary.withValues(
                            alpha: 0.7,
                          ),
                          fontSize: SettingsTokens.typeSizeOf(context, 11),
                        ),
                      ),
                    ],
                  ),
                );
                if (!tv) return footer;
                // Own row so reading-order cannot yank ↑/↓ onto this star mid-list.
                return TvKitRow(
                  tabId: 'settings',
                  rowId: 'feat-settings',
                  sortOrder: 100 + _navbarOrder.length,
                  itemCount: 1,
                  onFocusUp: () {
                    // Walk upward until a row actually has a focus node.
                    for (var i = _navbarOrder.length - 1; i >= 0; i--) {
                      final id = _navbarOrder[i];
                      if (ShellTvFocusCoordinator.focusRowItem(
                        'settings',
                        'feat-$id',
                        0,
                      )) {
                        return;
                      }
                    }
                    // No feature rows (or none registered) — leave detail.
                    ShellTvFocusCoordinator.tryPageBack('settings');
                  },
                  onFocusDown: () {
                    ShellTvFocusCoordinator.focusRowItem(
                      'settings',
                      'feat-settings',
                      0,
                    );
                  },
                  child: footer,
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

