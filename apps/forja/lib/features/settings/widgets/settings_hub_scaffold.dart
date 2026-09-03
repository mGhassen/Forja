import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/settings/addons/settings_addons_host.dart';
import 'package:forja/features/settings/pages/settings_category_bodies.dart';
import 'package:forja/features/settings/settings_catalog.dart';
import 'package:forja/features/settings/providers/settings_visibility_provider.dart';
import 'package:forja/features/settings/settings_visibility.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';

/// Hub chrome: split sidebar on wide (incl. Android TV 1080p+), list→push on compact.
class SettingsHubScaffold extends ConsumerStatefulWidget {
  const SettingsHubScaffold({
    super.key,
    required this.selectedId,
    required this.onSelect,
    this.firstTileFocusNode,
  });

  final String selectedId;
  final ValueChanged<String> onSelect;
  final FocusNode? firstTileFocusNode;

  @override
  ConsumerState<SettingsHubScaffold> createState() =>
      _SettingsHubScaffoldState();
}

class _SettingsHubScaffoldState extends ConsumerState<SettingsHubScaffold> {
  static const _categoryRowId = 'settings-categories';

  SettingsVisibility? _visibility;
  final FocusScopeNode _detailScope =
      FocusScopeNode(debugLabel: 'settings-detail');
  int _detailEnterToken = 0;

  @override
  void initState() {
    super.initState();
    // Back ladder: detail → selected category → first category → nav rail.
    TvHeroActions.bind(
      'settings',
      pageBack: _handlePageBack,
    );
  }

  void _reloadFromProvider(SettingsVisibility next) {
    if (!mounted) return;
    if (_visibility == next) return;
    setState(() => _visibility = next);
    // Never force Profile here. Resume/cloud pull can briefly drop gated
    // tiles; auto-fallback was overwriting [ShellBus.settingsHubCategoryId]
    // and yanking the hub back to Profile & account.
  }

  @override
  void didUpdateWidget(covariant SettingsHubScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedId != widget.selectedId &&
        widget.selectedId != SettingsCategoryId.sources) {
      SettingsAddonDrill.close();
    }
  }

  @override
  void dispose() {
    _detailScope.dispose();
    super.dispose();
  }

  bool _focusSelectedCategory() {
    final visibility = _visibility;
    if (visibility == null) return false;
    final categories = settingsCategories(visibility);
    final index = categories.indexWhere((c) => c.id == widget.selectedId);
    if (index < 0) return false;
    return ShellTvFocusCoordinator.focusRowItem(
      'settings',
      _categoryRowId,
      index,
    );
  }

  /// OK / → from the category rail: bump [SettingsDetailEnter] so the detail
  /// scaffold lands focus on the first right-pane control.
  void _enterDetail(String categoryId) {
    if (categoryId != widget.selectedId) {
      widget.onSelect(categoryId);
    }
    setState(() => _detailEnterToken++);
    // Do not focus the bare [FocusScope] — that leaves primary on
    // `settings-detail` with no row chrome. Land on the first control after
    // the detail body rebuilds.
    WidgetsBinding.instance.addPostFrameCallback((_) => _landDetailFocus(0));
  }

  void _landDetailFocus(int attempt) {
    if (!mounted) return;
    if (!ShellScope.metricsOf(context).usesTvDensity) return;

    final first = _firstDetailFocusable();
    if (first != null) {
      first.requestFocus();
      if (first.hasPrimaryFocus || first.hasFocus) return;
    }

    if (attempt < 30) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _landDetailFocus(attempt + 1),
      );
      return;
    }

    // Empty / still building — own the scope so Back can exit to the rail.
    if (_detailScope.canRequestFocus && !_detailScope.hasFocus) {
      _detailScope.requestFocus();
    }
  }

  FocusNode? _firstDetailFocusable() {
    if (!_detailScope.canRequestFocus) return null;

    final policy = ReadingOrderTraversalPolicy();
    final fromPolicy = policy.findFirstFocus(
      _detailScope,
      ignoreCurrentFocus: true,
    );
    if (fromPolicy != null &&
        !identical(fromPolicy, _detailScope) &&
        fromPolicy.canRequestFocus &&
        !fromPolicy.skipTraversal &&
        fromPolicy.context != null) {
      return fromPolicy;
    }

    for (final node in _detailScope.descendants) {
      if (identical(node, _detailScope)) continue;
      if (node is FocusScopeNode) continue;
      if (!node.canRequestFocus || node.skipTraversal) continue;
      if (node.context == null) continue;
      return node;
    }
    return null;
  }

  int? _focusedCategoryIndex() {
    final handle =
        ShellTvFocusCoordinator.rowHandle('settings', _categoryRowId);
    if (handle == null || handle.itemCount <= 0) return null;
    for (var i = 0; i < handle.itemCount; i++) {
      if (handle.nodeAt(i)?.hasFocus ?? false) return i;
    }
    return null;
  }

  bool _handlePageBack() {
    if (!mounted) return false;
    if (!SettingsTokens.useSplitLayout(context)) return false;
    if (!ShellScope.inputPolicyOf(context).useFocusableMoodChips) return false;

    if (SettingsAddonDrill.current.value != null) {
      SettingsAddonDrill.close();
      return true;
    }

    if (_detailScope.hasFocus) {
      if (_detailEnterToken != 0) {
        setState(() => _detailEnterToken = 0);
      }
      return _focusSelectedCategory();
    }

    final categoryIndex = _focusedCategoryIndex();
    if (categoryIndex != null && categoryIndex > 0) {
      return ShellTvFocusCoordinator.focusRowItem(
        'settings',
        _categoryRowId,
        0,
      );
    }
    return false;
  }

  Widget _wrapCompactTvFocus(Widget child) {
    // Settings lists are vertical reading-order (↑/← prev, ↓/→ next) — not
    // spatial sideways jumps between side-by-side controls.
    return ShellTvContainDpad(
      child: ShellTvLinearFocusScope(
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibilityAsync = ref.watch(settingsVisibilityProvider);
    ref.listen(settingsVisibilityProvider, (_, next) {
      next.whenData(_reloadFromProvider);
    });
    // Visibility already watches play/nav/account revisions — do not
    // invalidate (that clears AsyncData and flashes the hub empty).

    final visibility = visibilityAsync.valueOrNull ?? _visibility;
    if (visibility == null) {
      return const SafeArea(child: SizedBox.expand());
    }

    final categories = settingsCategories(visibility);
    final split = SettingsTokens.useSplitLayout(context);
    final selectedMeta = settingsCategoryById(widget.selectedId, visibility);
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    if (ShellBus.takeEnterSettingsDetail()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (tv) {
          _enterDetail(widget.selectedId);
        } else {
          _focusSelectedCategory();
        }
      });
    }

    if (split) {
      return TvFocusGraph(
        tabId: 'settings',
        child: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: SettingsTokens.sidebarWidth,
                child: FocusTraversalGroup(
                  policy: ReadingOrderTraversalPolicy(),
                  child: TvCatalogRow(
                    rowId: _categoryRowId,
                    sortOrder: 0,
                    itemCount: tv ? categories.length : 0,
                    orientation: ShellTvRowOrientation.vertical,
                    child: _CategorySidebar(
                      categories: categories,
                      selectedId: widget.selectedId,
                      onSelect: (id) {
                        if (id != SettingsCategoryId.sources) {
                          SettingsAddonDrill.close();
                        }
                        widget.onSelect(id);
                      },
                      firstTileFocusNode: widget.firstTileFocusNode,
                      categoryRowId: tv ? _categoryRowId : null,
                      onEnterDetail: tv ? _enterDetail : null,
                    ),
                  ),
                ),
              ),
              Container(
                width: 1,
                color: ForjaShellColors.borderSubtle,
              ),
              Expanded(
                child: tv
                    ? FocusScope(
                        node: _detailScope,
                        // D-pad stays in the detail pane (vertical reading
                        // order). Back (_handlePageBack) → category rail.
                        child: SettingsDetailEnter(
                          enterToken: _detailEnterToken,
                          child: ShellTvContainDpad(
                            child: ShellTvLinearFocusScope(
                              child: FocusTraversalGroup(
                                policy: ReadingOrderTraversalPolicy(),
                                child: SettingsAddonsAwareScaffold(
                                  categoryTitle:
                                      selectedMeta?.title ?? 'Settings',
                                  categoryAdminOnly:
                                      selectedMeta?.adminOnly ?? false,
                                  scrollable:
                                      !(selectedMeta?.fillViewport ?? false),
                                  child: buildSettingsCategoryBody(
                                    widget.selectedId,
                                    visibility,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    : SettingsAddonsAwareScaffold(
                        categoryTitle: selectedMeta?.title ?? 'Settings',
                        categoryAdminOnly: selectedMeta?.adminOnly ?? false,
                        scrollable: !(selectedMeta?.fillViewport ?? false),
                        child: buildSettingsCategoryBody(
                          widget.selectedId,
                          visibility,
                        ),
                      ),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: _wrapCompactTvFocus(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                SettingsTokens.pagePadding,
                tv ? 28 : 8,
                SettingsTokens.pagePadding,
                4,
              ),
              child: const ShellTabHeader(
                title: 'Settings',
                padding: EdgeInsets.zero,
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                  SettingsTokens.pagePadding,
                  8,
                  SettingsTokens.pagePadding,
                  48,
                ),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final c = categories[index];
                  return SettingsCategoryTile(
                    icon: c.icon,
                    title: c.title,
                    subtitle: c.subtitle,
                    selected: false,
                    adminOnly: c.adminOnly,
                    listIndex: index,
                    focusNode: index == 0 ? widget.firstTileFocusNode : null,
                    onTap: () => widget.onSelect(c.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategorySidebar extends StatelessWidget {
  const _CategorySidebar({
    required this.categories,
    required this.selectedId,
    required this.onSelect,
    this.categoryRowId,
    this.onEnterDetail,
    this.firstTileFocusNode,
  });

  final List<SettingsCategoryMeta> categories;
  final String selectedId;
  final ValueChanged<String> onSelect;
  final String? categoryRowId;
  final ValueChanged<String>? onEnterDetail;
  final FocusNode? firstTileFocusNode;

  @override
  Widget build(BuildContext context) {
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final headerTop = tv ? 28.0 : 12.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, headerTop, 16, 8),
          child: const ShellTabHeader(
            title: 'Settings',
            padding: EdgeInsets.zero,
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final c = categories[index];
              return SettingsCategoryTile(
                icon: c.icon,
                title: c.title,
                subtitle: c.subtitle,
                selected: c.id == selectedId,
                adminOnly: c.adminOnly,
                listIndex: index,
                // Pin default/restore focus on the *selected* tile — never
                // index 0 (Profile). Resume focus dump onto hub-0 was
                // selecting Profile via onFocusSelect.
                focusNode: c.id == selectedId ? firstTileFocusNode : null,
                tvRowId: categoryRowId,
                tvItemIndex: categoryRowId != null ? index : null,
                onRightEdge: onEnterDetail == null
                    ? null
                    : () => onEnterDetail!(c.id),
                // ↑/↓ selects only; OK / Right enters the independent detail pane.
                onFocusSelect:
                    onEnterDetail == null ? null : () => onSelect(c.id),
                onTap: () {
                  if (onEnterDetail != null) {
                    onEnterDetail!(c.id);
                  } else {
                    onSelect(c.id);
                  }
                },
              );
            },
          ),
        ),
        const SettingsSidebarFooter(),
      ],
    );
  }
}
