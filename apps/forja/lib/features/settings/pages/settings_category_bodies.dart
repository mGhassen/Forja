import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rust/rust.dart';
import 'package:forja/features/my_list/lists_screen.dart';
import 'package:forja/features/settings/sections/settings_about_panel.dart';
import 'package:forja/features/settings/sections/settings_cache_data_section.dart';
import 'package:forja/features/settings/sections/settings_debrid_section.dart';
import 'package:forja/features/settings/sections/settings_mdblist_panel.dart';
import 'package:forja/features/settings/sections/settings_playback_section.dart';
import 'package:forja/features/settings/sections/settings_providers_section.dart';
import 'package:forja/features/settings/sections/settings_search_torrents_section.dart';
import 'package:forja/features/settings/sections/settings_simkl_panel.dart';
import 'package:forja/features/settings/sections/settings_trakt_panel.dart';
import 'package:forja/features/settings/sections/settings_webstreamr_section.dart';
import 'package:forja/features/settings/settings_catalog.dart';
import 'package:forja/features/settings/splash_preview_screen.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/services/app_version.dart';
import 'package:forja/shell/nav_config.dart';

/// Builds the body for a Settings category (lazy — only when selected / pushed).
Widget buildSettingsCategoryBody(String categoryId) {
  switch (categoryId) {
    case SettingsCategoryId.playback:
      return const SettingsPlaybackSection();
    case SettingsCategoryId.sources:
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsSearchTorrentsSection(),
          SettingsProvidersSection(),
        ],
      );
    case SettingsCategoryId.webstreamr:
      return const SettingsWebstreamrSection();
    case SettingsCategoryId.debrid:
      return const SettingsDebridSection();
    case SettingsCategoryId.accounts:
      return const SettingsAccountsPageBody();
    case SettingsCategoryId.lists:
      return const ListsScreen(embedded: true);
    case SettingsCategoryId.data:
      return const SettingsDataPageBody();
    case SettingsCategoryId.navigation:
      return const SettingsNavigationPageBody();
    case SettingsCategoryId.about:
      return const SettingsAboutPageBody();
    default:
      return const SizedBox.shrink();
  }
}

/// Pushed detail route for mobile / TV.
class SettingsCategoryPage extends StatelessWidget {
  const SettingsCategoryPage({super.key, required this.categoryId});

  final String categoryId;

  @override
  Widget build(BuildContext context) {
    final meta = settingsCategoryById(categoryId);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SettingsPageScaffold(
        title: meta?.title ?? 'Settings',
        showBack: true,
        scrollable: !(meta?.fillViewport ?? false),
        child: buildSettingsCategoryBody(categoryId),
      ),
    );
  }
}

class SettingsAccountsPageBody extends StatelessWidget {
  const SettingsAccountsPageBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          label: 'Trakt',
          children: const [SettingsTraktPanel()],
        ),
        SettingsGroup(
          label: 'Simkl',
          children: const [SettingsSimklPanel()],
        ),
        SettingsGroup(
          label: 'MDBlist',
          children: const [SettingsMdblistPanel()],
        ),
      ],
    );
  }
}

class SettingsDataPageBody extends StatefulWidget {
  const SettingsDataPageBody({super.key});

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
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsString(jsonStr);

      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Settings',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: Uint8List.fromList(utf8.encode(jsonStr)),
      );

      if (result != null) {
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          await File(result).writeAsString(jsonStr);
        }
      }

      await tempFile.delete();

      if (result != null && mounted) {
        ForjaToast.success('Settings exported successfully!');
      }
    } catch (e) {
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
          'This will overwrite all your current settings, including addons, API keys, and preferences. Continue?',
      confirmLabel: 'Import',
      destructive: true,
    );
    if (!confirm) return;

    setState(() => _isImporting = true);
    try {
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      await _settings.importAllSettings(data);
      if (mounted) ForjaToast.success('Settings imported successfully!');
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SettingsFilledButton(
                        label: 'Export',
                        icon: Icons.upload_rounded,
                        busy: _isExporting,
                        onPressed: _exportSettings,
                      ),
                      const SizedBox(width: 12),
                      SettingsFilledButton(
                        label: 'Import',
                        icon: Icons.download_rounded,
                        secondary: true,
                        busy: _isImporting,
                        onPressed: _importSettings,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SettingsCacheDataSection(),
      ],
    );
  }
}

class SettingsNavigationPageBody extends StatefulWidget {
  const SettingsNavigationPageBody({super.key});

  @override
  State<SettingsNavigationPageBody> createState() =>
      _SettingsNavigationPageBodyState();
}

class _SettingsNavigationPageBodyState
    extends State<SettingsNavigationPageBody> {
  final SettingsService _settings = SettingsService();
  List<String> _navbarVisible = [];
  List<String> _navbarOrder = [];
  String _defaultNavTab = 'home';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var navVisible = await _settings.getNavbarConfig();
    final defaultNavTab = await _settings.getDefaultNavTab();
    final allIds = SettingsService.allNavIds;
    final hidden = allIds.where((id) => !navVisible.contains(id)).toList();
    var navOrder = [...navVisible, ...hidden];
    if (!PlatformPlayback.capabilities.builtinTorrentSearch) {
      navOrder = navOrder
          .where((id) => !PlatformPlayback.torrentNavIds.contains(id))
          .toList();
      navVisible.removeWhere(
        (id) => PlatformPlayback.torrentNavIds.contains(id),
      );
    }

    if (!mounted) return;
    setState(() {
      _navbarVisible = navVisible;
      _navbarOrder = navOrder;
      final startupOptions = _startupTabOptionsFor(
        navOrder,
        navVisible,
      );
      _defaultNavTab = startupOptions.contains(defaultNavTab)
          ? defaultNavTab
          : (startupOptions.isNotEmpty ? startupOptions.first : 'settings');
      if (_defaultNavTab != defaultNavTab) {
        _settings.setDefaultNavTab(_defaultNavTab);
      }
    });
  }

  List<String> _startupTabOptionsFor(
    List<String> order,
    List<String> visible,
  ) {
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

  void _saveNavbarConfig() {
    final visible = _navbarOrder
        .where((id) => _navbarVisible.contains(id))
        .toList();
    _settings.setNavbarConfig(visible);
    final startupOptions = _startupTabOptions();
    if (!startupOptions.contains(_defaultNavTab)) {
      final resolved = startupOptions.isNotEmpty
          ? startupOptions.first
          : 'settings';
      setState(() => _defaultNavTab = resolved);
      _settings.setDefaultNavTab(resolved);
    }
  }

  void _setDefaultNavTab(String id) {
    setState(() => _defaultNavTab = id);
    _settings.setDefaultNavTab(id);
  }

  Widget _defaultNavStar(String id, {required bool enabled}) {
    final isDefault = _defaultNavTab == id;
    return IconButton(
      tooltip: isDefault ? 'Default menu' : 'Set as default menu',
      onPressed: enabled ? () => _setDefaultNavTab(id) : null,
      icon: Icon(
        isDefault ? Icons.star_rounded : Icons.star_border_rounded,
        color: isDefault
            ? ForjaShellColors.brandGreen
            : enabled
                ? ForjaShellColors.iconMuted
                : ForjaShellColors.borderSubtle,
        size: 21,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Show, hide, and reorder navigation tabs. Drag to reorder. Settings is always visible.',
            style: TextStyle(
              color: ForjaShellColors.textSecondary.withValues(alpha: 0.9),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
        SettingsGroup(
          children: [
            ReorderableListView.builder(
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
                _saveNavbarConfig();
              },
              itemBuilder: (context, index) {
                final id = _navbarOrder[index];
                final dest = navDestinations[id]!;
                final isVisible = _navbarVisible.contains(id);

                return Container(
                  key: ValueKey(id),
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 2),
                    leading: NavDestinationIcon(
                      destination: dest,
                      selected: isVisible,
                      color: isVisible
                          ? ForjaShellColors.textPrimary
                          : ForjaShellColors.iconMuted,
                      size: 22,
                    ),
                    title: Text(
                      dest.label,
                      style: TextStyle(
                        color: isVisible
                            ? ForjaShellColors.textPrimary
                            : ForjaShellColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _defaultNavStar(id, enabled: isVisible),
                        Switch(
                          value: isVisible,
                          activeTrackColor: ForjaShellColors.brandGreen,
                          onChanged: (val) {
                            setState(() {
                              if (val) {
                                _navbarVisible.add(id);
                              } else {
                                _navbarVisible.remove(id);
                              }
                            });
                            _saveNavbarConfig();
                          },
                        ),
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
                    ),
                  ),
                );
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 2),
              leading: const Icon(
                Icons.settings,
                color: ForjaShellColors.brandGreen,
                size: 22,
              ),
              title: const Text(
                'Settings',
                style: TextStyle(
                  color: ForjaShellColors.brandGreen,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _defaultNavStar('settings', enabled: true),
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

class SettingsAboutPageBody extends StatelessWidget {
  const SettingsAboutPageBody({super.key});

  @override
  Widget build(BuildContext context) {
    final loaded = Engine.isReady;
    final version = loaded
        ? RustLib.instance.version
        : 'not loaded (Dart fallback)';
    final statusColor =
        loaded ? ForjaShellColors.brandGreen : const Color(0xFFFB923C);
    final platformNote = loaded
        ? ''
        : Platform.isAndroid || Platform.isIOS
            ? ' — run ./scripts/build_rust_mobile.sh and rebuild'
            : ' — run ./scripts/build_rust.sh';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          label: 'Updates',
          children: const [SettingsAboutPanel()],
        ),
        SettingsGroup(
          label: 'Developer',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 16, 2, 16),
              child: Row(
                children: [
                  Icon(Icons.memory_rounded, size: 18, color: statusColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      loaded
                          ? 'Rust engine active — v$version'
                          : 'Rust engine inactive — $version$platformNote',
                      style: TextStyle(color: statusColor, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            if (kDebugMode &&
                (Platform.isMacOS || Platform.isWindows || Platform.isLinux))
              SettingsActionRow(
                leading: const Icon(
                  Icons.play_circle_outline,
                  color: ForjaShellColors.iconActive,
                ),
                title: 'Preview Splash Screen',
                subtitle: 'Show the boot splash without restarting',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SplashPreviewScreen(),
                  ),
                ),
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
