import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/settings/addons/settings_addon_catalog.dart';
import 'package:forja/features/settings/addons/settings_addon_detail.dart';
import 'package:forja/features/settings/addons/settings_addon_toggles.dart';
import 'package:forja/features/settings/settings_visibility.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:forja/shell/shell_bus.dart';

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
  String? _openAddonId;

  /// Opened programmatically — allows deep-link into an addon.
  void openAddon(String addonId) {
    if (!mounted) return;
    setState(() => _openAddonId = addonId);
  }

  @override
  void initState() {
    super.initState();
    _openAddonId = widget.initialAddonId ?? ShellBus.pendingAddonDeepLink;
    ShellBus.pendingAddonDeepLink = null;
  }

  void _back() {
    if (!mounted) return;
    setState(() => _openAddonId = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_openAddonId != null) {
      final meta = settingsAddonById(_openAddonId!);
      if (meta == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _back());
        return const SizedBox.shrink();
      }
      return _AddonDetailPane(
        meta: meta,
        visibility: widget.visibility,
        onBack: _back,
      );
    }
    return _AddonListPane(
      visibility: widget.visibility,
      onOpen: (id) => setState(() => _openAddonId = id),
    );
  }
}

class _AddonDetailPane extends StatelessWidget {
  const _AddonDetailPane({
    required this.meta,
    required this.visibility,
    required this.onBack,
  });

  final SettingsAddonMeta meta;
  final SettingsVisibility visibility;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DetailHeader(meta: meta, onBack: onBack),
        const SizedBox(height: 16),
        buildAddonDetailBody(meta.id, visibility),
      ],
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.meta, required this.onBack});

  final SettingsAddonMeta meta;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        shellFocusableTap(
          context: context,
          onTap: onBack,
          borderRadius: 20,
          scaleOnFocus: 1.0,
          showFocusRail: true,
          tvTabId: 'settings',
          tvZone: ShellTvZone.settings,
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(
              Icons.arrow_back_rounded,
              color: ForjaShellColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Icon(meta.icon, color: ForjaShellColors.textSecondary, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: settingsTitleText(
            meta.title,
            const TextStyle(
              color: ForjaShellColors.textPrimary,
              fontSize: SettingsTokens.pageTitleSize,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
            adminOnly: meta.adminOnly,
            sparkSize: 18,
          ),
        ),
      ],
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
    final addons = settingsAddons();
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: addons.length,
      separatorBuilder: (_, _) => const SizedBox(height: 2),
      itemBuilder: (context, index) {
        final addon = addons[index];
        return _AddonRow(
          meta: addon,
          visibility: visibility,
          onTap: () => onOpen(addon.id),
        );
      },
    );
  }
}

class _AddonRow extends ConsumerWidget {
  const _AddonRow({
    required this.meta,
    required this.visibility,
    required this.onTap,
  });

  final SettingsAddonMeta meta;
  final SettingsVisibility visibility;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return shellFocusableTap(
      context: context,
      onTap: onTap,
      borderRadius: 12,
      scaleOnFocus: 1.0,
      showFocusRail: true,
      tvTabId: 'settings',
      tvZone: ShellTvZone.settings,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: ForjaShellColors.surfaceElevated.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(meta.icon, color: ForjaShellColors.textSecondary, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meta.title,
                    style: const TextStyle(
                      color: ForjaShellColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
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
              ),
            ),
            if (meta.hasToggle)
              AddonMasterToggle(
                addonId: meta.id,
                visibility: visibility,
              ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              color: ForjaShellColors.iconMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
