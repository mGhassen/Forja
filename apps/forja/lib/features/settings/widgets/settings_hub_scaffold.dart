import 'package:flutter/material.dart';
import 'package:forja/features/settings/pages/settings_category_bodies.dart';
import 'package:forja/features/settings/settings_catalog.dart';
import 'package:forja/features/settings/settings_visibility.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:rust/rust.dart';

/// Hub chrome: split sidebar on wide (incl. Android TV 1080p+), list→push on compact.
class SettingsHubScaffold extends StatefulWidget {
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
  State<SettingsHubScaffold> createState() => _SettingsHubScaffoldState();
}

class _SettingsHubScaffoldState extends State<SettingsHubScaffold> {
  static const _categoryRowId = 'settings-categories';

  SettingsVisibility? _visibility;
  final FocusScopeNode _detailScope =
      FocusScopeNode(debugLabel: 'settings-detail');

  @override
  void initState() {
    super.initState();
    SettingsService.playSourceChangeNotifier.addListener(_reload);
    SettingsService.navbarChangeNotifier.addListener(_reload);
    // Back ladder: detail → selected category → first category → nav rail.
    ShellTvFocusCoordinator.registerTabDefaults(
      'settings',
      pageBack: _handlePageBack,
    );
    _reload();
  }

  @override
  void dispose() {
    SettingsService.playSourceChangeNotifier.removeListener(_reload);
    SettingsService.navbarChangeNotifier.removeListener(_reload);
    shellTvUnregisterRow(tabId: 'settings', rowId: _categoryRowId);
    _detailScope.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final next = await SettingsVisibility.resolve();
    if (!mounted) return;
    setState(() => _visibility = next);
    // Split layout only - compact uses push routes and keeps selectedId at profile.
    if (!SettingsTokens.useSplitLayout(context)) return;
    final ids = settingsCategories(next).map((c) => c.id).toSet();
    if (!ids.contains(widget.selectedId)) {
      widget.onSelect(SettingsCategoryId.profile);
    }
  }

  void _registerCategoryRow(int count) {
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    if (!tv) return;
    shellTvRegisterRow(
      tabId: 'settings',
      rowId: _categoryRowId,
      sortOrder: 0,
      itemCount: count,
      orientation: ShellTvRowOrientation.vertical,
    );
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

  bool _focusDetailFirst() {
    if (!_detailScope.canRequestFocus) return false;
    final first = OrderedTraversalPolicy().findFirstFocus(_detailScope);
    if (first == null || !first.canRequestFocus) {
      _detailScope.requestFocus();
      // Async bodies (Features navbar load) may gain focusables next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_detailScope.hasFocus) return;
        final retry = OrderedTraversalPolicy().findFirstFocus(_detailScope);
        if (retry != null && retry.canRequestFocus) {
          retry.requestFocus();
        }
      });
      return _detailScope.hasFocus;
    }
    first.requestFocus();
    return true;
  }

  void _enterDetail(String categoryId) {
    if (categoryId != widget.selectedId) {
      widget.onSelect(categoryId);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusDetailFirst();
    });
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

  /// TV Back: detail → selected category → first category → (false → nav).
  bool _handlePageBack() {
    if (!mounted) return false;
    if (!SettingsTokens.useSplitLayout(context)) return false;
    if (!ShellScope.inputPolicyOf(context).useFocusableMoodChips) return false;

    if (_detailScope.hasFocus) {
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
    return ShellTvLinearFocusScope(
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibility = _visibility;
    if (visibility == null) {
      return const SafeArea(child: SizedBox.expand());
    }

    final categories = settingsCategories(visibility);
    final split = SettingsTokens.useSplitLayout(context);
    final selectedMeta = settingsCategoryById(widget.selectedId, visibility);
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;

    if (split) {
      if (tv) _registerCategoryRow(categories.length);
      return SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: SettingsTokens.sidebarWidth,
              child: FocusTraversalGroup(
                policy: OrderedTraversalPolicy(),
                child: _CategorySidebar(
                  categories: categories,
                  selectedId: widget.selectedId,
                  onSelect: widget.onSelect,
                  firstTileFocusNode: widget.firstTileFocusNode,
                  categoryRowId: tv ? _categoryRowId : null,
                  onEnterDetail: tv ? _enterDetail : null,
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
                      child: ShellTvLinearFocusScope(
                        child: ShellTvLinearFocusEdges(
                          onBackwardEdge: _focusSelectedCategory,
                          child: FocusTraversalGroup(
                            policy: OrderedTraversalPolicy(),
                            child: SettingsPageScaffold(
                              title: selectedMeta?.title ?? 'Settings',
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
                    )
                  : SettingsPageScaffold(
                      title: selectedMeta?.title ?? 'Settings',
                      scrollable: !(selectedMeta?.fillViewport ?? false),
                      child: buildSettingsCategoryBody(
                        widget.selectedId,
                        visibility,
                      ),
                    ),
            ),
          ],
        ),
      );
    }

    return SafeArea(
      child: _wrapCompactTvFocus(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                SettingsTokens.pagePadding,
                8,
                SettingsTokens.pagePadding,
                4,
              ),
              child: ShellTabHeader(
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: ShellTabHeader(
            title: 'Settings',
            padding: EdgeInsets.zero,
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final c = categories[index];
              return SettingsCategoryTile(
                icon: c.icon,
                title: c.title,
                subtitle: c.subtitle,
                selected: c.id == selectedId,
                listIndex: index,
                focusNode: index == 0 ? firstTileFocusNode : null,
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
