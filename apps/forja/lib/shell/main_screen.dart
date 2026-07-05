import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shell/nav_config.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja_storage/forja_storage.dart';
import 'package:forja_api/services/app_updater_service.dart';
import 'package:forja/shared/widgets/desktop_window_chrome.dart';
import 'package:forja/shared/widgets/update_dialog.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  static State<MainScreen>? of(BuildContext context) {
    return context.findAncestorStateOfType<_MainScreenState>();
  }

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  Timer? _metricsDebounce;
  Timer? _metricsSafety;

  /// All screens keyed by nav ID — created once, never recreated.
  late final Map<String, Widget> _allScreens = buildAllScreens();

  /// Currently visible nav IDs (always ends with 'settings').
  List<String> _visibleIds = [...SettingsService.allNavIds, 'settings'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ShellBus.stremioSearchNotifier.addListener(_onStremioSearch);
    ShellBus.requestTab.addListener(_onRequestTab);
    SettingsService.navbarChangeNotifier.addListener(_onNavbarConfigChanged);

    _loadNavbarConfig();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    try {
      final updater = AppUpdaterService();
      final updateInfo = await updater.checkForUpdates();
      if (updateInfo != null && mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => UpdateDialog(updateInfo: updateInfo),
        );
      }
    } catch (e) {
      debugPrint('[MainScreen] Update check failed: $e');
    }
  }

  Future<void> _loadNavbarConfig() async {
    final visible = await SettingsService().getNavbarConfig();
    if (!mounted) return;
    setState(() {
      // Remember which screen we're currently on
      final currentId = _selectedIndex < _visibleIds.length
          ? _visibleIds[_selectedIndex]
          : null;
      _visibleIds = [...visible, 'settings'];
      // Try to stay on the same screen after reorder/hide
      if (currentId != null) {
        final newIndex = _visibleIds.indexOf(currentId);
        if (newIndex >= 0) {
          _selectedIndex = newIndex;
        } else if (_selectedIndex >= _visibleIds.length) {
          _selectedIndex = _visibleIds.length - 1;
        }
      } else if (_selectedIndex >= _visibleIds.length) {
        _selectedIndex = 0;
      }
    });
  }

  void _onNavbarConfigChanged() {
    _loadNavbarConfig();
  }

  /// Rotation on MediaTek/Transsion can cause a multi-second frame storm.
  /// Two-timer strategy:
  ///   1. Debounced timer (1.5s): resets on every metrics change, fires
  ///      after the storm quiets down.
  ///   2. Safety timer (4s): fires once after the FIRST metrics change—
  ///      never cancelled—so even if the storm outlasts the debounce,
  ///      a clean rebuild is guaranteed.
  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // Debounced: fires 1.5s after the LAST metrics change.
    _metricsDebounce?.cancel();
    _metricsDebounce = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() {});
    });
    // Safety: fires 4s after the FIRST metrics change. Never cancelled.
    _metricsSafety ??= Timer(const Duration(seconds: 4), () {
      _metricsSafety = null;
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && Platform.isAndroid) {
      // Only re-apply immersive mode; do NOT reset preferred orientations
      // here — it interferes with the player's orientation lock when the
      // player is pushed on top of this screen.
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  void _onStremioSearch() {
    final data = ShellBus.stremioSearchNotifier.value;
    if (data == null || (data['query'] ?? '').isEmpty) return;
    final idx = _visibleIds.indexOf('search');
    if (idx != -1) setState(() => _selectedIndex = idx);
  }

  void _onRequestTab() {
    final id = ShellBus.requestTab.value;
    if (id == null) return;
    final idx = _visibleIds.indexOf(id);
    if (idx != -1 && mounted) setState(() => _selectedIndex = idx);
    ShellBus.requestTab.value = null;
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  void searchComics(String query) {
    final idx = _visibleIds.indexOf('comics');
    if (idx != -1) setState(() => _selectedIndex = idx);
  }

  void searchManga(String query) {
    final idx = _visibleIds.indexOf('manga');
    if (idx != -1) setState(() => _selectedIndex = idx);
  }

  @override
  void dispose() {
    _metricsDebounce?.cancel();
    _metricsSafety?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    ShellBus.stremioSearchNotifier.removeListener(_onStremioSearch);
    ShellBus.requestTab.removeListener(_onRequestTab);
    SettingsService.navbarChangeNotifier.removeListener(_onNavbarConfigChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;
    
    final bool useNavRail = isDesktop || isLandscape;

    final shell = Scaffold(
      body: Stack(
        children: [
          // Base gradient
          Container(decoration: AppTheme.effectiveBackground),
          // Ambient glows (skipped in light mode)
          if (!AppTheme.isLightMode) ...[
          // Ambient purple glow – top-right
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.current.primaryColor.withValues(alpha: 0.18),
                    AppTheme.current.primaryColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Ambient cyan glow – bottom-left
          Positioned(
            bottom: 40,
            left: -80,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.current.accentColor.withValues(alpha: 0.08),
                    AppTheme.current.accentColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Soft violet glow – center-left
          Positioned(
            top: MediaQuery.of(context).size.height * 0.35,
            left: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.current.primaryColor.withValues(alpha: 0.10),
                    AppTheme.current.primaryColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          ], // end light mode glow skip
          // Content layer
          Row(
            children: [
              if (useNavRail)
              SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height),
                  child: IntrinsicHeight(
                    child: NavigationRail(
                          backgroundColor: Colors.transparent,
                          selectedIndex: _selectedIndex,
                          onDestinationSelected: _onItemTapped,
                          labelType: NavigationRailLabelType.all,
                          indicatorColor: AppTheme.current.primaryColor,
                          selectedLabelTextStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          unselectedLabelTextStyle: const TextStyle(
                            color: Colors.white54,
                          ),
                          leading: Padding(
                            padding: EdgeInsets.fromLTRB(
                              isDesktop && Platform.isMacOS ? 4 : 0,
                              isDesktop && Platform.isMacOS ? 8 : 24,
                              0,
                              24,
                            ),
                            child: Image.asset(
                              'assets/icon/logo-f-192.png',
                              width: 48,
                              height: 48,
                            ),
                          ),
                          destinations: _visibleIds.map((id) {
                            final meta = navMeta[id]!;
                            return NavigationRailDestination(
                              icon: Icon(meta['icon'] as IconData, color: Colors.white54),
                              selectedIcon: Icon(meta['active'] as IconData, color: Colors.white),
                              label: Text(meta['label'] as String),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: _visibleIds.map((id) => _allScreens[id]!).toList(),
              ),
            ),
          ],
        ),
        ],
      ),
      bottomNavigationBar: useNavRail
          ? null
          : _buildScrollableBottomNav(),
    );

    return DesktopWindowChrome.wrapShell(child: shell);
  }

  Widget _buildScrollableBottomNav() {
    final lightMode = AppTheme.isLightMode;

    Widget navContent = Container(
          height: 80,
          decoration: BoxDecoration(
            color: AppTheme.current.bgDark.withValues(alpha: lightMode ? 1.0 : 0.75),
            border: const Border(top: BorderSide(color: Colors.white10, width: 0.5)),
          ),
          child: Stack(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _visibleIds.asMap().entries.map((entry) {
                final int idx = entry.key;
                final String id = entry.value;
                final meta = navMeta[id]!;
                final bool isSelected = _selectedIndex == idx;

                return InkWell(
                  onTap: () => _onItemTapped(idx),
                  child: Container(
                    width: 100,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.current.primaryColor.withValues(alpha: 0.2) : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            isSelected ? meta['active'] as IconData : meta['icon'] as IconData,
                            color: isSelected ? Colors.white : Colors.white54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          meta['label'] as String,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white54,
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          if (!lightMode)
          Positioned(
            right: 0, top: 0, bottom: 0,
            child: IgnorePointer(
              child: Container(
                width: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Colors.transparent, AppTheme.current.bgDark.withValues(alpha: 0.7)],
                  ),
                ),
                child: const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.white24),
              ),
            ),
          ),
        ],
      ),
    );

    if (lightMode) {
      return ClipRect(child: navContent);
    }

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: navContent,
      ),
    );
  }
}
