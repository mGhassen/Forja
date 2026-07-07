import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/features/search/search_screen.dart';
import 'package:forja/shell/nav_config.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shell/shell_scaffold.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';
import 'package:rust/rust.dart';
import 'package:forja/shared/services/app_updater_service.dart';
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

  final GlobalKey<SearchScreenState> _searchKey = GlobalKey<SearchScreenState>();
  final Map<String, Widget> _tabCache = {};
  final Set<String> _mountedTabIds = {'home'};
  List<String> _visibleIds = [...SettingsService.defaultVisibleNavIds, 'settings'];

  Widget _tabFor(String id) {
    assert(navTabBuilders.containsKey(id));
    final isNew = !_tabCache.containsKey(id);
    final tab = _tabCache.putIfAbsent(id, () {
      if (id == 'search') {
        return SearchScreen(key: _searchKey);
      }
      return navTabBuilders[id]!();
    });
    if (isNew && kDebugMode) {
      debugPrint('[MainScreen] Built tab: $id');
    }
    return tab;
  }

  Widget? _shellHeader() {
    if (_visibleIds.isEmpty || _selectedIndex >= _visibleIds.length) return null;
    if (_visibleIds[_selectedIndex] != 'search') return null;
    return _searchKey.currentState?.buildShellSearchBar();
  }

  void _selectTab(int index) {
    final id = _visibleIds[index];
    setState(() {
      _mountedTabIds.add(id);
      _selectedIndex = index;
    });
    _applyTabShellChrome(id);
    if (id == 'search') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  bool _musicUsesOwnSidebar(BuildContext context) {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      return false;
    }
    return MediaQuery.sizeOf(context).width > ShellTokens.musicDesktopBreakpoint;
  }

  void _applyTabShellChrome(String tabId) {
    if (tabId == 'music') {
      ShellBus.hideGlobalNav.value = _musicUsesOwnSidebar(context);
    } else if (tabId != 'iptv') {
      ShellBus.hideGlobalNav.value = false;
    }
    ShellBus.notifyShellChromeChanged();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ShellBus.stremioSearchNotifier.addListener(_onStremioSearch);
    ShellBus.requestTab.addListener(_onRequestTab);
    ShellBus.shellChromeRevision.addListener(_onShellChromeChanged);
    ShellBus.hideGlobalNav.addListener(_onShellChromeChanged);
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
    var visible = await SettingsService().getNavbarConfig();
    if (!PlatformPlayback.capabilities.builtinTorrentSearch) {
      visible = visible
          .where((id) => !PlatformPlayback.torrentNavIds.contains(id))
          .toList();
    }
    if (!mounted) return;
    setState(() {
      final currentId = _selectedIndex < _visibleIds.length
          ? _visibleIds[_selectedIndex]
          : null;
      _visibleIds = [...visible, 'settings'];
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

  void _onShellChromeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (_visibleIds.isNotEmpty && _selectedIndex < _visibleIds.length) {
      _applyTabShellChrome(_visibleIds[_selectedIndex]);
    }
    _metricsDebounce?.cancel();
    _metricsDebounce = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() {});
    });
    _metricsSafety ??= Timer(const Duration(seconds: 4), () {
      _metricsSafety = null;
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && Platform.isAndroid) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  void _onStremioSearch() {
    final data = ShellBus.stremioSearchNotifier.value;
    if (data == null || (data['query'] ?? '').isEmpty) return;
    final idx = _visibleIds.indexOf('search');
    if (idx != -1) _selectTab(idx);
  }

  void _onRequestTab() {
    final id = ShellBus.requestTab.value;
    if (id == null) return;
    final idx = _visibleIds.indexOf(id);
    if (idx != -1 && mounted) _selectTab(idx);
    ShellBus.requestTab.value = null;
  }

  void searchComics(String query) {
    final idx = _visibleIds.indexOf('comics');
    if (idx != -1) _selectTab(idx);
  }

  void searchManga(String query) {
    final idx = _visibleIds.indexOf('manga');
    if (idx != -1) _selectTab(idx);
  }

  @override
  void dispose() {
    _metricsDebounce?.cancel();
    _metricsSafety?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    ShellBus.stremioSearchNotifier.removeListener(_onStremioSearch);
    ShellBus.requestTab.removeListener(_onRequestTab);
    ShellBus.shellChromeRevision.removeListener(_onShellChromeChanged);
    ShellBus.hideGlobalNav.removeListener(_onShellChromeChanged);
    ShellBus.clearHideGlobalNav();
    SettingsService.navbarChangeNotifier.removeListener(_onNavbarConfigChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    final isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    final useNavRail = isDesktop || isLandscape;

    return DesktopWindowChrome.wrapShell(
      child: ShellScaffold(
        useNavRail: useNavRail,
        isDesktop: isDesktop,
        visibleIds: _visibleIds,
        selectedIndex: _selectedIndex,
        mountedTabIds: _mountedTabIds,
        onDestinationSelected: _selectTab,
        tabFor: _tabFor,
        shellHeader: _shellHeader(),
        hideGlobalNav: ShellBus.hideGlobalNav.value,
      ),
    );
  }
}
