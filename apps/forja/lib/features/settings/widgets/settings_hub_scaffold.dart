import 'package:flutter/material.dart';
import 'package:forja/features/settings/pages/settings_category_bodies.dart';
import 'package:forja/features/settings/settings_catalog.dart';
import 'package:forja/features/settings/settings_visibility.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
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
  SettingsVisibility? _visibility;

  @override
  void initState() {
    super.initState();
    SettingsService.playSourceChangeNotifier.addListener(_reload);
    SettingsService.navbarChangeNotifier.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    SettingsService.playSourceChangeNotifier.removeListener(_reload);
    SettingsService.navbarChangeNotifier.removeListener(_reload);
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

  Widget _wrapTvFocus(Widget child) {
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

    if (split) {
      return SafeArea(
        child: _wrapTvFocus(
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: SettingsTokens.sidebarWidth,
                child: _CategorySidebar(
                  categories: categories,
                  selectedId: widget.selectedId,
                  onSelect: widget.onSelect,
                  firstTileFocusNode: widget.firstTileFocusNode,
                ),
              ),
              Container(
                width: 1,
                color: ForjaShellColors.borderSubtle,
              ),
              Expanded(
                child: SettingsPageScaffold(
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
        ),
      );
    }

    return SafeArea(
      child: _wrapTvFocus(
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
    this.firstTileFocusNode,
  });

  final List<SettingsCategoryMeta> categories;
  final String selectedId;
  final ValueChanged<String> onSelect;
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
                onTap: () => onSelect(c.id),
              );
            },
          ),
        ),
        const SettingsSidebarFooter(),
      ],
    );
  }
}
