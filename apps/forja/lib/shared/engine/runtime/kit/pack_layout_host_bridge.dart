/// Binds host engines into foundation [PackLayoutCapabilities] before layout mounts.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/engine/models/models.dart' as eng;
import 'package:forja/shared/engine/packs/install/plugin_install_coordinator.dart'
    as install;
import 'package:forja/shared/engine/packs/registry/plugin_registry.dart' as preg;
import 'package:forja/shared/engine/runtime/meta/plugin_actions.dart' as meta;
import 'package:forja/shared/engine/runtime/nav/chrome_filters.dart' as chrome;
import 'package:forja/shared/engine/runtime/nav/open_catalog_search.dart'
    as catalog_search;
import 'package:forja/shared/engine/runtime/nav/pack_filters.dart' as pfilters;
import 'package:forja/shared/engine/runtime/nav/plugin_nav.dart' as pnav;
import 'package:forja/shared/engine/runtime/open/catalog_open.dart' as copen;
import 'package:forja/shared/engine/runtime/open/meta_movie.dart' as mmovie;
import 'package:forja/shared/engine/runtime/vm/service.dart' as engine;
import 'package:forja/shared/engine/store/list_follow.dart' as lfollow;
import 'package:forja/shared/host/watch/watch_history.dart' as wh;
import 'package:forja/shared/playback/open/history_playback_resume.dart' as hpr;
import 'package:forja/shared/player/details/kit_details_play.dart' as kplay;
import 'package:forja/shared/player/details/kit_details_play_row.dart' as kplayrow;
import 'package:forja/shared/playback/play_context.dart';
import 'package:forja/shared/sync/providers/settings_revision_providers.dart' as srev;
import 'package:forja/shared/playback/play_resolve.dart' as play;
import 'package:forja/shared/player/details/details_meta.dart' as dmeta;
import 'package:forja/shared/player/details/hero_pill_buttons.dart' as hero;
import 'package:forja/shared/player/details/kit_entry_details.dart' as kentry;
import 'package:forja/shared/player/details/kit_list_status_button.dart' as klist;
import 'package:forja/shared/player/details/kit_list_status_hero.dart' as khero;
import 'package:forja/shared/player/sources/kit_sources_panel.dart' as ksrc;
import 'package:forja/shared/shell/chrome/vertical_filters.dart' as vfilters;
import 'package:forja/shared/shell/core/forja_shell_layout.dart' as slayout;
import 'package:forja/shared/shell/core/forja_shell_profile.dart' as sprofile;
import 'package:forja/shared/shell/core/forja_shell_scope.dart' as sscope;
import 'package:forja/shared/shell/feedback/forja_toast.dart' as toast;
import 'package:forja/shared/shell/focus/shell_focusable_tap.dart' as sfocus;
import 'package:forja/shared/shell/tv/media_details_tv_scope.dart' as mdtv;
import 'package:forja/shared/shell/tv/shell_tv_coordinator.dart' as tvcoord;
import 'package:forja/shared/shell/tv/shell_tv_focus.dart' as tvfocus;
import 'package:forja/shared/shell/tv/tv_browse_text_field.dart' as tvfield;
import 'package:forja/shared/shell/tv/tv_focus_graph.dart' as tvgraph;
import 'package:forja/shared/theme/app_theme.dart' as theme;
import 'package:forja/shell/bus/shell_bus.dart' as bus;
import 'package:forja/shell/chrome/kit_chrome_top_bar.dart' as kchrome;
import 'package:forja/shell/chrome/player_surface_chrome_stub.dart' as pstub;
import 'package:forja/shared/engine/runtime/kit/chrome_menu_item.dart';
import 'package:forja/shared/engine/runtime/kit/list/kit_list_entry.dart';
import 'package:forja/shared/shell/desktop/desktop_selectable_title.dart'
    as dtitle;
import 'package:forja/shared/engine/runtime/kit/pack_layout_capabilities.dart'
    hide SettingsService, ShellBus, ShellTvFocus, TvKitRow, WatchHistoryService;
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:rust/rust.dart' as rust;
import 'package:rust/rust.dart' show SettingsService, WatchHistoryService;

/// Call once during app bootstrap (before any [PackLayoutHost] mounts).
void bindPackLayoutHostBridge() {
  PackLayoutCapabilities.bind(_PackLayoutHostBridge());
}

PackLayoutMovie _toPackMovie(rust.Movie m) => PackLayoutMovie(
      id: m.id,
      title: m.title,
      posterPath: m.posterPath,
      backdropPath: m.backdropPath,
      logoPath: m.logoPath,
      voteAverage: m.voteAverage,
      releaseDate: m.releaseDate,
      overview: m.overview,
      genres: m.genres,
      mediaType: m.mediaType,
    );

rust.Movie _toRustMovie(PackLayoutMovie m) => rust.Movie(
      id: m.id,
      title: m.title,
      posterPath: m.posterPath,
      backdropPath: m.backdropPath,
      logoPath: m.logoPath,
      voteAverage: m.voteAverage,
      releaseDate: m.releaseDate,
      overview: m.overview,
      genres: m.genres,
      mediaType: m.mediaType,
    );

PackPluginSnapshot _toSnapshot(eng.EnginePack pack, eng.EnginePlugin plugin) =>
    PackPluginSnapshot(
      id: plugin.id,
      config: Map<String, dynamic>.from(plugin.config),
      sourceUrl: pack.sourceUrl,
      capabilities: List<String>.from(plugin.capabilities),
    );

lfollow.ListFollowTarget _toHostFollow(PackListFollowTarget t) =>
    lfollow.ListFollowTarget(
      pluginId: t.pluginId,
      open: t.open,
      title: t.title,
      posterPath: t.posterPath,
      voteAverage: t.voteAverage,
      releaseDate: t.releaseDate,
      tmdbId: t.tmdbId,
      tmdbMediaType: t.tmdbMediaType,
      mediaType: t.mediaType,
    );

PackListFollowTarget _toPackFollow(lfollow.ListFollowTarget t) =>
    PackListFollowTarget(
      pluginId: t.pluginId,
      open: t.open,
      title: t.title,
      posterPath: t.posterPath,
      voteAverage: t.voteAverage,
      releaseDate: t.releaseDate,
      tmdbId: t.tmdbId,
      tmdbMediaType: t.tmdbMediaType,
      mediaType: t.mediaType,
    );

class _TvFocusBridge implements PackLayoutTvFocus {
  @override
  String? get currentNavTabId => tvfocus.ShellTvFocus.currentNavTabId;

  @override
  FocusNode? get homeHeroPlay => tvfocus.ShellTvFocus.homeHeroPlay;

  @override
  set homeHeroPlay(FocusNode? node) => tvfocus.ShellTvFocus.homeHeroPlay = node;

  @override
  FocusNode? get homeHeroGallery => tvfocus.ShellTvFocus.homeHeroGallery;

  @override
  set homeHeroGallery(FocusNode? node) =>
      tvfocus.ShellTvFocus.homeHeroGallery = node;

  @override
  void focusHomeHeroPlay() => tvfocus.ShellTvFocus.focusHomeHeroPlay();

  @override
  void focusHomeHeroGallery() => tvfocus.ShellTvFocus.focusHomeHeroGallery();

  @override
  bool focusHomeMenu() => tvfocus.ShellTvFocus.focusHomeMenu();

  @override
  void focusHomeSearch() => tvfocus.ShellTvFocus.focusHomeSearch();

  @override
  void focusHubHeroSearch() => tvfocus.ShellTvFocus.focusHubHeroSearch();

  @override
  void registerHeroLastMiniDoor(FocusNode node) =>
      tvfocus.ShellTvFocus.registerHeroLastMiniDoor(node);

  @override
  void tryFocusMiniFromHeroLast() =>
      tvfocus.ShellTvFocus.tryFocusMiniFromHeroLast();

  @override
  bool focusActiveNavTab() =>
      tvcoord.ShellTvFocusCoordinator.focusActiveNavTab();

  @override
  bool focusRowItem(String tabId, String rowId, int index) =>
      tvcoord.ShellTvFocusCoordinator.focusRowItem(tabId, rowId, index);

  @override
  bool focusRowItemRemembered(String tabId, String rowId) =>
      tvcoord.ShellTvFocusCoordinator.focusRowItemRemembered(tabId, rowId);
}

class _PackLayoutHostBridge extends PackLayoutCapabilities {
  final _tv = _TvFocusBridge();

  @override
  PackLayoutTvFocus get tvFocus => _tv;

  @override
  Future<MetaEnvelope> metaRun({
    required String pluginId,
    required String action,
    Map<String, dynamic> params = const {},
    String? packSourceUrl,
    bool forceRefresh = false,
  }) =>
      meta.MetaRuntime.instance.run(
        pluginId: pluginId,
        action: action,
        params: params,
        packSourceUrl: packSourceUrl,
        forceRefresh: forceRefresh,
      );

  @override
  Future<MetaEnvelope> becauseMetaRun({
    required String pluginId,
    required String action,
    Map<String, dynamic> params = const {},
  }) =>
      metaRun(pluginId: pluginId, action: action, params: params);

  @override
  Future<PackPluginSnapshot?> findPlugin(
    String pluginId, {
    String? sourceUrl,
  }) async {
    final found = await preg.PluginRegistry.instance.findPlugin(
      pluginId,
      sourceUrl: sourceUrl,
    );
    if (found == null) return null;
    return _toSnapshot(found.pack, found.plugin);
  }

  @override
  Listenable get engineChangeListenable => engine.EngineService.changeNotifier;

  @override
  Future<void> waitUntilInstallIdle() =>
      install.PluginInstallCoordinator.instance.waitUntilIdle();

  @override
  String? pluginIdForTab(String tabId) =>
      pnav.PluginNavRegistry.pluginIdForTabSync(tabId);

  @override
  String? tabIdForPlugin(String pluginId) =>
      pnav.PluginNavRegistry.tabIdForPluginSync(pluginId);

  @override
  bool isKitTab(String tabId) => pnav.PluginNavRegistry.isKitTab(tabId);

  @override
  bool isCoreShell(String tabId) => pnav.PluginNavRegistry.isCoreShell(tabId);

  @override
  Future<String?> resolvePluginIdForTab(String tabId) =>
      pnav.PluginNavRegistry.pluginIdForTab(tabId);

  @override
  Listenable hubFeedEpochListenable(String pluginId) =>
      preg.PluginRegistry.hubFeedEpoch;

  @override
  Listenable get hubFeedEpoch => preg.PluginRegistry.hubFeedEpoch;

  @override
  bool hubFeedEpochTouches(String pluginId) =>
      preg.PluginRegistry.hubFeedEpochTouches(pluginId);

  @override
  void cancelLiveCatalog() => engine.EngineService.instance.cancelLiveCatalog();

  @override
  Future<void> openMetaItem(
    BuildContext context, {
    required String pluginId,
    required MetaItem item,
    int? initialSeason,
    int? initialEpisode,
  }) =>
      copen.openMetaItem(
        context,
        pluginId: pluginId,
        item: item,
        initialSeason: initialSeason,
        initialEpisode: initialEpisode,
      );

  @override
  PackLayoutMovie? metaItemToMovie(MetaItem item) {
    final m = mmovie.metaItemToMovie(item);
    return m == null ? null : _toPackMovie(m);
  }

  @override
  bool metaOpenUsesKitDetails(MetaOpen open) =>
      copen.metaOpenUsesKitDetails(open);

  @override
  bool hubMetaIsUpcoming(MetaItem item) => dmeta.hubMetaIsUpcoming(item);

  @override
  String? hubMetaTmdbMediaType(MetaItem item) =>
      dmeta.hubMetaTmdbMediaType(item);

  @override
  String? hubPosterTypeLabel(MetaItem item) =>
      mmovie.hubPosterTypeLabel(item);

  @override
  PackListFollowTarget? listFollowFromMeta({
    required String pluginId,
    required MetaItem meta,
  }) {
    final t = lfollow.ListFollowTarget.fromMeta(
      pluginId: pluginId,
      meta: meta,
    );
    return t == null ? null : _toPackFollow(t);
  }

  @override
  List<Map<String, dynamic>?> catalogChromeFilters({
    String? tabId,
    String? pluginId,
  }) =>
      chrome.catalogChromeFilters(tabId: tabId, pluginId: pluginId);

  @override
  String catalogChromeFilterEpoch(String? tabId) =>
      chrome.catalogChromeFilterEpoch(tabId);

  @override
  void verticalFiltersSyncFromLayout({
    required String tabId,
    required String pluginId,
    String? packSourceUrl,
    required List<Map<String, dynamic>> widgets,
  }) =>
      vfilters.VerticalFiltersRegistry.syncFromLayout(
        tabId: tabId,
        pluginId: pluginId,
        packSourceUrl: packSourceUrl,
        widgets: widgets,
      );

  @override
  void verticalFiltersClear(String tabId) =>
      vfilters.VerticalFiltersRegistry.unregister(tabId);

  @override
  Listenable get verticalFiltersRevision =>
      vfilters.VerticalFiltersRegistry.revision;

  @override
  Object? verticalFiltersSpecFor(String tabId) =>
      vfilters.VerticalFiltersRegistry.specFor(tabId);

  @override
  void topMenuSyncFromLayout({
    required String tabId,
    required List<Map<String, dynamic>> widgets,
    required Map<String, String> selections,
    required Map<String, Map<String, dynamic>> widgetSpecs,
    required void Function(String widgetId, String value, {required bool toggle})
        onSelect,
  }) {
    // Real registry lives in foundation now.
  }

  @override
  void topMenuNotifySelectionChanged(String tabId) {}

  @override
  void topMenuClear(String tabId) {}

  @override
  Listenable? topMenuListenable(String tabId) => null;

  @override
  Future<void> packFiltersEnsureLoaded(String pluginId) =>
      pfilters.PackFiltersRegistry.ensureLoaded(pluginId);

  @override
  Listenable? packFiltersListenable(String pluginId) =>
      pfilters.PackFiltersRegistry.revision;

  @override
  Listenable get packFiltersRevision => pfilters.PackFiltersRegistry.revision;

  @override
  void packFiltersInvalidate([String? pluginId]) =>
      pfilters.PackFiltersRegistry.invalidate(pluginId);

  @override
  List<ChromeMenuItem> packFiltersMenusFor(String pluginId) =>
      pfilters.PackFiltersRegistry.menusFor(pluginId);

  @override
  ChromeMenuItem? packFiltersMenuById(String pluginId, String? id) =>
      pfilters.PackFiltersRegistry.menuById(pluginId, id);

  @override
  List<({String id, String label})> packFiltersCategoriesFor(String pluginId) =>
      pfilters.PackFiltersRegistry.categoriesFor(pluginId);

  @override
  List<({String id, String label, String? logoUrl})> packFilterOptions(
    String pluginId,
  ) =>
      const [];

  @override
  String? packFilterSelected(String pluginId) => null;

  @override
  Future<void> packFilterSelect(String pluginId, String? id) async {}

  @override
  ValueNotifier<String?> get shellBusRequestTab => bus.ShellBus.requestTab;

  @override
  Listenable get shellBusHubRefresh => bus.ShellBus.splashDismissed;

  @override
  ValueNotifier<bool> get shellBusSplashDismissed =>
      bus.ShellBus.splashDismissed;

  @override
  ValueNotifier<double> hubScrollOffsetFor(String tabId) =>
      bus.ShellBus.hubScrollOffsetFor(tabId);

  @override
  ValueNotifier<double> hubHeroHeightFor(String tabId) =>
      bus.ShellBus.hubHeroHeightFor(tabId);

  @override
  ValueNotifier<String?> hubSelectedMenuIdFor(String tabId) =>
      bus.ShellBus.hubSelectedMenuIdFor(tabId);

  @override
  ValueNotifier<String?> hubSelectedCategoryIdFor(String tabId) =>
      bus.ShellBus.hubSelectedCategoryIdFor(tabId);

  @override
  void registerFindShortcutHandler(bool Function() handler) =>
      bus.ShellBus.registerFindShortcutHandler(handler);

  @override
  void unregisterFindShortcutHandler(bool Function() handler) =>
      bus.ShellBus.unregisterFindShortcutHandler(handler);

  @override
  void toastError(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
  }) =>
      toast.ForjaToast.error(
        message,
        actionLabel: actionLabel,
        onAction: onAction,
        duration: duration ?? const Duration(seconds: 4),
      );

  @override
  void toastSuccess(String message, {Duration? duration}) =>
      toast.ForjaToast.success(
        message,
        duration: duration ?? const Duration(seconds: 2),
      );

  @override
  Color get themeBgDark => theme.AppTheme.bgDark;

  @override
  Color get themeBgCard => theme.AppTheme.bgCard;

  @override
  PackShellInputPolicy inputPolicyOf(BuildContext context) {
    final p = sscope.ShellScope.inputPolicyOf(context);
    return PackShellInputPolicy(
      scaleOnHover: p.scaleOnHover,
      scaleOnFocus: p.scaleOnFocus,
      ensureVisibleOnFocus: p.ensureVisibleOnFocus,
      useFocusableMoodChips: p.useFocusableMoodChips,
      heroPlayAutoFocus: p.heroPlayAutoFocus,
      kenBurnsBackdrop: p.kenBurnsBackdrop,
    );
  }

  @override
  PackShellMetrics metricsOf(BuildContext context) {
    final m = sscope.ShellScope.metricsOf(context);
    return PackShellMetrics(
      usesTvDensity: m.usesTvDensity,
      heroCompactRightInset: m.heroCompactRightInset,
      heroMinTitleHeight: m.heroMinTitleHeight,
      heroActionUseFittedBox: m.heroActionUseFittedBox,
    );
  }

  @override
  PackShellProfile profileOf(BuildContext context) {
    final p = sscope.ShellScope.profileOf(context);
    return switch (p) {
      sprofile.ShellProfile.tv => PackShellProfile.tv,
      sprofile.ShellProfile.mobile => PackShellProfile.mobile,
      _ => PackShellProfile.desktop,
    };
  }

  @override
  bool shellDesktopTextSelect(BuildContext context) =>
      dtitle.shellDesktopTextSelect(context);

  @override
  bool shellUsesWideLayout(BuildContext context) =>
      slayout.shellUsesWideLayout(context);

  @override
  double shellPosterCardWidth(BuildContext context) =>
      slayout.shellPosterCardWidth(context);

  @override
  double shellPosterCardHeight(BuildContext context) =>
      slayout.shellPosterCardHeight(context);

  @override
  double shellContinueWatchingCardWidth(BuildContext context) =>
      slayout.shellContinueWatchingCardWidth(context);

  @override
  double shellContinueWatchingCardHeight(BuildContext context) =>
      slayout.shellContinueWatchingCardHeight(context);

  @override
  double shellHubCardTitleFontSize(BuildContext context) =>
      slayout.shellHubCardTitleFontSize(context);

  @override
  double shellScaled(BuildContext context, double value) =>
      slayout.shellScaled(context, value);

  @override
  double shellCardBorderRadius(BuildContext context) =>
      slayout.shellCardBorderRadius(context);

  @override
  double shellHeroHeightFraction(BuildContext context) =>
      slayout.shellHeroHeightFraction(context);

  @override
  double shellHeroMinHeight(BuildContext context) =>
      slayout.shellHeroMinHeight(context);

  @override
  double shellHeroNextRowPeekFraction(BuildContext context) =>
      slayout.shellHeroNextRowPeekFraction(context);

  @override
  double shellHomeRowSpacing(BuildContext context) =>
      slayout.shellHomeRowSpacing(context);

  @override
  double shellHomeSectionBottomGap(BuildContext context) =>
      slayout.shellHomeSectionBottomGap(context);

  @override
  double shellHomeSectionHeaderHeight(BuildContext context) =>
      slayout.shellHomeSectionHeaderHeight(context);

  @override
  double shellHomeSectionHorizontalPadding(BuildContext context) =>
      slayout.shellHomeSectionHorizontalPadding(context);

  @override
  EdgeInsetsGeometry shellHomeSectionTitlePadding(
    BuildContext context, {
    double? top,
    double? bottom,
  }) =>
      slayout.shellHomeSectionTitlePadding(context, top: top, bottom: bottom);

  @override
  double shellHomeSectionTitleTop(BuildContext context, {bool compact = false}) =>
      slayout.shellHomeSectionTitleTop(context, compact: compact);

  @override
  double shellSectionTitleTopCompact(BuildContext context) =>
      slayout.shellSectionTitleTopCompact(context);

  @override
  EdgeInsetsGeometry shellSectionTitlePadding(BuildContext context) =>
      slayout.shellSectionTitlePadding(context);

  @override
  double shellPosterCardRowGap(BuildContext context) =>
      slayout.shellPosterCardRowGap(context);

  @override
  double shellLayoutScale(BuildContext context) =>
      slayout.shellLayoutScale(context);

  @override
  double shellTvKitScrollBottomGap(BuildContext context) =>
      slayout.shellTvKitScrollBottomGap(context);

  @override
  bool shellTvIsNavigationKey(KeyEvent event) =>
      tvfocus.shellTvIsNavigationKey(event);

  @override
  bool mediaDetailsTvContainActive(BuildContext context) =>
      mdtv.MediaDetailsTv.tabId == tvfocus.ShellTvFocus.currentNavTabId;

  @override
  String get mediaDetailsTvHeroRowId => mdtv.MediaDetailsTv.heroRowId;

  @override
  String get mediaDetailsTvTabId => mdtv.MediaDetailsTv.tabId;

  @override
  Widget shellFocusableTap({
    required BuildContext context,
    required Widget child,
    VoidCallback? onTap,
    double? borderRadius,
    bool showFocusBorder = false,
    bool showFocusFill = true,
    bool suppressInkHover = false,
    double? scaleOnFocus,
    int? listIndex,
    VoidCallback? onLeftEdge,
    VoidCallback? onUpEdge,
    VoidCallback? onDownEdge,
    VoidCallback? onRightEdge,
    ValueChanged<bool>? onFocusChange,
    ValueChanged<bool>? onHoverChange,
    String? tvTabId,
    String? tvRowId,
    int? tvItemIndex,
    Object? tvZone,
    FocusNode? focusNode,
    bool autofocus = false,
    ShellPaintEnsureVisible ensureVisibleMode = ShellPaintEnsureVisible.row,
    VoidCallback? onFocusLeft,
    VoidCallback? onFocusRight,
    KeyEventResult Function(FocusNode, KeyEvent)? onKeyEvent,
  }) =>
      sfocus.shellFocusableTap(
        context: context,
        child: child,
        onTap: onTap,
        borderRadius: borderRadius ?? 12,
        showFocusBorder: showFocusBorder,
        showFocusFill: showFocusFill,
        suppressInkHover: suppressInkHover,
        scaleOnFocus: scaleOnFocus ?? 1.0,
        listIndex: listIndex,
        onLeftEdge: onLeftEdge ?? onFocusLeft,
        onUpEdge: onUpEdge,
        onDownEdge: onDownEdge,
        onRightEdge: onRightEdge ?? onFocusRight,
        onFocusChange: onFocusChange,
        onHoverChange: onHoverChange,
        tvTabId: tvTabId,
        tvRowId: tvRowId,
        tvItemIndex: tvItemIndex,
        ensureVisibleMode: ensureVisibleMode,
        tvZone: () {
          if (tvZone == null) return null;
          if (tvZone is tvcoord.ShellTvZone) return tvZone as tvcoord.ShellTvZone;
          if (tvZone is ShellTvZone) {
            return switch (tvZone as ShellTvZone) {
              ShellTvZone.nav => tvcoord.ShellTvZone.nav,
              ShellTvZone.hero => tvcoord.ShellTvZone.hero,
              ShellTvZone.topBar => tvcoord.ShellTvZone.topBar,
              ShellTvZone.chipStrip => tvcoord.ShellTvZone.chipStrip,
              ShellTvZone.row => tvcoord.ShellTvZone.row,
              ShellTvZone.grid => tvcoord.ShellTvZone.grid,
              ShellTvZone.settings => tvcoord.ShellTvZone.settings,
              ShellTvZone.chrome => tvcoord.ShellTvZone.row,
            };
          }
          final z = tvZone.toString();
          if (z.contains('topBar')) return tvcoord.ShellTvZone.topBar;
          if (z.contains('hero')) return tvcoord.ShellTvZone.hero;
          if (z.contains('chrome')) return tvcoord.ShellTvZone.row;
          return tvcoord.ShellTvZone.row;
        }(),
        focusNode: focusNode,
        autoFocus: autofocus,
        onKeyEvent: onKeyEvent,
      );

  @override
  Widget tvKitRow({
    Key? key,
    required String tabId,
    required String rowId,
    required int sortOrder,
    required int itemCount,
    VoidCallback? onFocusUp,
    ShellTvRowOrientation orientation = ShellTvRowOrientation.horizontal,
    required Widget child,
  }) =>
      tvgraph.TvKitRow(
        key: key,
        tabId: tabId.isEmpty ? null : tabId,
        rowId: rowId,
        sortOrder: sortOrder,
        itemCount: itemCount,
        onFocusUp: onFocusUp,
        orientation: orientation == ShellTvRowOrientation.vertical
            ? tvcoord.ShellTvRowOrientation.vertical
            : tvcoord.ShellTvRowOrientation.horizontal,
        child: child,
      );

  @override
  Widget playerSurfaceChrome({required Widget child}) =>
      pstub.PlayerSurfaceChromeStub(builder: (_) => child);

  @override
  Widget playerSurfaceChromeBuilder({required WidgetBuilder builder}) =>
      pstub.PlayerSurfaceChromeStub(builder: builder);

  @override
  Widget kitChromeTopBar({
    Key? key,
    required String tabId,
    required Widget child,
  }) =>
      child;

  @override
  Widget buildKitChromeTopBar({
    Key? key,
    required String tabId,
    required ValueNotifier<String?> selectedMenuId,
    required ValueNotifier<String?> selectedCategoryId,
    required List<ChromeMenuItem> menus,
    required List<({String id, String label})> categories,
    required ValueNotifier<double> scrollOffset,
    required ValueNotifier<double> heroHeight,
    required VoidCallback? onSearch,
  }) =>
      kchrome.KitChromeTopBar(
        key: key,
        tabId: tabId,
        selectedMenuId: selectedMenuId,
        selectedCategoryId: selectedCategoryId,
        menus: menus,
        categories: categories,
        scrollOffset: scrollOffset,
        heroHeight: heroHeight,
        onSearch: onSearch,
      );

  @override
  Widget? listStatusPinForMovie({
    required PackLayoutMovie movie,
    bool excludeFromTvTraversal = false,
    double? iconSize,
  }) =>
      klist.KitListStatusButton.movie(
        movie: _toRustMovie(movie),
        excludeFromTvTraversal: excludeFromTvTraversal,
        iconSize: iconSize,
      );

  @override
  Widget? listStatusPinForFollow({
    required PackListFollowTarget followTarget,
    bool excludeFromTvTraversal = false,
    double? iconSize,
  }) =>
      klist.KitListStatusButton.follow(
        followTarget: _toHostFollow(followTarget),
        excludeFromTvTraversal: excludeFromTvTraversal,
        iconSize: iconSize,
      );

  @override
  Widget heroListStatus({required PackListFollowTarget target}) =>
      khero.KitListStatusHero(target: _toHostFollow(target));

  @override
  Widget kitListStatusHero({
    required PackListFollowTarget target,
    String? tvTabId,
    int tvItemIndexStart = 0,
    VoidCallback? onUpEdge,
    VoidCallback? onRightEdge,
    bool enabled = true,
  }) =>
      khero.KitListStatusHero(
        target: _toHostFollow(target),
        tvTabId: tvTabId,
        tvItemIndexStart: tvItemIndexStart,
        onUpEdge: onUpEdge,
        enabled: enabled,
      );

  @override
  Widget buildBookmarkHeroStatusPill({
    required PackLayoutMovie movie,
    String? tvTabId,
    int tvItemIndexStart = 0,
    VoidCallback? onUpEdge,
    VoidCallback? onRightEdge,
    bool enabled = true,
  }) =>
      klist.BookmarkHeroStatusPill(
        movie: _toRustMovie(movie),
        tvTabId: tvTabId,
        tvItemIndexStart: tvItemIndexStart,
        onUpEdge: onUpEdge,
        onRightEdge: onRightEdge,
        enabled: enabled,
      );

  @override
  Widget heroPillPlayButton({
    required VoidCallback onPressed,
    String label = 'Play',
    FocusNode? focusNode,
    VoidCallback? onUpEdge,
    VoidCallback? onDownEdge,
    VoidCallback? onLeftEdge,
    VoidCallback? onRightEdge,
    String? tvTabId,
    String? tvRowId,
    int? tvItemIndex,
  }) =>
      hero.HeroPillPlayButton(
        label: label,
        onTap: onPressed,
        focusNode: focusNode,
        onUpEdge: onUpEdge,
        onRightEdge: onRightEdge,
        tvTabId: tvTabId,
        tvRowId: tvRowId,
        tvItemIndex: tvItemIndex,
      );

  @override
  Widget heroPillActionRow({required List<Widget> children}) =>
      hero.HeroPillActionRow(children: children);

  @override
  Future<void> openEntryDetails(
    BuildContext context, {
    required String pluginId,
    required MetaItem item,
  }) async {}

  @override
  Future<void> openKitEntryDetails(
    BuildContext context, {
    required Object entry,
    required String listSourceId,
    required List<Map<String, dynamic>> layoutWidgets,
    int refreshEpoch = 0,
    String? shellTabId,
  }) {
    if (entry is! KitListEntry) return Future.value();
    return kentry.KitEntryDetailsPage.open(
      context,
      entry: entry,
      listSourceId: listSourceId,
      layoutWidgets: layoutWidgets,
      refreshEpoch: refreshEpoch,
      shellTabId: shellTabId,
    );
  }

  @override
  void claimProvidersFocus() => ksrc.KitSourcesPanel.claimProvidersFocus();

  @override
  Widget? tvBrowseTextField({
    Key? key,
    required TextEditingController controller,
    required FocusNode browseFocusNode,
    required String hintText,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    GlobalKey? stateKey,
  }) =>
      null;

  @override
  Type get tvBrowseTextFieldStateType => tvfield.TvBrowseTextFieldState;

  @override
  Widget buildTvBrowseTextField({
    Key? key,
    required TextEditingController controller,
    required FocusNode focusNode,
    required ValueChanged<String> onChanged,
    required InputDecoration decoration,
    TextStyle? style,
    VoidCallback? onEscape,
    ValueChanged<String>? onSubmitted,
    KeyEventResult Function(FocusNode, KeyEvent)? onKeyEvent,
    String? browsePlaceholder,
    TextStyle? browseHintStyle,
    double? caretHeight,
  }) =>
      tvfield.TvBrowseTextField(
        key: key,
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        decoration: decoration,
        style: style,
        onEscape: onEscape,
        onSubmitted: onSubmitted,
        onKeyEvent: onKeyEvent,
        browsePlaceholder: browsePlaceholder,
        browseHintStyle: browseHintStyle,
        caretHeight: caretHeight,
      );

  @override
  Listenable get watchHistoryRevision => wh.WatchHistory.revision;

  @override
  Stream<List<Map<String, dynamic>>> homeHistoryStream() =>
      WatchHistoryService().historyStream;

  @override
  Future<List<Map<String, dynamic>>> catalogContinueEntries(
    String pluginId, {
    required bool mergeHomeWatchHistory,
  }) =>
      wh.catalogContinueEntries(
        pluginId,
        mergeHomeWatchHistory: mergeHomeWatchHistory,
      );

  @override
  bool isHomeWatchHistoryEntry(Map<String, dynamic> entry) =>
      wh.isHomeWatchHistoryEntry(entry);

  @override
  MetaItem? watchHistoryMetaFromEntry(Map<String, dynamic> entry) =>
      wh.WatchHistory.metaFromEntry(entry);

  @override
  Future<void> resumePlaybackFromHistory(
    BuildContext context,
    Map<String, dynamic> homeEntry,
  ) =>
      hpr.resumePlaybackFromHistory(context, homeEntry);

  @override
  bool canResumeFromSavedProgress(int posMs, int durMs) =>
      rust.canResumeFromSavedProgress(posMs, durMs);

  @override
  Future<void> runPlayFromContext({
    required BuildContext context,
    required Map<String, dynamic> playContext,
  }) async {
    final ctx = playContext['__playCtx'];
    if (ctx is PlayContext) {
      await kplay.runPlayFromContext(context: context, ctx: ctx);
    }
  }

  @override
  Map<String, dynamic> catalogPlayContextFromMeta({
    required MetaItem meta,
    required String pluginId,
    required int episodeNumber,
    String? episodeVideoId,
    Map<String, dynamic> extras = const {},
    Duration? startPosition,
  }) {
    final ctx = play.catalogPlayContextFromMeta(
      meta: meta,
      pluginId: pluginId,
      episodeNumber: episodeNumber,
      episodeVideoId: episodeVideoId,
      extras: extras,
      startPosition: startPosition,
    );
    return {'__playCtx': ctx};
  }

  @override
  Future<void> watchHistoryRemove(String pluginId, String metaId) =>
      wh.WatchHistory.remove(pluginId, metaId);

  @override
  Future<void> homeHistoryRemoveItem(String metaId) =>
      WatchHistoryService().removeItem(metaId);

  @override
  Future<void> openCatalogSearch(
    BuildContext context, {
    required String tabId,
    String? pluginId,
    String hintText = 'Search…',
  }) {
    final id = (pluginId ?? pnav.PluginNavRegistry.pluginIdForTabSync(tabId) ?? '')
        .trim();
    if (id.isEmpty) return Future.value();
    return catalog_search.openCatalogSearch(
      context,
      pluginId: id,
      tabId: tabId,
      hintText: hintText,
    );
  }

  @override
  Listenable get navbarChangeNotifier =>
      SettingsService.navbarChangeNotifier;

  @override
  void tvFocusClearTab(String tabId) =>
      tvcoord.ShellTvFocusCoordinator.clearTab(tabId);

  @override
  void tvFocusFirstContentRow(String tabId) =>
      tvcoord.ShellTvFocusCoordinator.focusFirstContentRow(tabId);

  @override
  FocusNode? tvItemNode(String tabId, String rowId, int index) =>
      tvcoord.ShellTvFocusCoordinator.itemNode(tabId, rowId, index);

  @override
  void tvOnRowItemFocused({
    required String tabId,
    required String rowId,
    required int index,
    FocusNode? node,
    Object? zone,
  }) {
    final n = node ??
        tvcoord.ShellTvFocusCoordinator.itemNode(tabId, rowId, index);
    if (n == null) return;
    tvcoord.ShellTvZone z = tvcoord.ShellTvZone.row;
    if (zone is tvcoord.ShellTvZone) {
      z = zone;
    } else if (zone is ShellTvZone) {
      z = switch (zone) {
        ShellTvZone.nav => tvcoord.ShellTvZone.nav,
        ShellTvZone.hero => tvcoord.ShellTvZone.hero,
        ShellTvZone.topBar => tvcoord.ShellTvZone.topBar,
        ShellTvZone.chipStrip => tvcoord.ShellTvZone.chipStrip,
        ShellTvZone.row => tvcoord.ShellTvZone.row,
        ShellTvZone.grid => tvcoord.ShellTvZone.grid,
        ShellTvZone.settings => tvcoord.ShellTvZone.settings,
        ShellTvZone.chrome => tvcoord.ShellTvZone.row,
      };
    }
    tvcoord.ShellTvFocusCoordinator.onRowItemFocused(
      tabId: tabId,
      rowId: rowId,
      index: index,
      node: n,
      zone: z,
    );
  }

  @override
  void tvRegisterItemNode({
    required String tabId,
    required String rowId,
    required int index,
    required FocusNode node,
  }) =>
      tvcoord.ShellTvFocusCoordinator.registerItemNode(
        tabId: tabId,
        rowId: rowId,
        index: index,
        node: node,
      );

  @override
  void tvUnregisterItemNode({
    required String tabId,
    required String rowId,
    required int index,
    required FocusNode node,
  }) =>
      tvcoord.ShellTvFocusCoordinator.unregisterItemNode(
        tabId: tabId,
        rowId: rowId,
        index: index,
        node: node,
      );

  @override
  void tvRevealHeroForTab(String tabId) =>
      tvcoord.ShellTvFocusCoordinator.revealHeroForTab(tabId);

  @override
  PackShellTvRowHandle? tvRowHandle(String tabId, String rowId) {
    final h = tvcoord.ShellTvFocusCoordinator.rowHandle(tabId, rowId);
    if (h == null) return null;
    return PackShellTvRowHandle(
      itemCount: h.itemCount,
      lastFocusedIndex: h.lastFocusedIndex,
    );
  }

  @override
  void tvSetRowScrollIntoView(
    String tabId,
    String rowId,
    void Function(int index)? scrollIntoView,
  ) =>
      tvcoord.ShellTvFocusCoordinator.setRowScrollIntoView(
        tabId,
        rowId,
        scrollIntoView,
      );

  @override
  Future<bool> isKitPluginEnabled(
    String pluginId, {
    String? packSourceUrl,
  }) =>
      pnav.PluginNavRegistry.isKitPluginEnabled(
        pluginId,
        packSourceUrl: packSourceUrl,
      );

  @override
  Future<String?> packSourceUrlForTab(String tabId) =>
      pnav.PluginNavRegistry.packSourceUrlForTab(tabId);

  @override
  Listenable catalogChromeFilterListenable(String? tabId) =>
      chrome.catalogChromeFilterListenable(tabId) ??
      ValueNotifier<int>(0);

  @override
  bool catalogChromeHidesTypeFilterRails({
    String? tabId,
    String? pluginId,
  }) =>
      chrome.catalogChromeHidesTypeFilterRails(tabId);

  @override
  String? hubMetaPremiereDateLabel(MetaItem item) =>
      dmeta.hubMetaPremiereDateLabel(item);

  @override
  String? kitPosterSubtitle(MetaItem item) =>
      mmovie.kitPosterSubtitle(item);

  @override
  String? kitPosterBadge(MetaItem item, {String? pluginId}) =>
      mmovie.kitPosterBadge(item, pluginId: pluginId);

  @override
  Widget tvFocusGraph({
    required String tabId,
    required Widget child,
  }) =>
      tvgraph.TvFocusGraph(tabId: tabId, child: child);

  @override
  Widget tvChipStrip({
    required String tabId,
    required String rowId,
    required int sortOrder,
    required int itemCount,
    required String resultsRowId,
    VoidCallback? onFocusLeft,
    VoidCallback? onFocusRight,
    required Widget Function(BuildContext context, dynamic edgesFor) builder,
  }) =>
      tvgraph.TvChipStrip(
        tabId: tabId,
        rowId: rowId,
        sortOrder: sortOrder,
        itemCount: itemCount,
        resultsRowId: resultsRowId,
        onFocusLeft: onFocusLeft,
        onFocusRight: onFocusRight,
        builder: (context, edgesFor) => builder(context, edgesFor),
      );

  @override
  Widget tvGrid({
    Key? key,
    String? tabId,
    required String rowId,
    required int sortOrder,
    required int itemCount,
    required int columns,
    VoidCallback? onFocusUp,
    VoidCallback? onFocusDown,
    required Widget child,
  }) =>
      tvgraph.TvGrid(
        key: key,
        tabId: tabId,
        rowId: rowId,
        sortOrder: sortOrder,
        itemCount: itemCount,
        columns: columns,
        onFocusUp: onFocusUp,
        onFocusDown: onFocusDown,
        child: child,
      );

  @override
  void tvHeroActionsBind(
    String tabId, {
    FocusNode? Function()? defaultFocus,
    VoidCallback? heroReveal,
    VoidCallback? enterFromNavFocus,
    bool Function()? restoreFocus,
    bool Function()? pageBack,
    bool preferCustomRestoreFromNav = false,
  }) =>
      tvgraph.TvHeroActions.bind(
        tabId,
        defaultFocus: defaultFocus,
        heroReveal: heroReveal,
        enterFromNavFocus: enterFromNavFocus,
        restoreFocus: restoreFocus,
        pageBack: pageBack,
        preferCustomRestoreFromNav: preferCustomRestoreFromNav,
      );

  @override
  void tvHeroActionsUnbind(String tabId) => tvgraph.TvHeroActions.unbind(tabId);

  @override
  Widget detailsHeroTvActionScope({
    Key? key,
    required String tabId,
    required int itemCount,
    VoidCallback? onFocusUp,
    VoidCallback? onFocusDown,
    required Widget child,
  }) =>
      kplayrow.DetailsHeroTvActionScope(
        key: key,
        tabId: tabId,
        itemCount: itemCount,
        onFocusUp: onFocusUp,
        onFocusDown: onFocusDown,
        child: child,
      );

  @override
  Widget kitDetailsUpcomingNotice({
    Key? key,
    String? releaseDateLabel,
  }) =>
      kplayrow.KitDetailsUpcomingNotice(
        key: key,
        releaseDateLabel: releaseDateLabel,
      );

  @override
  Future<List<Map<String, dynamic>>> catalogResumeSeeds(String pluginId) =>
      wh.catalogResumeSeeds(pluginId);

  @override
  VoidCallback tvResultsUpToChips(
    BuildContext context, {
    String chipRowId = 'mood-chips',
  }) =>
      tvgraph.tvResultsUpToChips(context, chipRowId: chipRowId);

  @override
  Map<String, dynamic> get navDestinations =>
      Map<String, dynamic>.from(pnav.PluginNavRegistry.destinations);

  @override
  Object get addonRevisionProvider => srev.addonRevisionProvider;
}
