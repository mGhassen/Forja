import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/settings/addons/settings_addon_catalog.dart';
import 'package:forja/features/settings/addons/settings_addon_detail.dart';
import 'package:forja/features/settings/addons/settings_addon_toggles.dart';
import 'package:forja/features/settings/providers/settings_panel_providers.dart';
import 'package:forja/features/settings/providers/settings_visibility_provider.dart';
import 'package:forja/features/settings/settings_catalog.dart';
import 'package:forja/features/settings/settings_visibility.dart';
import 'package:forja/features/settings/widgets/settings_pack_prompt_pane.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/foundation/primitives/primitives.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/lan/lan_prefs.dart';
import 'package:forja/shared/foundation/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/foundation/tv/shell_tv_focus.dart';
import 'package:forja/shared/foundation/tv/tv_focus_graph.dart';
import 'package:forja/shell/bus/shell_bus.dart';
import 'package:forja/shared/sync/sync.dart';

/// Open addon inside Settings → Addons. Hub chrome listens so the page title
/// is the addon name (not a second "Addons" heading).
class SettingsAddonDrill {
  static final ValueNotifier<SettingsAddonMeta?> current =
      ValueNotifier<SettingsAddonMeta?>(null);

  /// Focus on the list control that opened this drill (row / chevron).
  static ShellTvFocusMemory? returnFocus;

  static void close() {
    current.value = null;
    // Keep [returnFocus] until the list host restores it (same frame listeners).
  }

  static void clearReturnFocus() {
    returnFocus = null;
  }

  /// Snapshot [returnFocus] only when leaving the list (null → open).
  static void open(SettingsAddonMeta meta) {
    if (current.value == null) {
      final mem = ShellTvFocusCoordinator.memoryFor('settings');
      final rowId = 'addon-${meta.id}';
      returnFocus = (mem != null && mem.rowId == rowId)
          ? mem
          : ShellTvFocusMemory(
              zone: ShellTvZone.row,
              rowId: rowId,
              itemIndex: 0,
            );
    }
    current.value = meta;
  }
}

/// Category page chrome that swaps title for addon detail or pack install picker.
class SettingsAddonsAwareScaffold extends StatelessWidget {
  const SettingsAddonsAwareScaffold({
    super.key,
    required this.categoryTitle,
    required this.child,
    this.categoryId,
    this.categoryAdminOnly = false,
    this.scrollable = true,
    this.categoryBack = false,
  });

  final String categoryTitle;
  final Widget child;
  final String? categoryId;
  final bool categoryAdminOnly;
  final bool scrollable;
  final bool categoryBack;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SettingsAddonMeta?>(
      valueListenable: SettingsAddonDrill.current,
      builder: (context, addon, _) {
        return ValueListenableBuilder<PluginBatchInstallPrompt?>(
          valueListenable: SettingsPackPromptDrill.current,
          builder: (context, packPrompt, _) {
            final packOpen = packPrompt != null &&
                categoryId == SettingsCategoryId.forjaPacks;
            final title = packOpen
                ? SettingsPackPromptDrill.titleFor(packPrompt)
                : (addon?.title ?? categoryTitle);
            return SettingsPageScaffold(
              title: title,
              adminOnly: packOpen
                  ? false
                  : (addon?.adminOnly ?? categoryAdminOnly),
              showBack: packOpen || addon != null || categoryBack,
              onBack: packOpen
                  ? () {
                      unawaited(
                        SettingsPackPromptDrill.dismissWithoutApply(),
                      );
                    }
                  : addon != null
                      ? SettingsAddonDrill.close
                      : () => Navigator.of(context).maybePop(),
              // Pack picker: fill pane so the list scrolls and Install stays pinned
              // (same shape as Update Forja — header + scroll + footer).
              scrollable: packOpen ? false : scrollable,
              child: child,
            );
          },
        );
      },
    );
  }
}

/// Settings → Addons body.
///
/// Shows a master list of addons with activate toggles. Tapping an addon row
/// replaces the list with that addon's detail (back returns to the list).
/// On compact layout this is always a single-column view; the split hub
/// scaffold handles left rail ↔ right pane.
class SettingsAddonsHost extends StatefulWidget {
  const SettingsAddonsHost({
    super.key,
    required this.visibility,
    this.initialAddonId,
  });

  final SettingsVisibility visibility;

  /// Pre-open a specific addon detail (deep-link from old category IDs).
  final String? initialAddonId;

  @override
  State<SettingsAddonsHost> createState() => SettingsAddonsHostState();
}

class SettingsAddonsHostState extends State<SettingsAddonsHost> {
  List<SettingsAddonMeta> _packContributed = const [];

  @override
  void initState() {
    super.initState();
    SettingsAddonDrill.current.addListener(_onDrill);
    EngineService.changeNotifier.addListener(_onEngineChanged);
    unawaited(_reloadPackAddons());
    final initialId = widget.initialAddonId ?? ShellBus.pendingAddonDeepLink;
    ShellBus.pendingAddonDeepLink = null;
    if (initialId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_openWhenReady(initialId));
      });
    }
  }

  @override
  void dispose() {
    SettingsAddonDrill.current.removeListener(_onDrill);
    EngineService.changeNotifier.removeListener(_onEngineChanged);
    super.dispose();
  }

  void _onDrill() {
    final open = SettingsAddonDrill.current.value;
    if (open == null) {
      final snap = SettingsAddonDrill.returnFocus;
      SettingsAddonDrill.returnFocus = null;
      if (snap != null) {
        _scheduleRestoreFocus(snap);
      }
    }
    if (mounted) setState(() {});
  }

  void _scheduleRestoreFocus(ShellTvFocusMemory snap) {
    void attempt(int n) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!ShellScope.inputPolicyOf(context).useFocusableMoodChips) return;
        final rowId = snap.rowId;
        if (rowId == null || rowId.isEmpty) return;
        // Prefer exact index (chevron vs row); soft fallback if node not ready.
        final ok = ShellTvFocusCoordinator.focusRowItemExact(
              'settings',
              rowId,
              snap.itemIndex,
            ) ||
            ShellTvFocusCoordinator.focusRowItem(
              'settings',
              rowId,
              snap.itemIndex,
            );
        if (!ok && n < 12) attempt(n + 1);
      });
    }

    attempt(0);
  }

  void _onEngineChanged() {
    if (!mounted) return;
    unawaited(_reloadPackAddons());
  }

  Future<void> _reloadPackAddons() async {
    final packs = await EngineService.instance.listPacks();
    final plugins = <EnginePlugin>[
      for (final pack in packs)
        if (pack.enabled)
          for (final p in pack.plugins) p,
    ];
    final contributed = packContributedAddonMetas(plugins);
    if (!mounted) return;
    setState(() => _packContributed = contributed);
  }

  Future<void> _openWhenReady(String addonId) async {
    await _reloadPackAddons();
    if (!mounted) return;
    final meta = settingsAddonById(
      addonId,
      packContributed: _packContributed,
    );
    if (meta != null) SettingsAddonDrill.open(meta);
  }

  void _open(String addonId) {
    final meta = settingsAddonById(
      addonId,
      packContributed: _packContributed,
    );
    if (meta != null) SettingsAddonDrill.open(meta);
  }

  @override
  Widget build(BuildContext context) {
    final open = SettingsAddonDrill.current.value;
    if (open != null) {
      final adminBlocked =
          open.adminOnly && !AccountFeatures.instance.isAdmin;
      if (adminBlocked) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          SettingsAddonDrill.close();
        });
        return const SizedBox.shrink();
      }
      return buildAddonDetailBody(open.id, widget.visibility);
    }
    return _AddonListPane(
      visibility: widget.visibility,
      packContributed: _packContributed,
      onOpen: _open,
    );
  }
}

class _AddonListPane extends ConsumerStatefulWidget {
  const _AddonListPane({
    required this.visibility,
    required this.packContributed,
    required this.onOpen,
  });

  final SettingsVisibility visibility;
  final List<SettingsAddonMeta> packContributed;
  final ValueChanged<String> onOpen;

  @override
  ConsumerState<_AddonListPane> createState() => _AddonListPaneState();
}

class _AddonListPaneState extends ConsumerState<_AddonListPane> {
  @override
  void initState() {
    super.initState();
    // Soft pull so web/cloud Features + play-source edits land while this
    // pane is open. Force: opening Addons is an intentional refresh (224) —
    // 15s debounce otherwise leaves cloud-enabled IPTV off.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(SyncDomainBridge.instance.syncFromCloud(force: true));
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(accountFeaturesProvider);
    final addons = settingsAddons(packContributed: widget.packContributed);
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    // Spatial rows: OK activates; → details. Linear scope would walk columns
    // as one reading-order line.
    final list = ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: addons.length,
      separatorBuilder: (_, _) => Padding(
        padding: const EdgeInsets.only(left: 2),
        child: Divider(
          height: 1,
          thickness: 1,
          color: ForjaShellColors.borderSubtle.withValues(alpha: 0.6),
        ),
      ),
      itemBuilder: (context, index) {
        final addon = addons[index];
        return _AddonRow(
          meta: addon,
          visibility: widget.visibility,
          sortOrder: index,
          onOpen: () => widget.onOpen(addon.id),
        );
      },
    );
    if (!tv) return list;
    return ShellTvDisableLinearFocus(child: list);
  }
}

class _AddonRow extends ConsumerStatefulWidget {
  const _AddonRow({
    required this.meta,
    required this.visibility,
    required this.sortOrder,
    required this.onOpen,
  });

  final SettingsAddonMeta meta;
  final SettingsVisibility visibility;
  final int sortOrder;
  final VoidCallback onOpen;

  @override
  ConsumerState<_AddonRow> createState() => _AddonRowState();
}

class _AddonRowState extends ConsumerState<_AddonRow> {
  late final FocusNode _rowFocus =
      FocusNode(debugLabel: 'addon-row-${widget.meta.id}');
  late final FocusNode _detailsFocus =
      FocusNode(debugLabel: 'addon-details-${widget.meta.id}');
  bool? _optimisticEnabled;
  bool _lanEnabled = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.meta.id == SettingsAddonId.lan) {
      unawaited(_hydrateLan());
    }
  }

  Future<void> _hydrateLan() async {
    _lanEnabled = await LanPrefs.instance.isLanServerEnabled();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _rowFocus.dispose();
    _detailsFocus.dispose();
    super.dispose();
  }

  Future<void> _activateRow() async {
    if (_busy || !widget.meta.hasToggle) return;
    final snap = ref.read(settingsPlaybackProvider).valueOrNull;
    final visAsync = ref.read(settingsVisibilityProvider);
    final visibility = visAsync.hasValue
        ? visAsync.requireValue
        : widget.visibility;
    final debridAsync = ref.read(settingsDebridProvider);
    final debridEnabled =
        debridAsync.hasValue ? debridAsync.requireValue.useDebrid : false;
    final enabled = addonMasterEnabled(
      addonId: widget.meta.id,
      snap: snap,
      visibility: visibility,
      debridEnabled: debridEnabled,
      lanEnabled: _lanEnabled,
    );
    final next = !enabled;
    debugPrint(
      '[AddonToggle] flip ${widget.meta.id} ${enabled ? "ON→OFF" : "OFF→ON"}',
    );
    _busy = true;
    setState(() => _optimisticEnabled = next);
    try {
      final applied = await setAddonMasterEnabled(
        ref,
        context,
        addonId: widget.meta.id,
        val: next,
      );
      if (!mounted) return;
      if (!applied) {
        setState(() => _optimisticEnabled = null);
        return;
      }
      if (widget.meta.id == SettingsAddonId.lan) {
        setState(() => _lanEnabled = next);
      }
    } catch (e, st) {
      debugPrint('[AddonToggle] row ${widget.meta.id} failed: $e\n$st');
      if (mounted) setState(() => _optimisticEnabled = null);
    } finally {
      _busy = false;
      if (mounted && _optimisticEnabled != null) {
        setState(() => _optimisticEnabled = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = widget.meta;
    final visibility = widget.visibility;
    final leanback = ShellScope.inputPolicyOf(context).leanbackOnly;
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final rowId = 'addon-${meta.id}';

    // Keep switch in sync with providers when parent optimistic catches up.
    if (meta.hasToggle) {
      final snap = ref.watch(settingsPlaybackProvider).valueOrNull;
      final visAsync = ref.watch(settingsVisibilityProvider);
      final vis = visAsync.hasValue ? visAsync.requireValue : visibility;
      final debridAsync = ref.watch(settingsDebridProvider);
      final debridEnabled =
          debridAsync.hasValue ? debridAsync.requireValue.useDebrid : false;
      final computed = addonMasterEnabled(
        addonId: meta.id,
        snap: snap,
        visibility: vis,
        debridEnabled: debridEnabled,
        lanEnabled: _lanEnabled,
      );
      if (_optimisticEnabled != null && _optimisticEnabled == computed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _optimisticEnabled == computed) {
            setState(() => _optimisticEnabled = null);
          }
        });
      }
    }

    final titles = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        settingsTitleText(
          meta.title,
          const TextStyle(
            color: ForjaShellColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          adminOnly: meta.adminOnly,
          sparkSize: 14,
        ),
        const SizedBox(height: 2),
        Text(
          meta.subtitle,
          style: const TextStyle(
            color: ForjaShellColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );

    final leading =
        Icon(meta.icon, color: ForjaShellColors.textSecondary, size: 22);

    // Same trailing slot for every row so chevrons share one right edge —
    // toggle rows used to pin the arrow in a 40 + 4 slot while plain rows
    // put a bare Icon inside content padding.
    const chevron = SizedBox(
      width: 40,
      height: 40,
      child: Center(
        child: Icon(
          Icons.chevron_right_rounded,
          color: ForjaShellColors.iconMuted,
          size: 22,
        ),
      ),
    );

    final detailsBtn = shellFocusableTap(
      context: context,
      focusNode: _detailsFocus,
      onTap: widget.onOpen,
      borderRadius: 8,
      scaleOnFocus: 1.0,
      showFocusRail: false,
      showFocusFill: true,
      showFocusBorder: true,
      tvTabId: 'settings',
      tvZone: ShellTvZone.row,
      tvRowId: rowId,
      tvItemIndex: meta.hasToggle ? 1 : 0,
      ensureVisibleMode: ShellTvEnsureVisibleMode.item,
      onLeftEdge: leanback && meta.hasToggle
          ? () {
              _rowFocus.requestFocus();
            }
          : null,
      child: chevron,
    );

    Widget body;
    if (meta.hasToggle) {
      body = Row(
        children: [
          Expanded(
            child: shellFocusableTap(
              context: context,
              focusNode: _rowFocus,
              onTap: () => unawaited(_activateRow()),
              borderRadius: SettingsTokens.categoryTileRadius,
              scaleOnFocus: 1.0,
              showFocusRail: true,
              tvTabId: 'settings',
              tvZone: ShellTvZone.row,
              tvRowId: rowId,
              tvItemIndex: 0,
              ensureVisibleMode: ShellTvEnsureVisibleMode.item,
              onRightEdge: leanback
                  ? () {
                      _detailsFocus.requestFocus();
                    }
                  : null,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 2, vertical: 16),
                child: Row(
                  children: [
                    leading,
                    const SizedBox(width: 12),
                    Expanded(child: titles),
                    AddonMasterToggle(
                      addonId: meta.id,
                      visibility: visibility,
                      chromeOnly: true,
                      optimisticEnabled: _optimisticEnabled,
                    ),
                  ],
                ),
              ),
            ),
          ),
          detailsBtn,
          const SizedBox(width: 4),
        ],
      );
    } else {
      body = shellFocusableTap(
        context: context,
        focusNode: _rowFocus,
        onTap: widget.onOpen,
        borderRadius: SettingsTokens.categoryTileRadius,
        scaleOnFocus: 1.0,
        showFocusRail: true,
        tvTabId: 'settings',
        tvZone: ShellTvZone.row,
        tvRowId: rowId,
        tvItemIndex: 0,
        ensureVisibleMode: ShellTvEnsureVisibleMode.item,
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 2, vertical: 16),
                child: Row(
                  children: [
                    leading,
                    const SizedBox(width: 12),
                    Expanded(child: titles),
                  ],
                ),
              ),
            ),
            chevron,
            const SizedBox(width: 4),
          ],
        ),
      );
    }

    if (!tv) return body;
    return TvKitRow(
      tabId: 'settings',
      rowId: rowId,
      sortOrder: widget.sortOrder,
      itemCount: meta.hasToggle ? 2 : 1,
      child: body,
    );
  }
}
