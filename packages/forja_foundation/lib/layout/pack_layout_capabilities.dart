/// Host bridges for [PackLayoutHost] — foundation must not import `package:forja/`.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja_foundation/layout/chrome_menu_item.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
export 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart' show ShellPaintEnsureVisible;

/// Catalog poster / hero movie fields (opaque stand-in for host `Movie`).
class PackLayoutMovie {
  const PackLayoutMovie({
    required this.id,
    required this.title,
    required this.posterPath,
    required this.backdropPath,
    this.logoPath = '',
    required this.voteAverage,
    required this.releaseDate,
    this.overview = '',
    this.genres = const [],
    this.mediaType = 'movie',
  });

  final int id;
  final String title;
  final String posterPath;
  final String backdropPath;
  final String logoPath;
  final double voteAverage;
  final String releaseDate;
  final String overview;
  final List<String> genres;
  final String mediaType;
}

/// Opaque hub plugin snapshot for layout (config page size, capabilities).
class PackPluginSnapshot {
  const PackPluginSnapshot({
    required this.id,
    required this.config,
    this.sourceUrl,
    this.capabilities = const [],
  });

  final String id;
  final Map<String, dynamic> config;
  final String? sourceUrl;
  final List<String> capabilities;

  bool hasCapability(String key) => capabilities.contains(key);
}

/// List-follow pin target (opaque stand-in for host `ListFollowTarget`).
class PackListFollowTarget {
  const PackListFollowTarget({
    required this.pluginId,
    required this.open,
    required this.title,
    required this.posterPath,
    this.voteAverage = 0,
    this.releaseDate = '',
    this.tmdbId,
    this.tmdbMediaType,
    this.mediaType,
  });

  final String pluginId;
  final MetaOpen open;
  final String title;
  final String posterPath;
  final double voteAverage;
  final String releaseDate;
  final int? tmdbId;
  final String? tmdbMediaType;
  final String? mediaType;
}

/// Shell input policy bits PackLayoutHost needs.
class PackShellInputPolicy {
  const PackShellInputPolicy({
    required this.scaleOnHover,
    required this.scaleOnFocus,
    required this.ensureVisibleOnFocus,
    required this.useFocusableMoodChips,
    required this.heroPlayAutoFocus,
    required this.kenBurnsBackdrop,
  });

  final bool scaleOnHover;
  final bool scaleOnFocus;
  final bool ensureVisibleOnFocus;
  final bool useFocusableMoodChips;
  final bool heroPlayAutoFocus;
  final bool kenBurnsBackdrop;

  /// Policy-aware hover OR keyboard focus chrome.
  static bool interactiveActive(
    PackShellInputPolicy policy, {
    required bool hovered,
    required bool focused,
    BuildContext? context,
  }) {
    final focusChrome = policy.scaleOnFocus && focused;
    return (policy.scaleOnHover && hovered) || focusChrome;
  }
}

/// Shell metrics bits PackLayoutHost needs.
class PackShellMetrics {
  const PackShellMetrics({
    required this.usesTvDensity,
    this.heroCompactRightInset = 20,
    this.heroMinTitleHeight = 72,
    this.heroActionUseFittedBox = false,
  });

  final bool usesTvDensity;
  final double heroCompactRightInset;
  final double heroMinTitleHeight;
  final bool heroActionUseFittedBox;
}

/// Opaque TV row handle (itemCount / lastFocusedIndex).
class PackShellTvRowHandle {
  PackShellTvRowHandle({
    required this.itemCount,
    required this.lastFocusedIndex,
  });

  int itemCount;
  int lastFocusedIndex;
}

enum PackShellProfile { desktop, mobile, tv }

enum ShellTvRowOrientation { horizontal, vertical }

enum ShellTvZone { nav, hero, topBar, chipStrip, row, grid, settings, chrome }

/// TV focus registry surface used by layout composers.
abstract class PackLayoutTvFocus {
  String? get currentNavTabId;
  FocusNode? get homeHeroPlay;
  set homeHeroPlay(FocusNode? node);
  FocusNode? get homeHeroGallery;
  set homeHeroGallery(FocusNode? node);

  void focusHomeHeroPlay();
  void focusHomeHeroGallery();
  bool focusHomeMenu();
  void focusHomeSearch();
  void focusHubHeroSearch();
  void registerHeroLastMiniDoor(FocusNode node);
  void tryFocusMiniFromHeroLast();
  bool focusActiveNavTab();
  bool focusRowItem(String tabId, String rowId, int index);
  bool focusRowItemRemembered(String tabId, String rowId);
}

/// Bound once at app boot before any [PackLayoutHost] mounts.
abstract class PackLayoutCapabilities {
  static PackLayoutCapabilities? _instance;

  static PackLayoutCapabilities get instance {
    final i = _instance;
    if (i == null) {
      throw StateError('PackLayoutCapabilities.bind() required before mount');
    }
    return i;
  }

  static void bind(PackLayoutCapabilities caps) => _instance = caps;

  static void unbind() => _instance = null;

  // --- Meta / packs ---
  Future<MetaEnvelope> metaRun({
    required String pluginId,
    required String action,
    Map<String, dynamic> params = const {},
    String? packSourceUrl,
    bool forceRefresh = false,
  });

  Future<PackPluginSnapshot?> findPlugin(
    String pluginId, {
    String? sourceUrl,
  });

  Listenable get engineChangeListenable;

  Future<void> waitUntilInstallIdle();

  String? pluginIdForTab(String tabId);

  String? tabIdForPlugin(String pluginId);

  bool isKitTab(String tabId);

  bool isCoreShell(String tabId);

  Future<String?> resolvePluginIdForTab(String tabId);

  Listenable hubFeedEpochListenable(String pluginId);

  // --- Open / details meta ---
  Future<void> openMetaItem(
    BuildContext context, {
    required String pluginId,
    required MetaItem item,
    int? initialSeason,
    int? initialEpisode,
  });

  PackLayoutMovie? metaItemToMovie(MetaItem item);

  bool metaOpenUsesKitDetails(MetaOpen open);

  bool hubMetaIsUpcoming(MetaItem item);

  String? hubMetaTmdbMediaType(MetaItem item);

  String? hubPosterTypeLabel(MetaItem item);

  PackListFollowTarget? listFollowFromMeta({
    required String pluginId,
    required MetaItem meta,
  });

  // --- Chrome filters / menus ---
  List<Map<String, dynamic>?> catalogChromeFilters({
    String? tabId,
    String? pluginId,
  });

  String catalogChromeFilterEpoch(String? tabId);

  void verticalFiltersSyncFromLayout({
    required String tabId,
    required String pluginId,
    String? packSourceUrl,
    required List<Map<String, dynamic>> widgets,
  });

  void verticalFiltersClear(String tabId);

  void topMenuSyncFromLayout({
    required String tabId,
    required List<Map<String, dynamic>> widgets,
    required Map<String, String> selections,
    required Map<String, Map<String, dynamic>> widgetSpecs,
    required void Function(String widgetId, String value, {required bool toggle})
        onSelect,
  });

  void topMenuNotifySelectionChanged(String tabId);

  void topMenuClear(String tabId);

  Listenable? topMenuListenable(String tabId);

  Future<void> packFiltersEnsureLoaded(String pluginId);

  Listenable? packFiltersListenable(String pluginId);

  List<({String id, String label, String? logoUrl})> packFilterOptions(
    String pluginId,
  );

  String? packFilterSelected(String pluginId);

  Future<void> packFilterSelect(String pluginId, String? id);

  // --- Shell bus / toast / theme ---
  ValueNotifier<String?> get shellBusRequestTab;

  Listenable get shellBusHubRefresh;

  void toastError(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
  });

  void toastSuccess(String message, {Duration? duration});

  Color get themeBgDark;

  Color get themeBgCard;

  // --- Shell scope / layout dims ---
  PackShellInputPolicy inputPolicyOf(BuildContext context);

  PackShellMetrics metricsOf(BuildContext context);

  PackShellProfile profileOf(BuildContext context);

  bool shellDesktopTextSelect(BuildContext context);

  bool shellUsesWideLayout(BuildContext context);

  double shellPosterCardWidth(BuildContext context);

  double shellPosterCardHeight(BuildContext context);

  double shellContinueWatchingCardWidth(BuildContext context);

  double shellContinueWatchingCardHeight(BuildContext context);

  double shellHubCardTitleFontSize(BuildContext context);

  double shellScaled(BuildContext context, double value);

  double shellCardBorderRadius(BuildContext context);

  double shellHeroHeightFraction(BuildContext context);

  double shellHeroMinHeight(BuildContext context);

  double shellHeroNextRowPeekFraction(BuildContext context);

  double shellHomeRowSpacing(BuildContext context);

  double shellHomeSectionBottomGap(BuildContext context);

  double shellHomeSectionHeaderHeight(BuildContext context);

  double shellHomeSectionHorizontalPadding(BuildContext context);

  EdgeInsetsGeometry shellHomeSectionTitlePadding(
    BuildContext context, {
    double? top,
    double? bottom,
  });

  double shellHomeSectionTitleTop(BuildContext context, {bool compact = false});

  double shellSectionTitleTopCompact(BuildContext context);

  EdgeInsetsGeometry shellSectionTitlePadding(BuildContext context);

  double shellPosterCardRowGap(BuildContext context);

  double shellLayoutScale(BuildContext context);

  double shellTvKitScrollBottomGap(BuildContext context);

  bool shellTvIsNavigationKey(KeyEvent event);

  // --- TV focus ---
  PackLayoutTvFocus get tvFocus;

  bool mediaDetailsTvContainActive(BuildContext context);

  String get mediaDetailsTvHeroRowId;

  String get mediaDetailsTvTabId;

  // --- Focus / wrap widgets ---
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
  });

  Future<MetaEnvelope> becauseMetaRun({
      required String pluginId,
      required String action,
      Map<String, dynamic> params = const {},
    });

  Listenable get hubFeedEpoch;

  bool hubFeedEpochTouches(String pluginId);

  void cancelLiveCatalog();

  Listenable get verticalFiltersRevision;

  Object? verticalFiltersSpecFor(String tabId);

  Listenable get packFiltersRevision;

  void packFiltersInvalidate([String? pluginId]);

  List<ChromeMenuItem> packFiltersMenusFor(String pluginId);

  ChromeMenuItem? packFiltersMenuById(String pluginId, String? id);

  List<({String id, String label})> packFiltersCategoriesFor(String pluginId);

  ValueNotifier<bool> get shellBusSplashDismissed;

  ValueNotifier<double> hubScrollOffsetFor(String tabId);

  ValueNotifier<double> hubHeroHeightFor(String tabId);

  ValueNotifier<String?> hubSelectedMenuIdFor(String tabId);

  ValueNotifier<String?> hubSelectedCategoryIdFor(String tabId);

  void registerFindShortcutHandler(bool Function() handler);

  void unregisterFindShortcutHandler(bool Function() handler);

  Widget tvKitRow({
      Key? key,
      required String tabId,
      required String rowId,
      required int sortOrder,
      required int itemCount,
      VoidCallback? onFocusUp,
      ShellTvRowOrientation orientation = ShellTvRowOrientation.horizontal,
      required Widget child,
    });

  Widget playerSurfaceChrome({required Widget child});

  Widget playerSurfaceChromeBuilder({required WidgetBuilder builder});

  Widget kitChromeTopBar({
      Key? key,
      required String tabId,
      required Widget child,
    });

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
    });

  Widget? listStatusPinForMovie({
      required PackLayoutMovie movie,
      bool excludeFromTvTraversal = false,
      double? iconSize,
    });

  Widget? listStatusPinForFollow({
      required PackListFollowTarget followTarget,
      bool excludeFromTvTraversal = false,
      double? iconSize,
    });

  Widget heroListStatus({required PackListFollowTarget target});

  Widget kitListStatusHero({
      required PackListFollowTarget target,
      String? tvTabId,
      int tvItemIndexStart = 0,
      VoidCallback? onUpEdge,
      VoidCallback? onRightEdge,
      bool enabled = true,
    });

  Widget buildBookmarkHeroStatusPill({
      required PackLayoutMovie movie,
      String? tvTabId,
      int tvItemIndexStart = 0,
      VoidCallback? onUpEdge,
      VoidCallback? onRightEdge,
      bool enabled = true,
    });

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
    });

  Widget heroPillActionRow({required List<Widget> children});

  Future<void> openEntryDetails(
      BuildContext context, {
      required String pluginId,
      required MetaItem item,
    });

  Future<void> openKitEntryDetails(
      BuildContext context, {
      required Object entry,
      required String listSourceId,
      required List<Map<String, dynamic>> layoutWidgets,
      int refreshEpoch = 0,
      String? shellTabId,
    });

  void claimProvidersFocus();

  Widget? tvBrowseTextField({
      Key? key,
      required TextEditingController controller,
      required FocusNode browseFocusNode,
      required String hintText,
      ValueChanged<String>? onChanged,
      ValueChanged<String>? onSubmitted,
      GlobalKey? stateKey,
    });

  Type get tvBrowseTextFieldStateType;

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
    });

  Listenable get watchHistoryRevision;

  Stream<List<Map<String, dynamic>>> homeHistoryStream();

  Future<List<Map<String, dynamic>>> catalogContinueEntries(
      String pluginId, {
      required bool mergeHomeWatchHistory,
    });

  bool isHomeWatchHistoryEntry(Map<String, dynamic> entry);

  MetaItem? watchHistoryMetaFromEntry(Map<String, dynamic> entry);

  Future<void> resumePlaybackFromHistory(
      BuildContext context,
      Map<String, dynamic> homeEntry,
    );

  bool canResumeFromSavedProgress(int posMs, int durMs);

  Future<void> runPlayFromContext({
      required BuildContext context,
      required Map<String, dynamic> playContext,
    });

  Map<String, dynamic> catalogPlayContextFromMeta({
      required MetaItem meta,
      required String pluginId,
      required int episodeNumber,
      String? episodeVideoId,
      Map<String, dynamic> extras = const {},
      Duration? startPosition,
    });

  Future<void> watchHistoryRemove(String pluginId, String metaId);

  Future<void> homeHistoryRemoveItem(String metaId);

  Future<void> openCatalogSearch(
      BuildContext context, {
      required String tabId,
      String? pluginId,
      String hintText = 'Search…',
    });

  Listenable get navbarChangeNotifier;

  void tvFocusClearTab(String tabId);

  void tvFocusFirstContentRow(String tabId);

  FocusNode? tvItemNode(String tabId, String rowId, int index);

  void tvOnRowItemFocused({
      required String tabId,
      required String rowId,
      required int index,
      FocusNode? node,
      Object? zone,
    });

  void tvRegisterItemNode({
      required String tabId,
      required String rowId,
      required int index,
      required FocusNode node,
    });

  void tvUnregisterItemNode({
      required String tabId,
      required String rowId,
      required int index,
      required FocusNode node,
    });

  void tvRevealHeroForTab(String tabId);

  PackShellTvRowHandle? tvRowHandle(String tabId, String rowId);

  void tvSetRowScrollIntoView(
      String tabId,
      String rowId,
      void Function(int index)? scrollIntoView,
    );

  Future<bool> isKitPluginEnabled(
      String pluginId, {
      String? packSourceUrl,
    });

  Future<String?> packSourceUrlForTab(String tabId);

  Listenable catalogChromeFilterListenable(String? tabId);

  bool catalogChromeHidesTypeFilterRails({
      String? tabId,
      String? pluginId,
    });

  String? hubMetaPremiereDateLabel(MetaItem item);

  String? kitPosterSubtitle(MetaItem item);

  String? kitPosterBadge(MetaItem item, {String? pluginId});

  Widget tvFocusGraph({
      required String tabId,
      required Widget child,
    });

  Widget tvChipStrip({
      required String tabId,
      required String rowId,
      required int sortOrder,
      required int itemCount,
      required String resultsRowId,
      VoidCallback? onFocusLeft,
      VoidCallback? onFocusRight,
      required Widget Function(BuildContext context, dynamic edgesFor) builder,
    });

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
  });

  void tvHeroActionsBind(
    String tabId, {
    FocusNode? Function()? defaultFocus,
    VoidCallback? heroReveal,
    VoidCallback? enterFromNavFocus,
    bool Function()? restoreFocus,
    bool Function()? pageBack,
    bool preferCustomRestoreFromNav = false,
  });

  void tvHeroActionsUnbind(String tabId);

  Widget detailsHeroTvActionScope({
    Key? key,
    required String tabId,
    required int itemCount,
    VoidCallback? onFocusUp,
    VoidCallback? onFocusDown,
    required Widget child,
  });

  Widget kitDetailsUpcomingNotice({
    Key? key,
    String? releaseDateLabel,
  });

  Future<List<Map<String, dynamic>>> catalogResumeSeeds(String pluginId);

  VoidCallback tvResultsUpToChips(
      BuildContext context, {
      String chipRowId = 'mood-chips',
    });

  Map<String, dynamic> get navDestinations;

  Object get addonRevisionProvider;
}

PackLayoutCapabilities get packCaps => PackLayoutCapabilities.instance;

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
    packCaps.shellFocusableTap(
      context: context,
      child: child,
      onTap: onTap,
      borderRadius: borderRadius,
      showFocusBorder: showFocusBorder,
      showFocusFill: showFocusFill,
      suppressInkHover: suppressInkHover,
      scaleOnFocus: scaleOnFocus,
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
      tvZone: tvZone,
      focusNode: focusNode,
      autofocus: autofocus,
      ensureVisibleMode: ensureVisibleMode,
      onFocusLeft: onFocusLeft,
      onFocusRight: onFocusRight,
      onKeyEvent: onKeyEvent,
    );

bool shellDesktopTextSelect(BuildContext context) =>
    packCaps.shellDesktopTextSelect(context);

bool shellUsesWideLayout(BuildContext context) =>
    packCaps.shellUsesWideLayout(context);

double shellPosterCardWidth(BuildContext context) =>
    packCaps.shellPosterCardWidth(context);

double shellPosterCardHeight(BuildContext context) =>
    packCaps.shellPosterCardHeight(context);

double shellContinueWatchingCardWidth(BuildContext context) =>
    packCaps.shellContinueWatchingCardWidth(context);

double shellContinueWatchingCardHeight(BuildContext context) =>
    packCaps.shellContinueWatchingCardHeight(context);

double shellHubCardTitleFontSize(BuildContext context) =>
    packCaps.shellHubCardTitleFontSize(context);

double shellScaled(BuildContext context, double value) =>
    packCaps.shellScaled(context, value);

double shellCardBorderRadius(BuildContext context) =>
    packCaps.shellCardBorderRadius(context);

double shellHeroHeightFraction(BuildContext context) =>
    packCaps.shellHeroHeightFraction(context);

double shellHeroMinHeight(BuildContext context) =>
    packCaps.shellHeroMinHeight(context);

double shellHeroNextRowPeekFraction(BuildContext context) =>
    packCaps.shellHeroNextRowPeekFraction(context);

double shellHomeRowSpacing(BuildContext context) =>
    packCaps.shellHomeRowSpacing(context);

double shellHomeSectionBottomGap(BuildContext context) =>
    packCaps.shellHomeSectionBottomGap(context);

double shellHomeSectionHeaderHeight(BuildContext context) =>
    packCaps.shellHomeSectionHeaderHeight(context);

double shellHomeSectionHorizontalPadding(BuildContext context) =>
    packCaps.shellHomeSectionHorizontalPadding(context);

EdgeInsetsGeometry shellHomeSectionTitlePadding(
  BuildContext context, {
  double? top,
  double? bottom,
}) =>
    packCaps.shellHomeSectionTitlePadding(context, top: top, bottom: bottom);

double shellHomeSectionTitleTop(BuildContext context, {bool compact = false}) =>
    packCaps.shellHomeSectionTitleTop(context, compact: compact);

double shellSectionTitleTopCompact(BuildContext context) =>
    packCaps.shellSectionTitleTopCompact(context);

EdgeInsetsGeometry shellSectionTitlePadding(BuildContext context) =>
    packCaps.shellSectionTitlePadding(context);

double shellPosterCardRowGap(BuildContext context) =>
    packCaps.shellPosterCardRowGap(context);

double shellLayoutScale(BuildContext context) =>
    packCaps.shellLayoutScale(context);

double shellTvKitScrollBottomGap(BuildContext context) =>
    packCaps.shellTvKitScrollBottomGap(context);

bool shellTvIsNavigationKey(KeyEvent event) =>
    packCaps.shellTvIsNavigationKey(event);


/// Facade matching former host [ShellScope] call sites.
abstract final class ShellScope {
  static PackShellInputPolicy inputPolicyOf(BuildContext context) =>
      packCaps.inputPolicyOf(context);

  static PackShellMetrics metricsOf(BuildContext context) =>
      packCaps.metricsOf(context);

  static PackShellProfile profileOf(BuildContext context) =>
      packCaps.profileOf(context);
}

typedef ShellProfile = PackShellProfile;
typedef ShellInputPolicy = PackShellInputPolicy;

/// Facade matching former host [ShellTvFocus] / coordinator call sites.
abstract final class ShellTvFocus {
  static String? get currentNavTabId => packCaps.tvFocus.currentNavTabId;

  static FocusNode? get homeHeroPlay => packCaps.tvFocus.homeHeroPlay;

  static set homeHeroPlay(FocusNode? n) => packCaps.tvFocus.homeHeroPlay = n;

  static FocusNode? get homeHeroGallery => packCaps.tvFocus.homeHeroGallery;

  static set homeHeroGallery(FocusNode? n) =>
      packCaps.tvFocus.homeHeroGallery = n;

  static void focusHomeHeroPlay() => packCaps.tvFocus.focusHomeHeroPlay();

  static void focusHomeHeroGallery() => packCaps.tvFocus.focusHomeHeroGallery();

  static bool focusHomeMenu() => packCaps.tvFocus.focusHomeMenu();

  static void focusHomeSearch() => packCaps.tvFocus.focusHomeSearch();

  static void focusHubHeroSearch() => packCaps.tvFocus.focusHubHeroSearch();

  static void registerHeroLastMiniDoor(FocusNode node) =>
      packCaps.tvFocus.registerHeroLastMiniDoor(node);

  static void tryFocusMiniFromHeroLast() =>
      packCaps.tvFocus.tryFocusMiniFromHeroLast();
}

abstract final class ShellTvFocusCoordinator {
  static bool focusActiveNavTab() => packCaps.tvFocus.focusActiveNavTab();

  static bool focusRowItem(String tabId, String rowId, int index) =>
      packCaps.tvFocus.focusRowItem(tabId, rowId, index);

  static bool focusRowItemRemembered(String tabId, String rowId) =>
      packCaps.tvFocus.focusRowItemRemembered(tabId, rowId);

  static void clearTab(String tabId) => packCaps.tvFocusClearTab(tabId);

  static void focusFirstContentRow(String tabId) =>
      packCaps.tvFocusFirstContentRow(tabId);

  static FocusNode? itemNode(String tabId, String rowId, int index) =>
      packCaps.tvItemNode(tabId, rowId, index);

  static void onRowItemFocused({
    required String tabId,
    required String rowId,
    required int index,
    FocusNode? node,
    Object? zone,
  }) =>
      packCaps.tvOnRowItemFocused(
        tabId: tabId,
        rowId: rowId,
        index: index,
        node: node,
        zone: zone,
      );

  static void registerItemNode({
    required String tabId,
    required String rowId,
    required int index,
    required FocusNode node,
  }) =>
      packCaps.tvRegisterItemNode(
        tabId: tabId,
        rowId: rowId,
        index: index,
        node: node,
      );

  static void unregisterItemNode({
    required String tabId,
    required String rowId,
    required int index,
    required FocusNode node,
  }) =>
      packCaps.tvUnregisterItemNode(
        tabId: tabId,
        rowId: rowId,
        index: index,
        node: node,
      );

  static void revealHeroForTab(String tabId) =>
      packCaps.tvRevealHeroForTab(tabId);

  static PackShellTvRowHandle? rowHandle(String tabId, String rowId) =>
      packCaps.tvRowHandle(tabId, rowId);

  static void setRowScrollIntoView(
    String tabId,
    String rowId,
    void Function(int index)? scrollIntoView,
  ) =>
      packCaps.tvSetRowScrollIntoView(tabId, rowId, scrollIntoView);
}

abstract final class ShellBus {
  static ValueNotifier<String?> get requestTab => packCaps.shellBusRequestTab;

  static Listenable get hubRefresh => packCaps.shellBusHubRefresh;

  static ValueNotifier<bool> get splashDismissed => packCaps.shellBusSplashDismissed;

  static ValueNotifier<double> hubScrollOffsetFor(String tabId) =>
      packCaps.hubScrollOffsetFor(tabId);

  static ValueNotifier<double> hubHeroHeightFor(String tabId) =>
      packCaps.hubHeroHeightFor(tabId);

  static ValueNotifier<String?> hubSelectedMenuIdFor(String tabId) =>
      packCaps.hubSelectedMenuIdFor(tabId);

  static ValueNotifier<String?> hubSelectedCategoryIdFor(String tabId) =>
      packCaps.hubSelectedCategoryIdFor(tabId);

  static void registerFindShortcutHandler(bool Function() handler) =>
      packCaps.registerFindShortcutHandler(handler);

  static void unregisterFindShortcutHandler(bool Function() handler) =>
      packCaps.unregisterFindShortcutHandler(handler);
}

abstract final class ForjaToast {
  static void error(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
  }) =>
      packCaps.toastError(
        message,
        actionLabel: actionLabel,
        onAction: onAction,
        duration: duration,
      );

  static void success(String message, {Duration? duration}) =>
      packCaps.toastSuccess(message, duration: duration);
}

abstract final class AppTheme {
  static Color get bgDark => packCaps.themeBgDark;

  static Color get bgCard => packCaps.themeBgCard;
}

abstract final class MediaDetailsTv {
  static String get heroRowId => packCaps.mediaDetailsTvHeroRowId;

  static String get tabId => packCaps.mediaDetailsTvTabId;
}

/// Thin [TvKitRow] stand-in — host paints real TV focus graph.
class TvKitRow extends StatelessWidget {
  const TvKitRow({
    super.key,
    this.tabId,
    required this.rowId,
    required this.sortOrder,
    required this.itemCount,
    this.onFocusUp,
    this.orientation = ShellTvRowOrientation.horizontal,
    required this.child,
  });

  final String? tabId;
  final String rowId;
  final int sortOrder;
  final int itemCount;
  final VoidCallback? onFocusUp;
  final ShellTvRowOrientation orientation;
  final Widget child;

  @override
  Widget build(BuildContext context) => packCaps.tvKitRow(
        key: key,
        tabId: tabId ?? '',
        rowId: rowId,
        sortOrder: sortOrder,
        itemCount: itemCount,
        onFocusUp: onFocusUp,
        orientation: orientation,
        child: child,
      );
}

/// Presentational list-status pin builders (host wires Simkl / follow).
abstract final class KitListStatusButton {
  static Widget? movie({
    required PackLayoutMovie movie,
    bool excludeFromTvTraversal = false,
    double? iconSize,
  }) =>
      packCaps.listStatusPinForMovie(
        movie: movie,
        excludeFromTvTraversal: excludeFromTvTraversal,
        iconSize: iconSize,
      );

  static Widget? follow({
    required PackListFollowTarget followTarget,
    bool excludeFromTvTraversal = false,
    double? iconSize,
  }) =>
      packCaps.listStatusPinForFollow(
        followTarget: followTarget,
        excludeFromTvTraversal: excludeFromTvTraversal,
        iconSize: iconSize,
      );
}

typedef Movie = PackLayoutMovie;

class ListFollowTarget extends PackListFollowTarget {
  const ListFollowTarget({
    required super.pluginId,
    required super.open,
    required super.title,
    required super.posterPath,
    super.voteAverage = 0,
    super.releaseDate = '',
    super.tmdbId,
    super.tmdbMediaType,
    super.mediaType,
  });

  static ListFollowTarget? fromMeta({
    required String pluginId,
    required MetaItem meta,
  }) {
    final t = packCaps.listFollowFromMeta(pluginId: pluginId, meta: meta);
    if (t == null) return null;
    return ListFollowTarget(
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
  }
}





final class MetaRuntime {
  static final MetaRuntime instance = MetaRuntime._();
  MetaRuntime._();
  Future<MetaEnvelope> run({
    required String pluginId,
    required String action,
    Map<String, dynamic> params = const {},
    String? packSourceUrl,
    bool forceRefresh = false,
  }) =>
      packCaps.metaRun(
        pluginId: pluginId,
        action: action,
        params: params,
        packSourceUrl: packSourceUrl,
        forceRefresh: forceRefresh,
      );
}

final class PluginRegistry {
  static final PluginRegistry instance = PluginRegistry._();
  PluginRegistry._();
  Future<PackPluginSnapshot?> findPlugin(
    String pluginId, {
    String? sourceUrl,
  }) =>
      packCaps.findPlugin(pluginId, sourceUrl: sourceUrl);

  static Listenable get hubFeedEpoch => packCaps.hubFeedEpoch;

  static bool hubFeedEpochTouches(String pluginId) =>
      packCaps.hubFeedEpochTouches(pluginId);
}

final class PluginInstallCoordinator {
  static final PluginInstallCoordinator instance = PluginInstallCoordinator._();
  PluginInstallCoordinator._();
  Future<void> waitUntilIdle() => packCaps.waitUntilInstallIdle();
}

final class EngineService {
  static final EngineService instance = EngineService._();
  EngineService._();
  static Listenable get changeNotifier => packCaps.engineChangeListenable;
  void cancelLiveCatalog() => packCaps.cancelLiveCatalog();
}

abstract final class PluginNavRegistry {
  static String? pluginIdForTabSync(String tabId) =>
      packCaps.pluginIdForTab(tabId);
  static String? tabIdForPluginSync(String pluginId) =>
      packCaps.tabIdForPlugin(pluginId);
  static bool isKitTab(String tabId) => packCaps.isKitTab(tabId);
  static bool isCoreShell(String tabId) => packCaps.isCoreShell(tabId);
  static Future<String?> pluginIdForTab(String tabId) =>
      packCaps.resolvePluginIdForTab(tabId);
  static Future<bool> isKitPluginEnabled(
    String pluginId, {
    String? packSourceUrl,
  }) =>
      packCaps.isKitPluginEnabled(pluginId, packSourceUrl: packSourceUrl);
  static Future<String?> packSourceUrlForTab(String tabId) =>
      packCaps.packSourceUrlForTab(tabId);
  static Map<String, dynamic> get destinations => packCaps.navDestinations;
}

abstract final class VerticalFiltersRegistry {
  static Listenable get revision => packCaps.verticalFiltersRevision;

  static void syncFromLayout({
    required String tabId,
    required String pluginId,
    String? packSourceUrl,
    required List<Map<String, dynamic>> widgets,
  }) =>
      packCaps.verticalFiltersSyncFromLayout(
        tabId: tabId,
        pluginId: pluginId,
        packSourceUrl: packSourceUrl,
        widgets: widgets,
      );

  static void unregister(String tabId) => packCaps.verticalFiltersClear(tabId);

  static Object? specFor(String tabId) => packCaps.verticalFiltersSpecFor(tabId);
}

abstract final class PackFiltersRegistry {
  static Listenable get revision => packCaps.packFiltersRevision;

  static Future<void> ensureLoaded(String pluginId) =>
      packCaps.packFiltersEnsureLoaded(pluginId);

  static void invalidate([String? pluginId]) =>
      packCaps.packFiltersInvalidate(pluginId);

  static List<ChromeMenuItem> menusFor(String pluginId) =>
      packCaps.packFiltersMenusFor(pluginId);

  static ChromeMenuItem? menuById(String pluginId, String? id) =>
      packCaps.packFiltersMenuById(pluginId, id);

  static List<({String id, String label})> categoriesFor(String pluginId) =>
      packCaps.packFiltersCategoriesFor(pluginId);

  static Listenable? listenable(String pluginId) =>
      packCaps.packFiltersListenable(pluginId);

  static List<({String id, String label, String? logoUrl})> options(
          String pluginId) =>
      packCaps.packFilterOptions(pluginId);

  static String? selected(String pluginId) =>
      packCaps.packFilterSelected(pluginId);

  static Future<void> select(String pluginId, String? id) =>
      packCaps.packFilterSelect(pluginId, id);
}

Future<void> openMetaItem(
  BuildContext context, {
  required String pluginId,
  required MetaItem item,
  int? initialSeason,
  int? initialEpisode,
}) =>
    packCaps.openMetaItem(
      context,
      pluginId: pluginId,
      item: item,
      initialSeason: initialSeason,
      initialEpisode: initialEpisode,
    );

PackLayoutMovie? metaItemToMovie(MetaItem item) =>
    packCaps.metaItemToMovie(item);

bool metaOpenUsesKitDetails(MetaOpen open) =>
    packCaps.metaOpenUsesKitDetails(open);

bool hubMetaIsUpcoming(MetaItem item) => packCaps.hubMetaIsUpcoming(item);

String? hubMetaTmdbMediaType(MetaItem item) =>
    packCaps.hubMetaTmdbMediaType(item);

String? hubPosterTypeLabel(MetaItem item) => packCaps.hubPosterTypeLabel(item);

List<Map<String, dynamic>?> catalogChromeFilters({
  String? tabId,
  String? pluginId,
}) =>
    packCaps.catalogChromeFilters(tabId: tabId, pluginId: pluginId);

String catalogChromeFilterEpoch(String? tabId) =>
    packCaps.catalogChromeFilterEpoch(tabId);

extension PackListFollowTargetFactory on PackListFollowTarget {
  static PackListFollowTarget? fromMeta({
    required String pluginId,
    required MetaItem meta,
  }) =>
      packCaps.listFollowFromMeta(pluginId: pluginId, meta: meta);
}

// ignore: camel_case_types
class ListFollowTargetFactory {
  static PackListFollowTarget? fromMeta({
    required String pluginId,
    required MetaItem meta,
  }) =>
      packCaps.listFollowFromMeta(pluginId: pluginId, meta: meta);
}

class PlayerSurfaceChromeStub extends StatelessWidget {
  const PlayerSurfaceChromeStub({super.key, required this.builder});
  final WidgetBuilder builder;
  @override
  Widget build(BuildContext context) =>
      packCaps.playerSurfaceChromeBuilder(builder: builder);
}

class KitChromeTopBar extends StatelessWidget {
  const KitChromeTopBar({
    super.key,
    required this.tabId,
    required this.selectedMenuId,
    required this.selectedCategoryId,
    required this.menus,
    required this.categories,
    required this.scrollOffset,
    required this.heroHeight,
    required this.onSearch,
  });

  final String tabId;
  final ValueNotifier<String?> selectedMenuId;
  final ValueNotifier<String?> selectedCategoryId;
  final List<ChromeMenuItem> menus;
  final List<({String id, String label})> categories;
  final ValueNotifier<double> scrollOffset;
  final ValueNotifier<double> heroHeight;
  final VoidCallback? onSearch;

  @override
  Widget build(BuildContext context) => packCaps.buildKitChromeTopBar(
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
}

class BookmarkHeroStatusPill extends StatelessWidget {
  const BookmarkHeroStatusPill({
    super.key,
    required this.movie,
    this.tvTabId,
    this.tvItemIndexStart = 0,
    this.onUpEdge,
    this.onRightEdge,
    this.enabled = true,
  });

  final PackLayoutMovie movie;
  final String? tvTabId;
  final int tvItemIndexStart;
  final VoidCallback? onUpEdge;
  final VoidCallback? onRightEdge;
  final bool enabled;

  @override
  Widget build(BuildContext context) => packCaps.buildBookmarkHeroStatusPill(
        movie: movie,
        tvTabId: tvTabId,
        tvItemIndexStart: tvItemIndexStart,
        onUpEdge: onUpEdge,
        onRightEdge: onRightEdge,
        enabled: enabled,
      );
}


class KitListStatusHero extends StatelessWidget {
  const KitListStatusHero({
    super.key,
    required this.target,
    this.tvTabId,
    this.tvItemIndexStart = 0,
    this.onUpEdge,
    this.onRightEdge,
    this.enabled = true,
  });
  final PackListFollowTarget target;
  final String? tvTabId;
  final int tvItemIndexStart;
  final VoidCallback? onUpEdge;
  final VoidCallback? onRightEdge;
  final bool enabled;
  @override
  Widget build(BuildContext context) => packCaps.kitListStatusHero(
        target: target,
        tvTabId: tvTabId,
        tvItemIndexStart: tvItemIndexStart,
        onUpEdge: onUpEdge,
        onRightEdge: onRightEdge,
        enabled: enabled,
      );
}

class HeroPillPlayButton extends StatelessWidget {
  const HeroPillPlayButton({
    super.key,
    required this.label,
    this.icon = Icons.play_arrow_rounded,
    this.iconWidget,
    this.onTap,
    this.primary = true,
    this.autoFocus = false,
    this.focusNode,
    this.alwaysShowLabel = false,
    this.onKeyEvent,
    this.tvTabId,
    this.onUpEdge,
    this.onRightEdge,
    this.tvRowId,
    this.tvItemIndex,
  });

  final String label;
  final IconData? icon;
  final Widget? iconWidget;
  final VoidCallback? onTap;
  final bool primary;
  final bool alwaysShowLabel;
  final bool autoFocus;
  final FocusNode? focusNode;
  final KeyEventResult Function(FocusNode node, KeyEvent event)? onKeyEvent;
  final String? tvTabId;
  final VoidCallback? onUpEdge;
  final VoidCallback? onRightEdge;
  final String? tvRowId;
  final int? tvItemIndex;

  @override
  Widget build(BuildContext context) => packCaps.heroPillPlayButton(
        onPressed: onTap ?? () {},
        label: label,
        focusNode: focusNode,
        onUpEdge: onUpEdge,
        onRightEdge: onRightEdge,
        tvTabId: tvTabId,
        tvRowId: tvRowId,
        tvItemIndex: tvItemIndex,
      );
}

class HeroPillActionRow extends StatelessWidget {
  const HeroPillActionRow({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) =>
      packCaps.heroPillActionRow(children: children);
}

abstract final class KitEntryDetailsPage {
  static Future<void> open(
    BuildContext context, {
    required Object entry,
    required String listSourceId,
    required List<Map<String, dynamic>> layoutWidgets,
    int refreshEpoch = 0,
    String? shellTabId,
  }) =>
      packCaps.openKitEntryDetails(
        context,
        entry: entry,
        listSourceId: listSourceId,
        layoutWidgets: layoutWidgets,
        refreshEpoch: refreshEpoch,
        shellTabId: shellTabId,
      );
}


abstract final class KitSourcesPanel {
  static void claimProvidersFocus() => packCaps.claimProvidersFocus();
}

abstract final class WatchHistory {
  static Listenable get revision => packCaps.watchHistoryRevision;
  static MetaItem? metaFromEntry(Map<String, dynamic> entry) =>
      packCaps.watchHistoryMetaFromEntry(entry);
  static Future<void> remove(String pluginId, String metaId) =>
      packCaps.watchHistoryRemove(pluginId, metaId);
}

class WatchHistoryService {
  Stream<List<Map<String, dynamic>>> get historyStream =>
      packCaps.homeHistoryStream();
  Future<void> removeItem(String id) => packCaps.homeHistoryRemoveItem(id);
}

Future<List<Map<String, dynamic>>> catalogContinueEntries(
  String pluginId, {
  required bool mergeHomeWatchHistory,
}) =>
    packCaps.catalogContinueEntries(
      pluginId,
      mergeHomeWatchHistory: mergeHomeWatchHistory,
    );

bool isHomeWatchHistoryEntry(Map<String, dynamic> entry) =>
    packCaps.isHomeWatchHistoryEntry(entry);

Future<void> resumePlaybackFromHistory(
  BuildContext context,
  Map<String, dynamic> homeEntry,
) =>
    packCaps.resumePlaybackFromHistory(context, homeEntry);

bool canResumeFromSavedProgress(int posMs, int durMs) =>
    packCaps.canResumeFromSavedProgress(posMs, durMs);

Future<void> runPlayFromContext({
  required BuildContext context,
  required Map<String, dynamic> ctx,
}) =>
    packCaps.runPlayFromContext(context: context, playContext: ctx);

Map<String, dynamic> catalogPlayContextFromMeta({
  required MetaItem meta,
  required String pluginId,
  required int episodeNumber,
  String? episodeVideoId,
  Map<String, dynamic> extras = const {},
  Duration? startPosition,
}) =>
    packCaps.catalogPlayContextFromMeta(
      meta: meta,
      pluginId: pluginId,
      episodeNumber: episodeNumber,
      episodeVideoId: episodeVideoId,
      extras: extras,
      startPosition: startPosition,
    );

Future<void> openCatalogSearch(
  BuildContext context, {
  required String tabId,
  String? pluginId,
  String hintText = 'Search…',
}) =>
    packCaps.openCatalogSearch(
      context,
      tabId: tabId,
      pluginId: pluginId,
      hintText: hintText,
    );



abstract final class SettingsService {
  static Listenable get navbarChangeNotifier => packCaps.navbarChangeNotifier;
}


class TvBrowseTextField extends StatelessWidget {
  const TvBrowseTextField({
    super.key,
    this.fieldKey,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.decoration,
    this.style,
    this.onEscape,
    this.onSubmitted,
    this.onKeyEvent,
    this.browsePlaceholder,
    this.browseHintStyle,
    this.caretHeight,
  });

  /// Hosted on the real TV field so [GlobalKey.currentState] has edit APIs.
  final Key? fieldKey;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final InputDecoration decoration;
  final TextStyle? style;
  final VoidCallback? onEscape;
  final ValueChanged<String>? onSubmitted;
  final KeyEventResult Function(FocusNode, KeyEvent)? onKeyEvent;
  final String? browsePlaceholder;
  final TextStyle? browseHintStyle;
  final double? caretHeight;

  @override
  Widget build(BuildContext context) => packCaps.buildTvBrowseTextField(
        key: fieldKey ?? key,
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
}

/// Opaque state type for [GlobalKey] typing in layout search.
class TvBrowseTextFieldState {}

Listenable catalogChromeFilterListenable(String? tabId) =>
    packCaps.catalogChromeFilterListenable(tabId);

bool catalogChromeHidesTypeFilterRails(String? tabId, {String? pluginId}) =>
    packCaps.catalogChromeHidesTypeFilterRails(
      tabId: tabId,
      pluginId: pluginId,
    );

String? hubMetaPremiereDateLabel(MetaItem item) =>
    packCaps.hubMetaPremiereDateLabel(item);

String? kitPosterSubtitle(MetaItem item) => packCaps.kitPosterSubtitle(item);

String? kitPosterBadge(MetaItem item, {String? pluginId}) =>
    packCaps.kitPosterBadge(item, pluginId: pluginId);

class TvFocusGraph extends StatelessWidget {
  const TvFocusGraph({super.key, required this.tabId, required this.child});
  final String tabId;
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      packCaps.tvFocusGraph(tabId: tabId, child: child);
}

class TvChipStrip extends StatelessWidget {
  const TvChipStrip({
    super.key,
    this.tabId,
    required this.rowId,
    required this.sortOrder,
    required this.itemCount,
    required this.resultsRowId,
    this.onFocusLeft,
    this.onFocusRight,
    required this.builder,
  });

  final String? tabId;
  final String rowId;
  final int sortOrder;
  final int itemCount;
  final String resultsRowId;
  final VoidCallback? onFocusLeft;
  final VoidCallback? onFocusRight;
  final Widget Function(BuildContext context, dynamic edgesFor) builder;

  @override
  Widget build(BuildContext context) => packCaps.tvChipStrip(
        tabId: tabId ?? '',
        rowId: rowId,
        sortOrder: sortOrder,
        itemCount: itemCount,
        resultsRowId: resultsRowId,
        onFocusLeft: onFocusLeft,
        onFocusRight: onFocusRight,
        builder: builder,
      );
}

class TvGrid extends StatelessWidget {
  const TvGrid({
    super.key,
    this.tabId,
    required this.rowId,
    required this.sortOrder,
    required this.itemCount,
    required this.columns,
    this.onFocusUp,
    this.onFocusDown,
    required this.child,
  });

  final String? tabId;
  final String rowId;
  final int sortOrder;
  final int itemCount;
  final int columns;
  final VoidCallback? onFocusUp;
  final VoidCallback? onFocusDown;
  final Widget child;

  @override
  Widget build(BuildContext context) => packCaps.tvGrid(
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
}

abstract final class TvHeroActions {
  static void bind(
    String tabId, {
    FocusNode? Function()? defaultFocus,
    VoidCallback? heroReveal,
    VoidCallback? enterFromNavFocus,
    bool Function()? restoreFocus,
    bool Function()? pageBack,
    bool preferCustomRestoreFromNav = false,
  }) =>
      packCaps.tvHeroActionsBind(
        tabId,
        defaultFocus: defaultFocus,
        heroReveal: heroReveal,
        enterFromNavFocus: enterFromNavFocus,
        restoreFocus: restoreFocus,
        pageBack: pageBack,
        preferCustomRestoreFromNav: preferCustomRestoreFromNav,
      );

  static void unbind(String tabId) => packCaps.tvHeroActionsUnbind(tabId);
}

class DetailsHeroTvActionScope extends StatelessWidget {
  const DetailsHeroTvActionScope({
    super.key,
    required this.tabId,
    required this.itemCount,
    this.onFocusUp,
    this.onFocusDown,
    required this.child,
  });

  final String tabId;
  final int itemCount;
  final VoidCallback? onFocusUp;
  final VoidCallback? onFocusDown;
  final Widget child;

  @override
  Widget build(BuildContext context) => packCaps.detailsHeroTvActionScope(
        key: key,
        tabId: tabId,
        itemCount: itemCount,
        onFocusUp: onFocusUp,
        onFocusDown: onFocusDown,
        child: child,
      );
}

class KitDetailsUpcomingNotice extends StatelessWidget {
  const KitDetailsUpcomingNotice({super.key, this.releaseDateLabel});
  final String? releaseDateLabel;

  @override
  Widget build(BuildContext context) => packCaps.kitDetailsUpcomingNotice(
        key: key,
        releaseDateLabel: releaseDateLabel,
      );
}

Future<List<Map<String, dynamic>>> catalogResumeSeeds(String pluginId) =>
    packCaps.catalogResumeSeeds(pluginId);

VoidCallback tvResultsUpToChips(
  BuildContext context, {
  String chipRowId = 'mood-chips',
}) =>
    packCaps.tvResultsUpToChips(context, chipRowId: chipRowId);


class TvChipEdges {
  const TvChipEdges({
    this.onUp,
    this.onDown,
    this.onLeft,
    this.onRight,
    this.onSelectAlreadySelected,
  });
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  final VoidCallback? onLeft;
  final VoidCallback? onRight;
  final VoidCallback? onSelectAlreadySelected;
}


// Host binds a real NotifierProvider; layout watches via ref.watch.
Object get addonRevisionProvider => packCaps.addonRevisionProvider;
