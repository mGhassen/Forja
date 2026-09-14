import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/engine/packs/install/plugin_install_coordinator.dart';
import 'package:forja/shared/engine/runtime/kit/pack_opaque_run.dart';
import 'package:forja/shared/engine/runtime/kit/paint_tree.dart';
import 'package:forja/shared/engine/runtime/nav/chrome_filters.dart';
import 'package:forja/shared/engine/runtime/nav/plugin_nav.dart';
import 'package:forja/shared/engine/runtime/nav/vertical_filters.dart';
import 'package:forja/shell/chrome/vertical_filters_rail.dart';
import 'package:forja/shell/routing/shell_tab_refresh.dart';
import 'package:forja_foundation/protocol/layout_types.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/blocks/catalog/catalog_body_block.dart';
import 'package:forja_foundation/widgets/chrome/layout_scope.dart';
import 'package:forja_foundation/widgets/feedback/error_retry_panel.dart';

/// Hub tab mount — validate pack page JSON and paint. No product field mappers.
///
/// Page action comes from pack [nav.page.action] (opaque). Default empty → error.
class PackLayoutPainter extends StatefulWidget {
  const PackLayoutPainter({
    super.key,
    required this.pluginId,
    this.tabId,
    this.packSourceUrl,
    this.pageAction,
    this.pageParams,
  });

  final String pluginId;
  final String? tabId;
  final String? packSourceUrl;

  /// Opaque pack action that returns the page tree (`pages` / `widgets`).
  final String? pageAction;
  final Map<String, dynamic>? pageParams;

  @override
  State<PackLayoutPainter> createState() => _PackLayoutPainterState();
}

class _PackLayoutPainterState extends State<PackLayoutPainter>
    with AutomaticKeepAliveClientMixin, ShellTabRefresh<PackLayoutPainter> {
  List<Map<String, dynamic>> _widgets = const [];
  final Map<String, String> _layoutSelections = {};
  String? _error;
  bool _loading = true;

  String get _pageKey => widget.tabId?.trim() ?? '';

  String get _pageAction {
    final fromWidget = widget.pageAction?.trim() ?? '';
    if (fromWidget.isNotEmpty) return fromWidget;
    final fromNav = PluginNavRegistry.pageActionForTab(_pageKey);
    if (fromNav != null && fromNav.isNotEmpty) return fromNav;
    return '';
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPage());
  }

  @override
  void didUpdateWidget(covariant PackLayoutPainter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pluginId != widget.pluginId ||
        oldWidget.tabId != widget.tabId ||
        oldWidget.packSourceUrl != widget.packSourceUrl ||
        oldWidget.pageAction != widget.pageAction) {
      unawaited(_loadPage(force: true));
    }
  }

  @override
  void dispose() {
    final tab = widget.tabId?.trim();
    if (tab != null && tab.isNotEmpty) {
      VerticalFiltersRegistry.unregister(tab);
    }
    super.dispose();
  }

  @override
  Future<void> onShellTabRefresh({required bool force}) =>
      _loadPage(force: force);

  Future<void> _loadPage({bool force = false}) async {
    final action = _pageAction;
    if (action.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'This hub did not declare nav.page.action — pack must own the page load.';
        _widgets = const [];
      });
      return;
    }

    final soft = _widgets.isNotEmpty && !force;
    if (!soft) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    await PluginInstallCoordinator.instance.waitUntilIdle();
    if (!mounted) return;

    final enabled = await PluginNavRegistry.isKitPluginEnabled(
      widget.pluginId,
      packSourceUrl: widget.packSourceUrl,
    );
    if (!mounted) return;
    if (!enabled) {
      setState(() {
        _loading = false;
        _widgets = const [];
        _error =
            'This hub plugin is off. Enable it under Settings → Sources → Forja (Hubs).';
      });
      return;
    }

    final params = <String, dynamic>{
      ...?widget.pageParams,
      ...?PluginNavRegistry.pageParamsForTab(_pageKey),
      'page': _pageKey,
    };

    final envelope = await packOpaqueRun(
      pluginId: widget.pluginId,
      action: action,
      params: params,
      packSourceUrl: widget.packSourceUrl,
      forceRefresh: force,
    );
    if (!mounted) return;

    if (!envelope.ok) {
      setState(() {
        _loading = false;
        _error = envelope.error?.message.isNotEmpty == true
            ? envelope.error!.message
            : 'Pack page load failed.';
      });
      return;
    }

    final invalid = validateLayoutData(envelope.data);
    if (invalid != null) {
      setState(() {
        _loading = false;
        _error = 'This hub’s layout is invalid.';
      });
      return;
    }

    final data = envelope.data!;
    final pages = data['pages'];
    var widgets = <Map<String, dynamic>>[];
    if (pages is Map && pages.isNotEmpty) {
      final page = pages[_pageKey] ?? pages.values.first;
      if (page is Map) {
        final raw = page['widgets'];
        if (raw is List) {
          widgets = [
            for (final w in raw)
              if (w is Map) Map<String, dynamic>.from(w),
          ];
        }
      }
    } else {
      final raw = data['widgets'];
      if (raw is List) {
        widgets = [
          for (final w in raw)
            if (w is Map) Map<String, dynamic>.from(w),
        ];
      }
    }

    setState(() {
      _loading = false;
      _error = null;
      _widgets = widgets;
      initLayoutTabSelections(_layoutSelections, widgets);
    });
    final tab = widget.tabId?.trim();
    if (tab != null && tab.isNotEmpty) {
      VerticalFiltersRegistry.syncFromLayout(
        tabId: tab,
        pluginId: widget.pluginId,
        packSourceUrl: widget.packSourceUrl,
        widgets: widgets,
      );
    }
    markShellTabFresh();
  }

  void _onLayoutSelect(String widgetId, String value, {required bool toggle}) {
    setState(() {
      if (toggle && _layoutSelections[widgetId] == value) {
        _layoutSelections.remove(widgetId);
      } else {
        _layoutSelections[widgetId] = value;
      }
    });
  }

  Widget _wrapLayoutScope(Widget child) {
    return LayoutScope(
      selections: Map<String, String>.unmodifiable(
        Map<String, String>.from(_layoutSelections),
      ),
      widgetSpecs: layoutWidgetSpecIndex(_widgets),
      tabId: _pageKey,
      onSelect: _onLayoutSelect,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading && _widgets.isEmpty) {
      return const ColoredBox(
        color: ForjaShellColors.surfaceElevated,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_error != null && _widgets.isEmpty) {
      return ColoredBox(
        color: ForjaShellColors.surfaceElevated,
        child: ShellErrorRetryPanel(
          message: _error!,
          onRetry: () => unawaited(onShellTabRefresh(force: true)),
        ),
      );
    }

    final listenable = catalogChromeFilterListenable(_pageKey);
    Widget result = listenable == null
        ? _wrapLayoutScope(_pageBody())
        : ListenableBuilder(
            listenable: listenable,
            builder: (_, _) => _wrapLayoutScope(_pageBody()),
          );
    final tab = widget.tabId?.trim() ?? '';
    if (tab.isNotEmpty && VerticalFiltersRegistry.hasFilters(tab)) {
      result = Stack(
        clipBehavior: Clip.none,
        children: [
          result,
          Positioned(
            key: ValueKey('kit-vf-rail-$tab'),
            left: ShellTokens.shellProviderRailInset,
            top: 0,
            bottom: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: VerticalFiltersRail(tabId: tab)),
            ),
          ),
        ],
      );
    }
    return result;
  }

  /// Expand stack / kit.list roots need a bounded Column — not SliverToBoxAdapter.
  Widget _pageBody() {
    final fullPage = _fullPageBody();
    if (fullPage != null) return fullPage;
    return CatalogBody(sections: _composeSections());
  }

  Widget? _fullPageBody() {
    if (_widgets.length != 1) return null;
    final root = _widgets.first;
    if (!LayoutTypes.isCompositionRoot(root)) return null;
    // Bound the expand stack — without this, kit.list SizedBox.expand is 0×0
    // and pointer hit tests spam "render box with no size".
    return SizedBox.expand(
      child: PackPaintTree(
        spec: root,
        pluginId: widget.pluginId,
        packSourceUrl: widget.packSourceUrl,
        tabId: _pageKey,
      ),
    );
  }

  bool _chromeHidesTypeFilterRail() =>
      catalogChromeHidesTypeFilterRails(_pageKey);

  /// Hero bleed rail (VF registered via [VerticalFiltersRegistry.syncFromLayout]).
  List<Widget> _composeSections() {
    Map<String, dynamic>? heroSpec;
    String? bleedKey;
    for (final w in _widgets) {
      final type = LayoutTypes.normalize((w['type'] ?? '').toString(), w);
      if (type != LayoutTypes.hero) continue;
      heroSpec = w;
      final bleed = (w['bleed'] ?? '').toString().trim();
      if (bleed.isNotEmpty) bleedKey = bleed;
      break;
    }

    Map<String, dynamic>? bleedSpec;
    if (bleedKey != null) {
      for (final w in _widgets) {
        final id = (w['id'] ?? '').toString().trim();
        final rail = (w['rail'] ?? '').toString().trim();
        if (id == bleedKey || rail == bleedKey) {
          if (w['hideWhenTypeFilter'] == true && _chromeHidesTypeFilterRail()) {
            break;
          }
          bleedSpec = w;
          break;
        }
      }
    }

    final out = <Widget>[];
    for (final w in _widgets) {
      final type = LayoutTypes.normalize((w['type'] ?? '').toString(), w);
      if (type == LayoutTypes.verticalFilters) continue;
      if (identical(w, bleedSpec) &&
          bleedSpec != null &&
          bleedSpec['hideWhenBleed'] == true) {
        continue;
      }
      if (w['hideWhenTypeFilter'] == true && _chromeHidesTypeFilterRail()) {
        continue;
      }
      if (type == LayoutTypes.hero &&
          identical(w, heroSpec) &&
          bleedSpec != null) {
        // Bleed child rides under the hero load as a following rail section.
        out.add(
          PackPaintTree(
            spec: w,
            pluginId: widget.pluginId,
            packSourceUrl: widget.packSourceUrl,
            tabId: _pageKey,
          ),
        );
        out.add(
          PackPaintTree(
            spec: Map<String, dynamic>.from(bleedSpec)..remove('title'),
            pluginId: widget.pluginId,
            packSourceUrl: widget.packSourceUrl,
            tabId: _pageKey,
          ),
        );
        continue;
      }
      out.add(
        PackPaintTree(
          spec: w,
          pluginId: widget.pluginId,
          packSourceUrl: widget.packSourceUrl,
          tabId: _pageKey,
        ),
      );
    }
    return out;
  }
}

/// Resolves [tabId] → hub pluginId then mounts [PackLayoutPainter].
class PackLayoutPainterLoader extends StatefulWidget {
  const PackLayoutPainterLoader({super.key, required this.tabId});

  final String tabId;

  @override
  State<PackLayoutPainterLoader> createState() =>
      _PackLayoutPainterLoaderState();
}

class _PackLayoutPainterLoaderState extends State<PackLayoutPainterLoader> {
  String? _pluginId;
  String? _packSourceUrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_resolve());
  }

  @override
  void didUpdateWidget(covariant PackLayoutPainterLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabId != widget.tabId) unawaited(_resolve());
  }

  Future<void> _resolve() async {
    setState(() => _loading = true);
    final pluginId = await PluginNavRegistry.pluginIdForTab(widget.tabId);
    final url = await PluginNavRegistry.packSourceUrlForTab(widget.tabId);
    if (!mounted) return;
    setState(() {
      _pluginId = pluginId;
      _packSourceUrl = url;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    final id = _pluginId?.trim() ?? '';
    if (id.isEmpty) {
      return const Center(child: Text('No hub pack for this tab.'));
    }
    return PackLayoutPainter(
      pluginId: id,
      tabId: widget.tabId,
      packSourceUrl: _packSourceUrl,
    );
  }
}

/// Backward-compatible aliases while call sites migrate.
typedef PackLayoutHost = PackLayoutPainter;
typedef PackLayoutHostLoader = PackLayoutPainterLoader;
