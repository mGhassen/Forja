import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/settings/addons/settings_addon_catalog.dart';
import 'package:forja/features/settings/addons/settings_addon_detail.dart';
import 'package:forja/features/settings/addons/settings_addon_toggles.dart';
import 'package:forja/features/settings/settings_catalog.dart';
import 'package:forja/features/settings/settings_visibility.dart';
import 'package:forja/features/settings/widgets/settings_pack_prompt_pane.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/engine/plugin_install_prompt.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shared/sync/sync.dart';

/// Open addon inside Settings → Addons. Hub chrome listens so the page title
/// is the addon name (not a second "Addons" heading).
class SettingsAddonDrill {
  static final ValueNotifier<SettingsAddonMeta?> current =
      ValueNotifier<SettingsAddonMeta?>(null);

  static void close() => current.value = null;
}

/// Category page chrome that swaps title for addon detail or pack install picker.
class SettingsAddonsAwareScaffold extends StatelessWidget {
  const SettingsAddonsAwareScaffold({
    super.key,
    required this.categoryTitle,
    required this.child,
    this.categoryId,
    this.categoryAdminOnly = false,
    this.scrollable = true,
    this.categoryBack = false,
  });

  final String categoryTitle;
  final Widget child;
  final String? categoryId;
  final bool categoryAdminOnly;
  final bool scrollable;
  final bool categoryBack;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SettingsAddonMeta?>(
      valueListenable: SettingsAddonDrill.current,
      builder: (context, addon, _) {
        return ValueListenableBuilder<PluginBatchInstallPrompt?>(
          valueListenable: SettingsPackPromptDrill.current,
          builder: (context, packPrompt, _) {
            final packOpen = packPrompt != null &&
                categoryId == SettingsCategoryId.forjaPacks;
            final title = packOpen
                ? SettingsPackPromptDrill.titleFor(packPrompt)
                : (addon?.title ?? categoryTitle);
            return SettingsPageScaffold(
              title: title,
              adminOnly: packOpen
                  ? false
                  : (addon?.adminOnly ?? categoryAdminOnly),
              showBack: packOpen || addon != null || categoryBack,
              onBack: packOpen
                  ? () {
                      unawaited(
                        SettingsPackPromptDrill.dismissWithoutApply(),
                      );
                    }
                  : addon != null
                      ? SettingsAddonDrill.close
                      : () => Navigator.of(context).maybePop(),
              scrollable: scrollable,
              child: child,
            );
          },
        );
      },
    );
  }
}

/// Settings → Addons body.
///
/// Shows a master list of addons with activate toggles. Tapping an addon row
/// replaces the list with that addon's detail (back returns to the list).
/// On compact layout this is always a single-column view; the split hub
/// scaffold handles left rail ↔ right pane.
class SettingsAddonsHost extends StatefulWidget {
  const SettingsAddonsHost({
    super.key,
    required this.visibility,
    this.initialAddonId,
  });

  final SettingsVisibility visibility;

  /// Pre-open a specific addon detail (deep-link from old category IDs).
  final String? initialAddonId;

  @override
  State<SettingsAddonsHost> createState() => SettingsAddonsHostState();
}

class SettingsAddonsHostState extends State<SettingsAddonsHost> {
  @override
  void initState() {
    super.initState();
    SettingsAddonDrill.current.addListener(_onDrill);
    final initialId = widget.initialAddonId ?? ShellBus.pendingAddonDeepLink;
    ShellBus.pendingAddonDeepLink = null;
    if (initialId != null) {
      SettingsAddonDrill.current.value = settingsAddonById(initialId);
    }
  }

  @override
  void dispose() {
    SettingsAddonDrill.current.removeListener(_onDrill);
    super.dispose();
  }

  void _onDrill() {
    if (mounted) setState(() {});
  }

  void _open(String addonId) {
    SettingsAddonDrill.current.value = settingsAddonById(addonId);
  }

  @override
  Widget build(BuildContext context) {
    final open = SettingsAddonDrill.current.value;
    if (open != null) {
      final adminBlocked =
          open.adminOnly && !AccountFeatures.instance.isAdmin;
      if (adminBlocked) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          SettingsAddonDrill.close();
        });
        return const SizedBox.shrink();
      }
      return buildAddonDetailBody(open.id, widget.visibility);
    }
    return _AddonListPane(
      visibility: widget.visibility,
      onOpen: _open,
    );
  }
}

class _AddonListPane extends ConsumerWidget {
  const _AddonListPane({
    required this.visibility,
    required this.onOpen,
  });

  final SettingsVisibility visibility;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(accountFeaturesProvider);
    final addons = settingsAddons();
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    // Spatial ←/→ so Right moves row → activate switch (linear scope would
    // treat → as “next row” and bury the toggle).
    final list = ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: addons.length,
      separatorBuilder: (_, _) => Padding(
        padding: const EdgeInsets.only(left: 2),
        child: Divider(
          height: 1,
          thickness: 1,
          color: ForjaShellColors.borderSubtle.withValues(alpha: 0.6),
        ),
      ),
      itemBuilder: (context, index) {
        final addon = addons[index];
        return _AddonRow(
          meta: addon,
          visibility: visibility,
          onTap: () => onOpen(addon.id),
        );
      },
    );
    if (!tv) return list;
    return ShellTvDisableLinearFocus(child: list);
  }
}

class _AddonRow extends ConsumerStatefulWidget {
  const _AddonRow({
    required this.meta,
    required this.visibility,
    required this.onTap,
  });

  final SettingsAddonMeta meta;
  final SettingsVisibility visibility;
  final VoidCallback onTap;

  @override
  ConsumerState<_AddonRow> createState() => _AddonRowState();
}

class _AddonRowState extends ConsumerState<_AddonRow> {
  late final FocusNode _rowFocus =
      FocusNode(debugLabel: 'addon-row-${widget.meta.id}');
  late final FocusNode _toggleFocus =
      FocusNode(debugLabel: 'addon-toggle-${widget.meta.id}');

  @override
  void dispose() {
    _rowFocus.dispose();
    _toggleFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meta = widget.meta;
    final visibility = widget.visibility;
    final onTap = widget.onTap;
    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final titles = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        settingsTitleText(
          meta.title,
          const TextStyle(
            color: ForjaShellColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          adminOnly: meta.adminOnly,
          sparkSize: 14,
        ),
        const SizedBox(height: 2),
        Text(
          meta.subtitle,
          style: const TextStyle(
            color: ForjaShellColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
    final chevron = const Icon(
      Icons.chevron_right_rounded,
      color: ForjaShellColors.iconMuted,
      size: 20,
    );

    final leading =
        Icon(meta.icon, color: ForjaShellColors.textSecondary, size: 22);
    // Desktop + TV: keep switch outside the row tap so click/OK on the
    // label opens detail and the switch only flips activation.
    if (meta.hasToggle) {
      return Row(
        children: [
          Expanded(
            child: shellFocusableTap(
              context: context,
              focusNode: _rowFocus,
              onTap: onTap,
              borderRadius: SettingsTokens.categoryTileRadius,
              scaleOnFocus: 1.0,
              showFocusRail: true,
              tvTabId: 'settings',
              tvZone: ShellTvZone.settings,
              ensureVisibleMode: ShellTvEnsureVisibleMode.item,
              onRightEdge: tv
                  ? () {
                      if (_toggleFocus.canRequestFocus) {
                        _toggleFocus.requestFocus();
                      }
                    }
                  : null,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 2, vertical: 16),
                child: Row(
                  children: [
                    leading,
                    const SizedBox(width: 12),
                    Expanded(child: titles),
                    const SizedBox(width: 4),
                    chevron,
                  ],
                ),
              ),
            ),
          ),
          AddonMasterToggle(
            addonId: meta.id,
            visibility: visibility,
            focusNode: tv ? _toggleFocus : null,
            onLeftEdge: tv
                ? () {
                    if (_rowFocus.canRequestFocus) {
                      _rowFocus.requestFocus();
                    }
                  }
                : null,
          ),
          const SizedBox(width: 4),
        ],
      );
    }

    return shellFocusableTap(
      context: context,
      focusNode: _rowFocus,
      onTap: onTap,
      borderRadius: SettingsTokens.categoryTileRadius,
      scaleOnFocus: 1.0,
      showFocusRail: true,
      tvTabId: 'settings',
      tvZone: ShellTvZone.settings,
      ensureVisibleMode: ShellTvEnsureVisibleMode.item,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 16),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(child: titles),
            const SizedBox(width: 4),
            chevron,
          ],
        ),
      ),
    );
  }
}
