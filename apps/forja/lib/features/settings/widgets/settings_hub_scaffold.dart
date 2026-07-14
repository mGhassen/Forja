import 'package:flutter/material.dart';
import 'package:forja/features/settings/pages/settings_category_bodies.dart';
import 'package:forja/features/settings/settings_catalog.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/design/design.dart';

/// Hub chrome: split sidebar on wide, category list on compact / TV.
class SettingsHubScaffold extends StatelessWidget {
  const SettingsHubScaffold({
    super.key,
    required this.selectedId,
    required this.onSelect,
  });

  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final categories = settingsCategories();
    final split = SettingsTokens.useSplitLayout(context);

    if (split) {
      return SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: SettingsTokens.sidebarWidth,
              child: _CategorySidebar(
                categories: categories,
                selectedId: selectedId,
                onSelect: onSelect,
              ),
            ),
            Container(
              width: 1,
              color: ForjaShellColors.borderSubtle,
            ),
            Expanded(
              child: SettingsPageScaffold(
                title: settingsCategoryById(selectedId)?.title ?? 'Settings',
                scrollable:
                    !(settingsCategoryById(selectedId)?.fillViewport ?? false),
                child: buildSettingsCategoryBody(selectedId),
              ),
            ),
          ],
        ),
      );
    }

    return SafeArea(
      child: Column(
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
                  onTap: () => onSelect(c.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CategorySidebar extends StatelessWidget {
  const _CategorySidebar({
    required this.categories,
    required this.selectedId,
    required this.onSelect,
  });

  final List<SettingsCategoryMeta> categories;
  final String selectedId;
  final ValueChanged<String> onSelect;

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
