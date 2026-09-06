import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rust/rust.dart';
import 'package:forja/features/settings/providers/settings_panel_providers.dart';
import 'package:forja/features/settings/providers/settings_visibility_provider.dart';
import 'package:forja/features/settings/sections/settings_about_panel.dart';
import 'package:forja/features/settings/sections/settings_cache_data_section.dart';
import 'package:forja/features/settings/addons/settings_addons_host.dart';
import 'package:forja/features/settings/sections/settings_forja_account_panel.dart';
import 'package:forja/features/settings/sections/settings_iptv_portals_section.dart';
import 'package:forja/features/settings/sections/settings_mdblist_panel.dart';
import 'package:forja/features/settings/sections/settings_forja_addons_play_toggles.dart';
import 'package:forja/features/settings/sections/settings_forja_packs_section.dart';
import 'package:forja/features/settings/sections/settings_providers_section.dart';
import 'package:forja/features/settings/sections/settings_search_torrents_section.dart';
import 'package:forja/features/settings/sections/settings_simkl_panel.dart';
import 'package:forja/features/settings/settings_catalog.dart';
import 'package:forja/features/settings/settings_visibility.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/services/app_version.dart';
import 'package:forja/shared/telemetry/product_analytics.dart';
import 'package:forja/shared/telemetry/telemetry.dart';
import 'package:forja/shared/sync/sync.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:forja/shell/nav_config.dart';
import 'package:forja/shared/catalog/plugin_nav.dart';

/// Builds the body for a Settings category (lazy - only when selected / pushed).
Widget buildSettingsCategoryBody(
  String categoryId,
  SettingsVisibility visibility,
) {
  switch (categoryId) {
    case SettingsCategoryId.profile:
      return const SettingsProfileAccountPageBody();
    case SettingsCategoryId.sources:
      return SettingsAddonsHost(visibility: visibility);
    case SettingsCategoryId.forjaPacks:
      return SettingsForjaPacksPageBody(visibility: visibility);
    case SettingsCategoryId.data:
      return SettingsDataPageBody(visibility: visibility);
    case SettingsCategoryId.navigation:
      return const SettingsNavigationPageBody();
    case SettingsCategoryId.about:
      return const SettingsAboutPageBody();
    default:
      return const SizedBox.shrink();
  }
}

/// Pushed detail route for mobile / TV.
class SettingsCategoryPage extends ConsumerWidget {
  const SettingsCategoryPage({super.key, required this.categoryId});

  final String categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibilityAsync = ref.watch(settingsVisibilityProvider);
    // Keep last visibility while reloading — blanking the body remounts Addons
    // mid-toggle and drops optimistic switch state (224).
    final visibility = visibilityAsync.value;
    if (visibility == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: SizedBox.expand(),
      );
    }
    final meta = settingsCategoryById(categoryId, visibility);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ShellTvContainDpad(
        child: ShellTvLinearFocusScope(
          child: FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(),
            child: SettingsAddonsAwareScaffold(
              categoryTitle: meta?.title ?? 'Settings',
              categoryId: categoryId,
              categoryAdminOnly: meta?.adminOnly ?? false,
              categoryBack: true,
              scrollable: !(meta?.fillViewport ?? false),
              child: buildSettingsCategoryBody(categoryId, visibility),
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsSourcesPageBody extends StatelessWidget {
  const SettingsSourcesPageBody({super.key, required this.visibility});

  final SettingsVisibility visibility;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsForjaAddonsPlayToggles(visibility: visibility),
        SettingsForjaAddonsSection(visibility: visibility),
        if (visibility.showTorrentEngine) const SettingsSearchTorrentsSection(),
      ],
    );
  }
}

class SettingsForjaPacksPageBody extends StatelessWidget {
  const SettingsForjaPacksPageBody({super.key, required this.visibility});

  final SettingsVisibility visibility;

  @override
  Widget build(BuildContext context) {
    return SettingsForjaPacksSection(visibility: visibility);
  }
}

class SettingsProfileAccountPageBody extends StatelessWidget {
  const SettingsProfileAccountPageBody({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingsForjaAccountPanel();
  }
}

class SettingsAccountsPageBody extends StatelessWidget {
  const SettingsAccountsPageBody({super.key, required this.visibility});

  final SettingsVisibility visibility;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(label: 'Simkl', children: const [SettingsSimklPanel()]),
        if (visibility.showMdblist)
          const SettingsGroup(
            label: 'MDBlist',
            adminOnly: true,
            children: [SettingsMdblistPanel()],
          ),
      ],
    );
  }
}

class SettingsDataPageBody extends StatefulWidget {
  const SettingsDataPageBody({super.key, required this.visibility});

  final SettingsVisibility visibility;

  @override
  State<SettingsDataPageBody> createState() => _SettingsDataPageBodyState();
}

class _SettingsDataPageBodyState extends State<SettingsDataPageBody> {
  final SettingsService _settings = SettingsService();
  bool _isExporting = false;
  bool _isImporting = false;

  Future<void> _exportSettings() async {
    setState(() => _isExporting = true);
    try {
      final data = await _settings.exportAllSettings();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final fileName = 'forja_settings_$timestamp.json';

      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Settings',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: Uint8List.fromList(utf8.encode(jsonStr)),
      );

      if (result == null) {
        // User cancelled the save dialog.
        return;
      }

      // Desktop saveFile returns a path; write explicitly (sandbox needs
      // com.apple.security.files.user-selected.read-write on macOS).
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        await File(result).writeAsString(jsonStr);
      }

      if (mounted) {
        ForjaToast.success('Settings exported');
      }
    } catch (e, st) {
      debugPrint('[SettingsData] export failed: $e\n$st');
      if (mounted) ForjaToast.error('Export failed: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _importSettings() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Import Settings',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final String jsonStr;
    if (file.bytes != null) {
      jsonStr = utf8.decode(file.bytes!);
    } else if (file.path != null) {
      jsonStr = await File(file.path!).readAsString();
    } else {
      if (mounted) ForjaToast.error('Could not read file.');
      return;
    }

    if (!mounted) return;

    final confirm = await showSettingsConfirmDialog(
      context: context,
      title: 'Import Settings',
      body:
          'This overwrites your current settings, including addons, API keys, and preferences. Continue?',
      confirmLabel: 'Import',
      destructive: true,
    );
    if (!confirm) return;

    setState(() => _isImporting = true);
    try {
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      await _settings.importAllSettings(data);
      if (mounted) ForjaToast.success('Settings imported');
    } catch (e) {
      if (mounted) ForjaToast.error('Import failed: $e');
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          label: 'Backup',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 12, 2, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Export or import all your settings, addons, API keys, and preferences as a JSON file.',
                    style: TextStyle(
                      color: ForjaShellColors.textSecondary.withValues(
                        alpha: 0.9,
                      ),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SettingsFilledButton(
                        label: 'Import',
                        icon: Icons.download_rounded,
                        secondary: true,
                        busy: _isImporting,
                        onPressed: _importSettings,
                      ),
                      const SizedBox(width: 12),
                      SettingsFilledButton(
                        label: 'Export',
                        icon: Icons.upload_rounded,
                        busy: _isExporting,
                        onPressed: _exportSettings,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (widget.visibility.showIptvSettings)
          const SettingsIptvPortalsSection(),
        SettingsCacheDataSection(
          showIptvPortalCache: widget.visibility.showIptvSettings,
        ),
      ],
    );
  }
}

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
  Future<void> _saveChain = Future<void>.value();

  bool get _featuresWriteInFlight => _writesInFlight > 0;

  @override
  void initState() {
    super.initState();
    // Soft pull + await nav heal when this device’s rail is richer than cloud
    // (app Features ON / web OFF — 224).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(SyncDomainBridge.instance.syncFromCloud(force: true));
    });
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
      if (!mounted || !_firstTabFocus.canRequestFocus) return;
      if (SettingsDetailEnter.tokenOf(context) != token) return;
      // Only while the detail pane owns focus (not when ↑/↓ only selected Features).
      if (!FocusScope.of(context).hasFocus) return;
      _handledEnterToken = token;
      _firstTabFocus.requestFocus();
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
    // RMW under the same exclusive lock as Addons — never rewrite the whole
    // visible list from widget memory (concurrent full saves wiped tabs).
    final epoch = ++_saveEpoch;
    _writesInFlight++;
    noteNavigationDirty();
    debugPrint('[Features] toggle $id → $next');
    try {
      final updated = await _settings.setNavbarTabVisible(id, next);
      debugPrint('[Features] navbar next=$updated');
      if (!mounted || epoch != _saveEpoch) return;
      setState(() {
        _navbarVisible = List.of(updated);
      });
      await scheduleNavigationSyncPush();
      if (!mounted || epoch != _saveEpoch) return;
      // Heal strip race: hub refresh must not leave KV without a just-enabled
      // tab while Features still shows ON (224 A04 — ATV rail empty).
      if (next) {
        final again = await _settings.getNavbarConfig();
        if (!again.contains(id)) {
          debugPrint('[Features] heal re-enable $id after strip race');
          final healed = await _settings.setNavbarTabVisible(id, true);
          if (!mounted || epoch != _saveEpoch) return;
          setState(() => _navbarVisible = List.of(healed));
          await scheduleNavigationSyncPush();
        }
      }
      if (!mounted || epoch != _saveEpoch) return;
      final startupOptions = _startupTabOptions();
      if (!startupOptions.contains(_defaultNavTab)) {
        final resolved = startupOptions.isNotEmpty
            ? startupOptions.first
            : 'settings';
        setState(() => _defaultNavTab = resolved);
        await _settings.setDefaultNavTab(resolved);
        await scheduleNavigationSyncPush();
      }
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
    final icon = Icon(
      isDefault ? Icons.star_rounded : Icons.star_border_rounded,
      color: isDefault
          ? ForjaShellColors.brandGreen
          : enabled
          ? ForjaShellColors.iconMuted
          : ForjaShellColors.borderSubtle,
      size: 21,
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
      borderRadius: 8,
      scaleOnFocus: 1.0,
      showFocusRail: false,
      showFocusFill: true,
      showFocusBorder: true,
      tvTabId: 'settings',
      tvZone: ShellTvZone.row,
      tvRowId: tvRowId,
      tvItemIndex: tvItemIndex,
      ensureVisibleMode: ShellTvEnsureVisibleMode.item,
      child: SizedBox(width: 40, height: 40, child: Center(child: icon)),
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
      ensureVisibleMode: ShellTvEnsureVisibleMode.item,
      child: SizedBox(
        width: 28,
        height: 36,
        child: Icon(
          icon,
          size: 20,
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
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            leanback
                ? 'OK toggles a tab. Star sets the default menu. ↑/↓ on arrows reorder. ↓ stays in the same column.'
                : 'Show, hide, and reorder tabs. Drag to reorder. Settings stays visible.',
            style: TextStyle(
              color: ForjaShellColors.textSecondary.withValues(alpha: 0.9),
              fontSize: 13,
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
                    final dest = navDestinations[id];
                    if (dest == null) {
                      return SizedBox.shrink(key: ValueKey('nav-missing-$id'));
                    }
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
                          child: ForjaSwitch(
                            value: isVisible,
                            scale: ForjaSwitch.settingsScale,
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
                            child: const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.drag_handle,
                                color: ForjaShellColors.iconMuted,
                                size: 20,
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
                                  ShellTvEnsureVisibleMode.item,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                child: Row(
                                  children: [
                                    NavDestinationIcon(
                                      destination: dest,
                                      selected: isVisible,
                                      color: isVisible
                                          ? ForjaShellColors.textPrimary
                                          : ForjaShellColors.iconMuted,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        dest.label,
                                        style: TextStyle(
                                          color: isVisible
                                              ? ForjaShellColors.textPrimary
                                              : ForjaShellColors
                                                    .textSecondary,
                                          fontSize: 14,
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
                      row = TvCatalogRow(
                        tabId: 'settings',
                        rowId: rowId,
                        sortOrder: index,
                        itemCount: itemCount,
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.settings,
                    color: ForjaShellColors.brandGreen,
                    size: 22,
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Settings',
                      style: TextStyle(
                        color: ForjaShellColors.brandGreen,
                        fontSize: 14,
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
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Always visible',
                    style: TextStyle(
                      color: ForjaShellColors.textSecondary.withValues(
                        alpha: 0.7,
                      ),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class SettingsAboutPageBody extends ConsumerWidget {
  const SettingsAboutPageBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(accountFeaturesProvider).isAdmin;
    final showDeveloperTools =
        isAdmin &&
        kDebugMode &&
        (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(label: 'Updates', children: const [SettingsAboutPanel()]),
        SettingsGroup(
          label: 'Privacy',
          children: [
            const SettingsCrashReportingRow(),
            const SettingsProductAnalyticsRow(),
            if (isAdmin && Platform.isMacOS) const SettingsMacOsKeychainRow(),
          ],
        ),
        if (showDeveloperTools)
          SettingsGroup(
            label: 'Developer',
            children: [
              SettingsActionRow(
                leading: const Icon(
                  Icons.bug_report_outlined,
                  color: ForjaShellColors.iconActive,
                ),
                title: 'Verify Sentry',
                subtitle: Telemetry.isActive
                    ? 'Send a test exception to the Forja Flutter project'
                    : 'Enable Crash reporting first, then tap again',
                adminOnly: true,
                onTap: () async {
                  try {
                    await Telemetry.sendTestException();
                    ForjaToast.success('Test event sent - check Sentry Issues');
                  } catch (e) {
                    ForjaToast.info('$e');
                  }
                },
              ),
              SettingsActionRow(
                leading: const Icon(
                  Icons.insights_outlined,
                  color: ForjaShellColors.iconActive,
                ),
                title: 'Verify PostHog',
                subtitle: Telemetry.isAnalyticsActive
                    ? 'Send analytics_verify to your PostHog project'
                    : 'Enable Product analytics first, then tap again',
                adminOnly: true,
                onTap: () async {
                  try {
                    await ProductAnalytics.sendTestEvent();
                    ForjaToast.success(
                      'Test event sent - check PostHog → Activity',
                    );
                  } catch (e) {
                    ForjaToast.info('$e');
                  }
                },
              ),
            ],
          ),
        const SizedBox(height: 24),
        Center(
          child: AppVersionLabel(
            style: TextStyle(
              color: ForjaShellColors.textSecondary.withValues(alpha: 0.8),
              fontSize: 13,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
