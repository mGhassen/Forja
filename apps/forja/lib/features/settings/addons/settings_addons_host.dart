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
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/engine/plugin_install_prompt.dart';
import 'package:forja/shared/lan/lan_prefs.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shared/sync/sync.dart';

/// Open addon inside Settings → Addons. Hub chrome listens so the page title
/// is the addon name (not a second "Addons" heading).
class SettingsAddonDrill {
  static final ValueNotifier<SettingsAddonMeta?> current =
      ValueNotifier<SettingsAddonMeta?>(null);

  static void close() => current.value = null;
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
              scrollable: scrollable,
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
  @override
  void initState() {
    super.initState();
    SettingsAddonDrill.current.addListener(_onDrill);
    final initialId = widget.initialAddonId ?? ShellBus.pendingAddonDeepLink;
    ShellBus.pendingAddonDeepLink = null;
    if (initialId != null) {
      SettingsAddonDrill.current.value = settingsAddonById(initialId);
    }
  }

  @override
  void dispose() {
    SettingsAddonDrill.current.removeListener(_onDrill);
    super.dispose();
  }

  void _onDrill() {
    if (mounted) setState(() {});
  }

  void _open(String addonId) {
    SettingsAddonDrill.current.value = settingsAddonById(addonId);
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
      onOpen: _open,
    );
  }
}

class _AddonListPane extends ConsumerStatefulWidget {
  const _AddonListPane({
    required this.visibility,
    required this.onOpen,
  });

  final SettingsVisibility visibility;
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
    // 15s debounce otherwise leaves cloud-enabled IPTV / Live Sports off.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(SyncDomainBridge.instance.syncFromCloud(force: true));
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(accountFeaturesProvider);
    final addons = settingsAddons();
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
      child: const SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: Icon(
            Icons.chevron_right_rounded,
            color: ForjaShellColors.iconMuted,
            size: 22,
          ),
        ),
      ),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 16),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(child: titles),
              const Icon(
                Icons.chevron_right_rounded,
                color: ForjaShellColors.iconMuted,
                size: 20,
              ),
            ],
          ),
        ),
      );
    }

    if (!tv) return body;
    return TvCatalogRow(
      tabId: 'settings',
      rowId: rowId,
      sortOrder: widget.sortOrder,
      itemCount: meta.hasToggle ? 2 : 1,
      child: body,
    );
  }
}
