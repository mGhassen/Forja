import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/settings/providers/settings_panel_providers.dart';
import 'package:forja/features/settings/settings_visibility.dart';
import 'package:forja/features/settings/widgets/settings_engine_pack_update.dart';
import 'package:forja/features/settings/widgets/settings_engine_plugin_pack.dart';
import 'package:forja/features/settings/widgets/settings_plugin_install_progress.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/sync/sync.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';

/// Settings → Forja Packs — JS plugin manifests (providers, hubs, live, …).
class SettingsForjaPacksSection extends ConsumerStatefulWidget {
  const SettingsForjaPacksSection({super.key, required this.visibility});

  final SettingsVisibility visibility;

  @override
  ConsumerState<SettingsForjaPacksSection> createState() =>
      _SettingsForjaPacksSectionState();
}

class _SettingsForjaPacksSectionState
    extends ConsumerState<SettingsForjaPacksSection> {
  final TextEditingController _engineController = TextEditingController();
  bool _engineInstalling = false;
  bool _engineUpdatingAll = false;

  @override
  void initState() {
    super.initState();
    PluginInstallCoordinator.instance.progress.addListener(_onPluginInstallProgress);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(enginePackUpdatesProvider.notifier).refresh();
    });
  }

  void _onPluginInstallProgress() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    PluginInstallCoordinator.instance.progress.removeListener(
      _onPluginInstallProgress,
    );
    _engineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enginePacks =
        ref.watch(enginePacksProvider).valueOrNull ?? const [];
    final packUpdates = ref.watch(enginePackUpdatesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          label: 'Forja packs',
          children: [
            ListenableBuilder(
              listenable: Listenable.merge([
                PluginInstallCoordinator.instance.progress,
                EngineService.changeNotifier,
                RemotePackIntentStore.changeNotifier,
              ]),
              builder: (context, _) =>
                  _buildEnginePackSection(enginePacks, packUpdates),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEnginePackSection(
    List<EnginePack> packs,
    EnginePackUpdatesState packUpdates,
  ) {
    final installError = EngineService.officialInstallError.value;
    final installProgress = PluginInstallCoordinator.instance.progress.value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (packs.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
              child: Text(
                installError == null
                    ? 'No packs installed. Paste a manifest URL below, or sign in to sync from your profile.'
                    : 'Pack install failed: $installError',
                style: TextStyle(
                  color: installError == null
                      ? ForjaShellColors.textSecondary.withValues(alpha: 0.9)
                      : const Color(0xFFF87171),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            if (installError != null) ...[
              SettingsFilledButton(
                label: 'Retry install',
                icon: Icons.refresh_rounded,
                busy: _engineInstalling,
                onPressed: _retryOfficialEnginePack,
              ),
              const SizedBox(height: 12),
            ],
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
            child: Text(
              'Each pack is a manifest.json URL. Forja downloads the manifest, '
              'then every plugin script, before the pack is fully usable.',
              style: TextStyle(
                color: ForjaShellColors.textSecondary.withValues(alpha: 0.85),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          SettingsTextField(
            controller: _engineController,
            label: 'Add pack',
            hint: 'https://.../manifest.json',
            onSubmitted: (_) => _installEnginePack(),
          ),
          const SizedBox(height: 14),
          SettingsFilledButton(
            label: 'Install',
            icon: Icons.add_rounded,
            busy: _engineInstalling,
            onPressed: _installEnginePack,
          ),
          if (packs.isNotEmpty) ...[
            const SizedBox(height: 20),
            SettingsEnginePackUpdatesBar(
              updateCount: packUpdates.count,
              checking: packUpdates.checking,
              updating: _engineUpdatingAll,
              onUpdateAll: () => _updateAllEnginePacks(packUpdates.updates),
              onCheckAgain: () =>
                  ref.read(enginePackUpdatesProvider.notifier).refresh(),
            ),
            const SettingsEngineMiniLabel('Installed packs'),
            ..._buildEnginePacksByKind(
              packs,
              installProgress: installProgress,
              packUpdates: packUpdates,
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildEnginePacksByKind(
    List<EnginePack> packs, {
    PluginInstallProgress? installProgress,
    required EnginePackUpdatesState packUpdates,
  }) {
    final grouped = groupEnginePacksByKind(packs);
    final out = <Widget>[];
    for (final kind in grouped.orderedKinds) {
      final kindPacks = grouped.byKind[kind] ?? const <EnginePack>[];
      final rows = <Widget>[];
      for (final pack in kindPacks) {
        final update = packUpdates.forPack(pack.sourceUrl);
        rows.add(
          FutureBuilder<PackDeviceSnapshot>(
            future: resolvePackDeviceState(
              manifestUrl: pack.sourceUrl,
              localPack: pack,
              update: update,
            ),
            builder: (context, snap) {
              final state = snap.data?.state;
              if (state == PackDeviceState.pendingPurge) {
                return SettingsEnginePackPendingTile(
                  packName: pack.name,
                  sourceUrl: pack.sourceUrl,
                  progress: installProgress,
                  badge: 'Removed from profile',
                  actionLabel: 'Uninstall now',
                  onAction: () => unawaited(_purgePackNow(pack.sourceUrl)),
                );
              }
              if (state == PackDeviceState.deferred ||
                  state == PackDeviceState.onProfileLean ||
                  state == PackDeviceState.failed ||
                  pack.plugins.isEmpty) {
                final badge = switch (state) {
                  PackDeviceState.deferred => 'Install later',
                  PackDeviceState.failed => 'Install failed',
                  PackDeviceState.downloading => 'Downloading',
                  _ => 'Pending download',
                };
                return SettingsEnginePackPendingTile(
                  packName: pack.name,
                  sourceUrl: pack.sourceUrl,
                  progress: installProgress,
                  badge: badge,
                  actionLabel: 'Install',
                  onAction: () => unawaited(_installNamedPack(pack.sourceUrl)),
                );
              }
              final panelPlugins = [
                for (final p in pack.plugins)
                  if (p.isHttp || p.isHubCatalog || p.isTorrent) p,
              ];
              if (panelPlugins.isEmpty) return const SizedBox.shrink();
              final liveSportPlugins = [
                for (final p in panelPlugins)
                  if (p.isLiveSportPlugin) p,
              ];
              final isLiveSportPack =
                  liveSportPlugins.isNotEmpty &&
                  liveSportPlugins.length == panelPlugins.length;
              return isLiveSportPack
                  ? SettingsLiveSportPackExpansion(
                      pack: pack,
                      plugins: liveSportPlugins,
                      update: update,
                      trailing: _EnginePackActions(
                        packEnabled: pack.enabled,
                        update: update,
                        onTogglePack: (val) =>
                            EngineService.instance.setPackEnabled(
                          sourceUrl: pack.sourceUrl,
                          enabled: val,
                        ),
                        onRefresh: () => _refreshEnginePack(
                          pack.sourceUrl,
                          update: update,
                        ),
                        onRemove: () => _removeEnginePack(pack.sourceUrl),
                        showOfficialBadge: false,
                      ),
                    )
                  : SettingsEnginePackExpansion(
                      pack: pack,
                      plugins: panelPlugins,
                      groupKey: EngineCategories.groupKey,
                      groupLabel: EngineCategories.groupLabel,
                      groupOrder: EngineCategories.groupOrderFor(panelPlugins),
                      installProgress: installProgress,
                      update: update,
                      trailing: _EnginePackActions(
                        packEnabled: pack.enabled,
                        update: update,
                        onTogglePack: (val) =>
                            EngineService.instance.setPackEnabled(
                          sourceUrl: pack.sourceUrl,
                          enabled: val,
                        ),
                        onRefresh: () => _refreshEnginePack(
                          pack.sourceUrl,
                          update: update,
                        ),
                        onRemove: () => _removeEnginePack(pack.sourceUrl),
                        showOfficialBadge: false,
                      ),
                    );
            },
          ),
        );
      }
      if (rows.isEmpty) continue;
      out.add(const SizedBox(height: 12));
      out.add(SettingsEngineMiniLabel(PluginRegistry.packKindLabel(kind)));
      out.add(const SizedBox(height: 4));
      out.addAll(rows);
    }
    return out;
  }

  Future<void> _retryOfficialEnginePack() async {
    setState(() => _engineInstalling = true);
    try {
      await EngineService.instance.retryOfficialInstall();
      if (!mounted) return;
      ForjaToast.success('Packs refreshed');
    } catch (e) {
      if (!mounted) return;
      ForjaToast.error('Pack install failed: $e');
    } finally {
      if (mounted) setState(() => _engineInstalling = false);
    }
  }

  Future<void> _refreshEnginePack(
    String sourceUrl, {
    EnginePackUpdateInfo? update,
  }) async {
    setState(() => _engineInstalling = true);
    try {
      final pack = await PluginInstallCoordinator.instance.installManifest(
        sourceUrl,
        isUpdate: true,
      );
      if (!mounted) return;
      ref.read(enginePackUpdatesProvider.notifier).clearFor(sourceUrl);
      ref.invalidate(enginePacksProvider);
      ForjaToast.success(
        update != null
            ? 'Updated ${pack.name} to v${pack.version}'
            : 'Refreshed ${pack.name} v${pack.version}',
      );
    } catch (e) {
      if (!mounted) return;
      ForjaToast.error('Refresh failed: $e');
    } finally {
      if (mounted) setState(() => _engineInstalling = false);
    }
  }

  Future<void> _updateAllEnginePacks(
    Map<String, EnginePackUpdateInfo> updates,
  ) async {
    if (updates.isEmpty || _engineUpdatingAll) return;
    setState(() => _engineUpdatingAll = true);
    var ok = 0;
    try {
      for (final entry in updates.values) {
        try {
          await PluginInstallCoordinator.instance.installManifest(
            entry.sourceUrl,
            isUpdate: true,
          );
          ref.read(enginePackUpdatesProvider.notifier).clearFor(entry.sourceUrl);
          ok++;
        } catch (e) {
          if (!mounted) return;
          ForjaToast.error('${entry.packName} update failed: $e');
        }
      }
      if (!mounted) return;
      ref.invalidate(enginePacksProvider);
      await ref.read(enginePackUpdatesProvider.notifier).refresh();
      if (ok > 0) {
        ForjaToast.success(
          ok == 1 ? '1 pack updated' : '$ok packs updated',
        );
      }
    } finally {
      if (mounted) setState(() => _engineUpdatingAll = false);
    }
  }

  Future<void> _installNamedPack(String sourceUrl) async {
    setState(() => _engineInstalling = true);
    try {
      final pack = await PluginInstallCoordinator.instance.installManifest(
        sourceUrl,
      );
      await DeferredRemoteInstallStore.clear(sourceUrl);
      if (!mounted) return;
      scheduleForjaSyncPush();
      ref.invalidate(enginePacksProvider);
      ForjaToast.success(
        'Installed ${pack.name} (${pack.plugins.length} plugins)',
      );
    } catch (e) {
      if (!mounted) return;
      ForjaToast.error('Install failed: $e');
    } finally {
      if (mounted) setState(() => _engineInstalling = false);
    }
  }

  Future<void> _purgePackNow(String sourceUrl) async {
    try {
      await EngineService.instance.removePack(sourceUrl);
      await PendingRemotePurgeStore.clear(sourceUrl);
      if (!mounted) return;
      ref.invalidate(enginePacksProvider);
      ForjaToast.success('Pack uninstalled');
    } catch (e) {
      if (!mounted) return;
      ForjaToast.error('$e');
    }
  }

  Future<void> _installEnginePack() async {
    final url = _engineController.text.trim();
    if (url.isEmpty) return;
    setState(() => _engineInstalling = true);
    try {
      final pack = await PluginInstallCoordinator.instance.installManifest(url);
      if (!mounted) return;
      _engineController.clear();
      scheduleForjaSyncPush();
      ref.invalidate(enginePacksProvider);
      ForjaToast.success(
        'Installed ${pack.name} (${pack.plugins.length} plugins)',
      );
    } catch (e) {
      if (!mounted) return;
      ForjaToast.error('Install failed: $e');
    } finally {
      if (mounted) setState(() => _engineInstalling = false);
    }
  }

  Future<void> _removeEnginePack(String sourceUrl) async {
    try {
      await EngineService.instance.removePack(sourceUrl);
      await PendingRemotePurgeStore.clear(sourceUrl);
      await DeferredRemoteInstallStore.clear(sourceUrl);
      if (!mounted) return;
      scheduleForjaSyncPush();
      ref.invalidate(enginePacksProvider);
      ForjaToast.success('Pack removed');
    } catch (e) {
      if (!mounted) return;
      ForjaToast.error('$e');
    }
  }
}

class _EnginePackActions extends StatelessWidget {
  const _EnginePackActions({
    required this.packEnabled,
    required this.onTogglePack,
    required this.onRefresh,
    required this.onRemove,
    this.showOfficialBadge = false,
    this.update,
  });

  final bool packEnabled;
  final ValueChanged<bool> onTogglePack;
  final VoidCallback onRefresh;
  final Future<void> Function() onRemove;
  final bool showOfficialBadge;
  final EnginePackUpdateInfo? update;

  @override
  Widget build(BuildContext context) {
    final hasUpdate = update != null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ForjaSwitch(
          value: packEnabled,
          scale: ForjaSwitch.settingsScale,
          onChanged: onTogglePack,
        ),
        if (showOfficialBadge)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(
              'Official',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: ForjaShellColors.brandGreen.withValues(alpha: 0.9),
              ),
            ),
          ),
        _settingsTvIconButton(
          context,
          tooltip: hasUpdate
              ? 'Update to v${update!.remoteVersion}'
              : 'Refresh',
          icon: hasUpdate
              ? Icons.system_update_rounded
              : Icons.refresh_rounded,
          onPressed: onRefresh,
          color: hasUpdate
              ? ForjaShellColors.brandGreen
              : ForjaShellColors.textPrimary,
        ),
        _AddonRemoveActions(onRemove: onRemove),
      ],
    );
  }
}

Widget _settingsTvIconButton(
  BuildContext context, {
  required String tooltip,
  required IconData icon,
  required VoidCallback? onPressed,
  Color color = ForjaShellColors.textPrimary,
}) {
  final child = Icon(icon, color: color, size: 20);
  final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
  if (tv) {
    return shellFocusableTap(
      context: context,
      onTap: onPressed,
      borderRadius: 8,
      scaleOnFocus: 1.0,
      showFocusRail: true,
      tvTabId: 'settings',
      tvZone: ShellTvZone.settings,
      child: SizedBox(width: 40, height: 40, child: Center(child: child)),
    );
  }
  return IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    icon: child,
  );
}

class _AddonRemoveActions extends StatefulWidget {
  const _AddonRemoveActions({
    required this.onRemove,
    this.confirming,
    this.onConfirmingChanged,
  });

  final Future<void> Function() onRemove;
  final bool? confirming;
  final ValueChanged<bool>? onConfirmingChanged;

  @override
  State<_AddonRemoveActions> createState() => _AddonRemoveActionsState();
}

class _AddonRemoveActionsState extends State<_AddonRemoveActions> {
  bool _localConfirming = false;

  bool get _confirming => widget.confirming ?? _localConfirming;

  void _setConfirming(bool value) {
    if (widget.onConfirmingChanged != null) {
      widget.onConfirmingChanged!(value);
    } else {
      setState(() => _localConfirming = value);
    }
  }

  Future<void> _confirm() async {
    _setConfirming(false);
    await widget.onRemove();
  }

  @override
  Widget build(BuildContext context) {
    if (_confirming) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _settingsTvIconButton(
            context,
            tooltip: 'Yes',
            icon: Icons.check_rounded,
            color: const Color(0xFFEF4444),
            onPressed: () => unawaited(_confirm()),
          ),
          _settingsTvIconButton(
            context,
            tooltip: 'No',
            icon: Icons.close_rounded,
            color: ForjaShellColors.iconMuted,
            onPressed: () => _setConfirming(false),
          ),
        ],
      );
    }
    return _settingsTvIconButton(
      context,
      tooltip: 'Remove pack',
      icon: Icons.delete_outline,
      color: const Color(0xFFF87171),
      onPressed: () => _setConfirming(true),
    );
  }
}
