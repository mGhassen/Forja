import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rust/rust.dart';
import 'package:forja/shared/services/app_version.dart';
import 'package:forja/features/my_list/lists_screen.dart';
import 'splash_preview_screen.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shell/nav_config.dart';
import 'package:forja/features/settings/sections/settings_about_panel.dart';
import 'package:forja/features/settings/sections/settings_cache_data_section.dart';
import 'package:forja/features/settings/sections/settings_debrid_section.dart';
import 'package:forja/features/settings/sections/settings_mdblist_panel.dart';
import 'package:forja/features/settings/sections/settings_playback_section.dart';
import 'package:forja/features/settings/sections/settings_providers_section.dart';
import 'package:forja/features/settings/sections/settings_search_torrents_section.dart';
import 'package:forja/features/settings/sections/settings_simkl_panel.dart';
import 'package:forja/features/settings/sections/settings_trakt_panel.dart';
import 'package:forja/features/settings/widgets/settings_expandable_section.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';

/// Settings tab — RFC-024 R24-A13: local prefs only; no ShellTabRefresh / API stale policy.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settings = SettingsService();

  // Navbar config
  List<String> _navbarVisible = [];
  List<String> _navbarOrder = [];
  String _defaultNavTab = 'home';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
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

    if (mounted) {
      setState(() {
        _navbarVisible = navVisible;
        _navbarOrder = navOrder;
        final startupOptions = <String>[];
        final seenStartup = <String>{};
        for (final id in navOrder) {
          if (navVisible.contains(id) && seenStartup.add(id)) {
            startupOptions.add(id);
          }
        }
        if (seenStartup.add('settings')) {
          startupOptions.add('settings');
        }
        _defaultNavTab = startupOptions.contains(defaultNavTab)
            ? defaultNavTab
            : (startupOptions.isNotEmpty ? startupOptions.first : 'settings');
        if (_defaultNavTab != defaultNavTab) {
          _settings.setDefaultNavTab(_defaultNavTab);
        }
      });
    }
  }

  @override
  void dispose() {
    ShellTvFocusCoordinator.clearTab('settings');
    _scrollController.dispose();
    super.dispose();
  }

  // Owned scroll controller for the settings list. Without this the
  // Scrollbar attaches to the PrimaryScrollController, which on desktop
  // makes thumb-drag distance jump every time a section expands and the
  // scroll extent grows under your cursor.
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        interactive: true,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(
            ShellTokens.bodyHorizontalPadding,
            0,
            ShellTokens.bodyHorizontalPadding,
            12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ShellTabHeader(title: 'Settings'),

              // ── Backup & Restore ──
              SettingsExpandableSection(
                initiallyExpanded: true,
                id: 'backup',
                icon: Icons.backup_rounded,
                title: 'Backup & Restore',
                children: [_buildBackupRestore()],
              ),

              const SettingsPlaybackSection(),

              const SettingsCacheDataSection(),

              const SettingsSearchTorrentsSection(),

              const SettingsProvidersSection(),

              const SettingsDebridSection(),


              // ── Accounts & Sync ──
              SettingsExpandableSection(
                id: 'accounts',
                icon: Icons.sync_rounded,
                title: 'Accounts & Sync',
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'TRAKT',
                      style: TextStyle(
                        color: AppTheme.current.primaryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const SettingsTraktPanel(),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'SIMKL',
                      style: TextStyle(
                        color: AppTheme.current.primaryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const SettingsSimklPanel(),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'MDBLIST',
                      style: TextStyle(
                        color: AppTheme.current.primaryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const SettingsMdblistPanel(),
                ],
              ),

              // ── Lists ──
              SettingsExpandableSection(
                id: 'lists',
                icon: Icons.list_alt_rounded,
                title: 'Lists',
                children: [_buildListsSection()],
              ),

              // ── Navigation Bar ──
              SettingsExpandableSection(
                id: 'navbar',
                icon: Icons.tab_rounded,
                title: 'Navigation Bar',
                children: [_buildNavbarConfig()],
              ),

              // ── Developer (Rust engine status) ──
              SettingsExpandableSection(
                id: 'developer',
                icon: Icons.developer_mode_rounded,
                title: 'Developer',
                children: [
                  _buildRustEngineSection(),
                  if (kDebugMode &&
                      (Platform.isMacOS ||
                          Platform.isWindows ||
                          Platform.isLinux))
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.play_circle_outline),
                        title: const Text('Preview Splash Screen'),
                        subtitle: const Text(
                          'Show the boot splash overlay without restarting',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SplashPreviewScreen(),
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              // ── App Updates ──
              SettingsExpandableSection(
                id: 'updates',
                icon: Icons.system_update_rounded,
                title: 'App Updates',
                children: [const SettingsAboutPanel()],
              ),

              const SizedBox(height: 40),
              Center(
                child: AppVersionLabel(
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Expandable Section Tile
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildRustEngineSection() {
    final loaded = Engine.isReady;
    final version = loaded
        ? RustLib.instance.version
        : 'not loaded (Dart fallback)';
    final statusColor = loaded ? Colors.greenAccent : Colors.orangeAccent;
    final platformNote = loaded
        ? ''
        : Platform.isAndroid || Platform.isIOS
        ? ' — run ./scripts/build_rust_mobile.sh and rebuild'
        : ' — run ./scripts/build_rust.sh';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Row(
            children: [
              Icon(Icons.memory_rounded, size: 16, color: statusColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  loaded
                      ? 'Rust engine active — v$version'
                      : 'Rust engine inactive — $version$platformNote',
                  style: TextStyle(color: statusColor, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }


  // ═══════════════════════════════════════════════════════════════════════════
  // Backup & Restore
  // ═══════════════════════════════════════════════════════════════════════════

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

      // Write to a temp file first, then let the user pick where to save
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsString(jsonStr);

      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Settings',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: Uint8List.fromList(utf8.encode(jsonStr)),
      );

      if (result != null) {
        // On desktop, saveFile() returns a path but doesn't write — we must do it ourselves
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          await File(result).writeAsString(jsonStr);
        }
      }

      await tempFile.delete();

      if (result != null && mounted) {
        ForjaToast.success('Settings exported successfully!');
      }
    } catch (e) {
      if (mounted) {
        ForjaToast.error('Export failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _importSettings() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Import Settings',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final String jsonStr;
    if (file.bytes != null) {
      jsonStr = utf8.decode(file.bytes!);
    } else if (file.path != null) {
      jsonStr = await File(file.path!).readAsString();
    } else {
      if (mounted) {
        ForjaToast.error('Could not read file.');
      }
      return;
    }

    if (!mounted) return;

    // Confirm before overwriting
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text(
          'Import Settings',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will overwrite all your current settings, including addons, API keys, and preferences. Continue?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Import',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isImporting = true);
    try {
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      await _settings.importAllSettings(data);
      await _loadSettings(); // Refresh all UI state
      if (mounted) {
        ForjaToast.success('Settings imported successfully!');
      }
    } catch (e) {
      if (mounted) {
        ForjaToast.error('Import failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Widget _buildBackupRestore() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Export or import all your settings, addons, API keys, and preferences as a JSON file.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isExporting ? null : _exportSettings,
                  icon: _isExporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.upload_rounded, size: 20),
                  label: const Text('Export'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurpleAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isImporting ? null : _importSettings,
                  icon: _isImporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download_rounded, size: 20),
                  label: const Text('Import'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Navbar Configuration
  // ═══════════════════════════════════════════════════════════════════════════

  void _saveNavbarConfig() {
    final visible = _navbarOrder
        .where((id) => _navbarVisible.contains(id))
        .toList();
    _settings.setNavbarConfig(visible);
    final startupOptions = _startupTabOptions();
    if (!startupOptions.contains(_defaultNavTab)) {
      final resolved = _resolveDefaultNavTab(startupOptions);
      setState(() => _defaultNavTab = resolved);
      _settings.setDefaultNavTab(resolved);
    }
  }

  List<String> _startupTabOptions() {
    final seen = <String>{};
    final options = <String>[];
    for (final id in _navbarOrder) {
      if (_navbarVisible.contains(id) && seen.add(id)) {
        options.add(id);
      }
    }
    if (seen.add('settings')) {
      options.add('settings');
    }
    return options;
  }

  String _resolveDefaultNavTab(List<String> options, {String? preferred}) {
    final candidate = preferred ?? _defaultNavTab;
    if (options.contains(candidate)) return candidate;
    return options.isNotEmpty ? options.first : 'settings';
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
            ? AppTheme.primaryColor
            : enabled
            ? Colors.white38
            : Colors.white12,
        size: 21,
      ),
    );
  }

  Widget _buildListsSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Browse and manage your Trakt and MDBlist custom lists',
            style: TextStyle(fontSize: 13, color: Colors.white54),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ListsScreen()),
              ),
              icon: const Icon(Icons.list_alt_rounded),
              label: const Text('Manage Lists'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavbarConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Show, hide, and reorder navigation tabs. Drag to reorder. Settings is always visible.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 13,
            ),
          ),
        ),
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
              margin: const EdgeInsets.only(bottom: 2),
              decoration: BoxDecoration(
                color: isVisible
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: NavDestinationIcon(
                  destination: dest,
                  selected: isVisible,
                  color: isVisible ? Colors.white : Colors.white24,
                  size: 22,
                ),
                title: Text(
                  dest.label,
                  style: TextStyle(
                    color: isVisible ? Colors.white : Colors.white38,
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
                      activeTrackColor: AppTheme.primaryColor,
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
                          color: Colors.white24,
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
        // Settings row — always visible, not reorderable
        Container(
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
            ),
          ),
          child: ListTile(
            leading: const Icon(
              Icons.settings,
              color: AppTheme.primaryColor,
              size: 22,
            ),
            title: const Text(
              'Settings',
              style: TextStyle(
                color: AppTheme.primaryColor,
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
                  color: Colors.white.withValues(alpha: 0.2),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Always visible',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }






}
