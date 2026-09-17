import 'dart:async';

import 'package:flutter/material.dart' hide Switch;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forja/features/settings/providers/settings_panel_providers.dart';
import 'package:forja/features/settings/shell/catalog.dart';
import 'package:forja/features/settings/shell/visibility.dart';
import 'package:forja/features/settings/packs/engine_pack_update.dart';
import 'package:forja/features/settings/packs/engine_plugin_pack.dart';
import 'package:forja/features/settings/packs/plugin_install_progress.dart';
import 'package:forja/features/settings/ui/settings_ui.dart';

import 'package:forja/shared/engine/engine.dart';
import 'package:forja/shared/engine/packs/registry/pack_hub_features.dart';
import 'package:forja/shared/engine/runtime/nav/plugin_nav.dart';
import 'package:forja/shared/platform/platform_info.dart';
import 'package:forja/shared/sync/sync.dart';
import 'package:forja/shell/tv/shell_tv_coordinator.dart';
import 'package:forja/shell/tv/shell_tv_focus.dart';
import 'package:forja/features/settings/packs/pack_prompt_pane.dart';
import 'package:forja/shared/engine/packs/install/pack_install_refs.dart';
import 'package:forja/features/settings/packs/forja_pack_choice_cards.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:forja/shell/bus/shell_bus.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/feedback/forja_toast.dart';
import 'package:forja_foundation/components/switch.dart';
import 'package:forja/shell/focus/shell_focusable_tap.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
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
  bool _engineReloading = false;
  bool _engineUpdatingAll = false;
  /// Snapshot while Reload / Update all / Download all runs — keeps rows still.
  List<EnginePack>? _frozenPacksDuringBulk;
  EnginePackUpdatesState? _frozenUpdatesDuringBulk;
  final Map<String, Future<PackDeviceSnapshot>> _deviceStateFutures = {};

  bool get _bulkPackBusy =>
      _engineReloading ||
      _engineUpdatingAll ||
      (_engineInstalling && _frozenPacksDuringBulk != null);

  @override
  void initState() {
    super.initState();
    SettingsPackPromptDrill.current.addListener(_onPackPromptDrill);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(enginePackUpdatesProvider.notifier).refresh();
    });
  }

  void _onPackPromptDrill() {
    if (mounted) setState(() {});
  }

  void _beginBulkPackOp(List<EnginePack> packs) {
    _frozenPacksDuringBulk = List<EnginePack>.from(packs);
    _frozenUpdatesDuringBulk = ref.read(enginePackUpdatesProvider);
  }

  void _endBulkPackOp() {
    _frozenPacksDuringBulk = null;
    _frozenUpdatesDuringBulk = null;
    _deviceStateFutures.clear();
  }

  Future<PackDeviceSnapshot> _deviceStateFuture({
    required EnginePack pack,
    EnginePackUpdateInfo? update,
  }) {
    final key =
        '${pack.sourceUrl}0${pack.plugins.length}0${pack.version}0'
        '${update?.remoteVersion ?? ''}';
    final hit = _deviceStateFutures[key];
    if (hit != null) return hit;
    _deviceStateFutures.removeWhere(
      (k, _) => k.startsWith('${pack.sourceUrl}0'),
    );
    final future = resolvePackDeviceState(
      manifestUrl: pack.sourceUrl,
      localPack: pack,
      update: update,
    );
    _deviceStateFutures[key] = future;
    return future;
  }

  @override
  void dispose() {
    SettingsPackPromptDrill.current.removeListener(_onPackPromptDrill);
    _engineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final packPrompt = SettingsPackPromptDrill.current.value;
    if (packPrompt != null) {
      return SettingsPackPromptPane(
        prompt: packPrompt,
        onDismiss: SettingsPackPromptDrill.close,
      );
    }

    final livePacks = ref.watch(enginePacksProvider).valueOrNull ?? const [];
    final enginePacks = _frozenPacksDuringBulk ?? livePacks;
    final liveUpdates = ref.watch(enginePackUpdatesProvider);
    final packUpdates = _frozenUpdatesDuringBulk ?? liveUpdates;

    // Bulk Reload/Update/Download: freeze the list — progress would remount
    // every FutureBuilder / ExpansionTile and stutter.
    // Do not listen to EngineService.changeNotifier here — that remounts rows
    // on every toggle; enginePacksProvider already reloads with previous kept.
    final packSection = _bulkPackBusy
        ? _buildEnginePackSection(
            enginePacks,
            packUpdates,
            installProgress: null,
          )
        : ListenableBuilder(
            listenable: Listenable.merge([
              PluginInstallCoordinator.instance.progress,
              EngineService.officialInstallError,
              RemotePackIntentStore.changeNotifier,
              PackInstallFailures.latest,
            ]),
            builder: (context, _) => _buildEnginePackSection(
              enginePacks,
              packUpdates,
              installProgress:
                  PluginInstallCoordinator.instance.progress.value,
            ),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          label: 'Forja packs',
          children: [packSection],
        ),
      ],
    );
  }

  Widget _buildEnginePackSection(
    List<EnginePack> packs,
    EnginePackUpdatesState packUpdates, {
    PluginInstallProgress? installProgress,
  }) {
    final installError = EngineService.officialInstallError.value;
    final sessionFailures = PackInstallFailures.latest.value;
    // Pending = lean stubs / empty script set. Reload = packs with scripts on disk.
    final downloadable = [
      for (final pack in packs)
        if (pack.plugins.isEmpty &&
            !PluginRegistry.isLegacyAssetPack(pack.sourceUrl))
          pack,
    ];
    final reloadable = [
      for (final pack in packs)
        if (pack.plugins.isNotEmpty &&
            !PluginRegistry.isLegacyAssetPack(pack.sourceUrl))
          pack,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      // Spatial 2D (cards side-by-side). DisableLinear is belt-and-suspenders
      // if a parent ever re-wraps linear.
      child: ShellTvDisableLinearFocus(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (sessionFailures.isNotEmpty) ...[
              _PackInstallFailuresBanner(failures: sessionFailures),
              const SizedBox(height: 12),
            ],
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
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 4, 2, 14),
              child: ForjaPackChoiceCards(
                compact: true,
                settingsTvFocus: true,
                communitySubtitle: PlatformInfo.isAndroidTv
                    ? 'Choose packs on your phone\n$kCommunityPacksUrl'
                    : 'Browse packs on the web',
                onInstallOfficial: () => unawaited(_installOfficialBundle()),
                onBrowseCommunity: () => unawaited(_browseCommunityPacks()),
              ),
            ),
            SettingsTextField(
              controller: _engineController,
              label: 'Add pack',
              hint: 'Paste one or more manifest URLs / local paths',
              onSubmitted: (_) {
                if (_engineReloading || _engineInstalling) return;
                unawaited(_installEnginePack());
              },
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (downloadable.isNotEmpty) ...[
                  SettingsFilledButton(
                    label: 'Download all',
                    icon: Icons.download_rounded,
                    secondary: true,
                    busy: _engineInstalling,
                    onPressed: _engineReloading || _engineUpdatingAll
                        ? null
                        : () =>
                              unawaited(_downloadAllPendingPacks(downloadable)),
                  ),
                  const SizedBox(width: 12),
                ],
                if (reloadable.isNotEmpty) ...[
                  SettingsFilledButton(
                    label: 'Reload',
                    icon: Icons.refresh_rounded,
                    secondary: true,
                    busy: _engineReloading,
                    onPressed:
                        _engineInstalling ||
                            _engineReloading ||
                            _engineUpdatingAll
                        ? null
                        : () => unawaited(_reloadAllEnginePacks(reloadable)),
                  ),
                  const SizedBox(width: 12),
                ],
                SettingsFilledButton(
                  label: 'Install',
                  icon: Icons.add_rounded,
                  busy: _engineInstalling,
                  onPressed: _engineReloading ? null : _installEnginePack,
                ),
              ],
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
              if (_bulkPackBusy) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
                  child: Text(
                    _engineReloading
                        ? 'Reloading packs…'
                        : _engineUpdatingAll
                            ? 'Updating packs…'
                            : 'Downloading packs…',
                    style: TextStyle(
                      color: ForjaShellColors.textSecondary.withValues(
                        alpha: 0.9,
                      ),
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
              SettingsEngineMiniLabel(
                downloadable.isNotEmpty && reloadable.isEmpty
                    ? 'Pending downloads'
                    : 'Installed packs',
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _buildEnginePacksByKind(
                  packs,
                  installProgress: installProgress,
                  packUpdates: packUpdates,
                ),
              ),
            ],
          ],
        ),
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
        final deprecated = packUpdates.isDeprecated(pack.sourceUrl);
        rows.add(
          KeyedSubtree(
            key: ValueKey('engine-pack-${pack.sourceUrl}'),
            child: FutureBuilder<PackDeviceSnapshot>(
              future: _deviceStateFuture(pack: pack, update: update),
              builder: (context, snap) {
                final state = snap.data?.state;
                if (state == PackDeviceState.pendingPurge) {
                  return SettingsEnginePackPendingTile(
                    packName: pack.name,
                    sourceUrl: pack.sourceUrl,
                    progress: installProgress,
                    badge: 'Removed from profile',
                    actionTooltip: 'Uninstall now',
                    actionIcon: Icons.delete_outline,
                    onAction: () => unawaited(_purgePackNow(pack)),
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
                    actionTooltip: state == PackDeviceState.failed
                        ? 'Retry download'
                        : 'Download',
                    actionIcon: Icons.download_rounded,
                    onAction: () =>
                        unawaited(_installNamedPack(pack.sourceUrl)),
                    onRemove: () => _removeEnginePack(pack),
                  );
                }
                final panelPlugins = [
                  for (final p in pack.plugins)
                    if (p.isHttp || p.isKitPlugin || p.isTorrent) p,
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
                        deprecated: deprecated,
                        onHeaderActivate: () => unawaited(
                          _togglePackEnabled(pack, enabled: !pack.enabled),
                        ),
                        trailing: _EnginePackActions(
                          packEnabled: pack.enabled,
                          update: update,
                          onTogglePack: (val) => unawaited(
                            _togglePackEnabled(pack, enabled: val),
                          ),
                          onRefresh: () => _refreshEnginePack(
                            pack.sourceUrl,
                            update: update,
                          ),
                          onRemove: () => _removeEnginePack(pack),
                          showOfficialBadge: false,
                        ),
                      )
                    : SettingsEnginePackExpansion(
                        pack: pack,
                        plugins: panelPlugins,
                        groupKey: EngineCategories.groupKey,
                        groupLabel: EngineCategories.groupLabel,
                        groupOrder:
                            EngineCategories.groupOrderFor(panelPlugins),
                        installProgress: installProgress,
                        update: update,
                        deprecated: deprecated,
                        onHeaderActivate: () => unawaited(
                          _togglePackEnabled(pack, enabled: !pack.enabled),
                        ),
                        trailing: _EnginePackActions(
                          packEnabled: pack.enabled,
                          update: update,
                          onTogglePack: (val) => unawaited(
                            _togglePackEnabled(pack, enabled: val),
                          ),
                          onRefresh: () => _refreshEnginePack(
                            pack.sourceUrl,
                            update: update,
                          ),
                          onRemove: () => _removeEnginePack(pack),
                          showOfficialBadge: false,
                        ),
                      );
              },
            ),
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

  Future<void> _browseCommunityPacks() async {
    if (PlatformInfo.isAndroidTv) {
      await Clipboard.setData(const ClipboardData(text: kCommunityPacksUrl));
      if (!mounted) return;
      ForjaToast.success('Community Packs URL copied');
      return;
    }
    final ok = await launchUrl(
      Uri.parse(kCommunityPacksUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      ForjaToast.error('Could not open Community Packs');
    }
  }

  Future<void> _installOfficialBundle() async {
    if (_engineInstalling || _engineReloading) return;
    setState(() => _engineInstalling = true);
    try {
      final outcome = await promptRecommendedBundleInstall();
      if (!mounted) return;
      switch (outcome) {
        case OfficialPackPromptOutcome.alreadyInstalled:
          ForjaToast.success('Recommended packs already installed');
        case OfficialPackPromptOutcome.busy:
          ForjaToast.info('Finish the current pack prompt first');
        case OfficialPackPromptOutcome.prompted:
          break;
      }
    } catch (e) {
      if (!mounted) return;
      ForjaToast.error('Official pack install failed: $e');
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
      await PluginNavRegistry.refresh();
      if (!mounted) return;
      ref.read(enginePackUpdatesProvider.notifier).clearFor(sourceUrl);
      await ref.read(enginePacksProvider.notifier).reload();
      ForjaToast.success(
        update != null
            ? 'Updated ${pack.name} to v${pack.version}'
            : 'Refreshed ${pack.name} v${pack.version}',
      );
      if (update != null) {
        PluginInstallCoordinator.instance.clearPackUpdateToast();
      }
    } catch (e) {
      if (!mounted) return;
      ForjaToast.error('Refresh failed: $e');
    } finally {
      if (mounted) setState(() => _engineInstalling = false);
    }
  }

  Future<void> _reloadAllEnginePacks(List<EnginePack> packs) async {
    if (packs.isEmpty || _engineReloading) return;
    setState(() {
      _engineReloading = true;
      _beginBulkPackOp(packs);
    });
    var ok = 0;
    try {
      for (final pack in packs) {
        try {
          await PluginInstallCoordinator.instance.installManifest(
            pack.sourceUrl,
            isUpdate: true,
          );
          ok++;
        } catch (e) {
          if (!mounted) return;
          ForjaToast.error('${pack.name} reload failed: $e');
        }
      }
      if (!mounted) return;
      await ref.read(enginePacksProvider.notifier).reload();
      await ref.read(enginePackUpdatesProvider.notifier).refresh();
      if (ok > 0) {
        ForjaToast.success(ok == 1 ? '1 pack reloaded' : '$ok packs reloaded');
        PluginInstallCoordinator.instance.clearPackUpdateToast();
      }
    } finally {
      if (mounted) {
        setState(() {
          _engineReloading = false;
          _endBulkPackOp();
        });
      }
    }
  }

  Future<void> _downloadAllPendingPacks(List<EnginePack> packs) async {
    if (packs.isEmpty || _engineInstalling || _engineReloading) return;
    setState(() {
      _engineInstalling = true;
      _beginBulkPackOp(packs);
    });
    var ok = 0;
    final installed = <EnginePack>[];
    try {
      for (final pack in packs) {
        try {
          final fresh = await PluginInstallCoordinator.instance.installManifest(
            pack.sourceUrl,
          );
          await DeferredRemoteInstallStore.clear(pack.sourceUrl);
          installed.add(fresh);
          ok++;
        } catch (e) {
          if (!mounted) return;
          ForjaToast.error('${pack.name} download failed: $e');
        }
      }
      if (installed.isNotEmpty) {
        await PackHubFeatures.refreshAndActivateInstalled(installed);
      }
      if (!mounted) return;
      scheduleForjaSyncPush();
      await ref.read(enginePacksProvider.notifier).reload();
      unawaited(ref.read(enginePackUpdatesProvider.notifier).refresh());
      if (ok > 0) {
        ForjaToast.success(
          ok == 1 ? '1 pack downloaded' : '$ok packs downloaded',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _engineInstalling = false;
          _endBulkPackOp();
        });
      }
    }
  }

  Future<void> _updateAllEnginePacks(
    Map<String, EnginePackUpdateInfo> updates,
  ) async {
    if (updates.isEmpty || _engineUpdatingAll) return;
    final allPacks =
        ref.read(enginePacksProvider).valueOrNull ?? const <EnginePack>[];
    setState(() {
      _engineUpdatingAll = true;
      _beginBulkPackOp(allPacks);
    });
    var ok = 0;
    try {
      for (final entry in updates.values) {
        try {
          await PluginInstallCoordinator.instance.installManifest(
            entry.sourceUrl,
            isUpdate: true,
          );
          ok++;
        } catch (e) {
          if (!mounted) return;
          ForjaToast.error('${entry.packName} update failed: $e');
        }
      }
      if (!mounted) return;
      await ref.read(enginePacksProvider.notifier).reload();
      await ref.read(enginePackUpdatesProvider.notifier).refresh();
      if (ok > 0) {
        ForjaToast.success(ok == 1 ? '1 pack updated' : '$ok packs updated');
        PluginInstallCoordinator.instance.clearPackUpdateToast();
      }
    } finally {
      if (mounted) {
        setState(() {
          _engineUpdatingAll = false;
          _endBulkPackOp();
        });
      }
    }
  }

  /// Enable pack; if scripts are missing (cloud lean stub), download first so
  /// hub `nav` can contribute Features / rail tabs (ATV parity with desktop).
  Future<void> _togglePackEnabled(
    EnginePack pack, {
    required bool enabled,
  }) async {
    var working = pack;
    if (enabled &&
        await PluginRegistry.instance.packNeedsDiskInstall(pack)) {
      setState(() => _engineInstalling = true);
      try {
        working = await PluginInstallCoordinator.instance.installManifest(
          pack.sourceUrl,
        );
        await DeferredRemoteInstallStore.clear(pack.sourceUrl);
        PackInstallFailures.clear();
      } catch (e) {
        if (!mounted) return;
        PackInstallFailures.reportOne(
          label: pack.name,
          manifestUrl: pack.sourceUrl,
          error: e,
        );
        ForjaToast.error('Install failed — see details above');
        return;
      } finally {
        if (mounted) setState(() => _engineInstalling = false);
      }
    }
    await EngineService.instance.setPackEnabled(
      sourceUrl: pack.sourceUrl,
      enabled: enabled,
    );
    // changeNotifier already reloads enginePacksProvider + MainScreen nav.
    // activate refreshes hub destinations; deactivate only drops Features ids.
    if (enabled) {
      await PackHubFeatures.activate(working);
    } else {
      await PluginNavRegistry.refresh();
      await PackHubFeatures.deactivate(working);
    }
    if (!mounted) return;
    scheduleForjaSyncPush();
  }

  Future<void> _installNamedPack(String sourceUrl) async {
    setState(() => _engineInstalling = true);
    try {
      final pack = await PluginInstallCoordinator.instance.installManifest(
        sourceUrl,
      );
      await DeferredRemoteInstallStore.clear(sourceUrl);
      await PackHubFeatures.refreshAndActivateInstalled([pack]);
      if (!mounted) return;
      PackInstallFailures.clear();
      scheduleForjaSyncPush();
      await ref.read(enginePacksProvider.notifier).reload();
      ForjaToast.success(
        'Installed ${pack.name} (${pack.plugins.length} plugins)',
      );
    } catch (e) {
      if (!mounted) return;
      PackInstallFailures.reportOne(
        label: packInstallRefDisplayName(sourceUrl),
        manifestUrl: sourceUrl,
        error: e,
      );
      ForjaToast.error('Install failed — see details above');
    } finally {
      if (mounted) setState(() => _engineInstalling = false);
    }
  }

  Future<void> _purgePackNow(EnginePack pack) async {
    try {
      await PackHubFeatures.deactivate(pack);
      await EngineService.instance.removePack(pack.sourceUrl);
      await PendingRemotePurgeStore.clear(pack.sourceUrl);
      await PluginNavRegistry.refresh();
      if (!mounted) return;
      ShellBus.settingsHubCategoryId.value = SettingsCategoryId.forjaPacks;
      scheduleForjaSyncPush();
      await ref.read(enginePacksProvider.notifier).reload();
      ForjaToast.success('Pack uninstalled');
    } catch (e) {
      if (!mounted) return;
      ForjaToast.error('$e');
    }
  }

  Future<void> _installEnginePack() async {
    final refs = parsePackInstallRefs(_engineController.text);
    if (refs.isEmpty) return;

    if (refs.length > 1) {
      await _openPasteBatchPrompt(refs);
      return;
    }

    final url = refs.first;
    setState(() => _engineInstalling = true);
    try {
      final pack = await PluginInstallCoordinator.instance.installManifest(url);
      await PackHubFeatures.refreshAndActivateInstalled([pack]);
      if (!mounted) return;
      PackInstallFailures.clear();
      _engineController.clear();
      scheduleForjaSyncPush();
      await ref.read(enginePacksProvider.notifier).reload();
      ForjaToast.success(
        'Installed ${pack.name} (${pack.plugins.length} plugins)',
      );
    } catch (e) {
      if (!mounted) return;
      PackInstallFailures.reportOne(
        label: packInstallRefDisplayName(url),
        manifestUrl: url,
        error: e,
      );
      ForjaToast.error('Install failed — see details above');
    } finally {
      if (mounted) setState(() => _engineInstalling = false);
    }
  }

  Future<void> _openPasteBatchPrompt(List<String> refs) async {
    final packs = await PluginRegistry.instance.listPacksRaw();
    if (!mounted) return;
    final installedUrls = <String>{};
    for (final p in packs) {
      if (p.plugins.isEmpty) continue;
      if (await PluginRegistry.instance.packNeedsDiskInstall(p)) continue;
      installedUrls.add(p.sourceUrl.trim());
    }
    if (!mounted) return;

    final candidates = <PluginInstallCandidate>[
      for (final url in refs)
        PluginInstallCandidate(
          manifestUrl: url,
          displayName: packInstallRefDisplayName(url),
          alreadyInstalled: installedUrls.contains(url),
        ),
    ];

    _engineController.clear();
    SettingsPackPromptDrill.open(
      PluginBatchInstallPrompt(candidates: candidates),
    );
  }

  Future<void> _removeEnginePack(EnginePack pack) async {
    try {
      await PackHubFeatures.deactivate(pack);
      await EngineService.instance.removePack(pack.sourceUrl);
      await PendingRemotePurgeStore.clear(pack.sourceUrl);
      await DeferredRemoteInstallStore.clear(pack.sourceUrl);
      await PluginNavRegistry.refresh();
      if (!mounted) return;
      // Stay on Forja Packs — remove used to invalidate the list (empty flash)
      // and navbar storms could promote away from Settings.
      ShellBus.settingsHubCategoryId.value = SettingsCategoryId.forjaPacks;
      scheduleForjaSyncPush();
      await ref.read(enginePacksProvider.notifier).reload();
      ForjaToast.success('Pack removed');
    } catch (e) {
      if (!mounted) return;
      ForjaToast.error('$e');
    }
  }
}

class _EnginePackActions extends StatefulWidget {
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
  State<_EnginePackActions> createState() => _EnginePackActionsState();
}

class _EnginePackActionsState extends State<_EnginePackActions> {
  bool _hovered = false;

  bool get _chromeActive => _hovered;

  @override
  Widget build(BuildContext context) {
    final hasUpdate = widget.update != null;
    final leanback = ShellScope.inputPolicyOf(context).leanbackOnly;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leanback)
          // Header OK toggles enable — switch is chrome only.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: IgnorePointer(
              child: Switch(
                value: widget.packEnabled,
                scale: Switch.settingsScale,
                onChanged: null,
                emphasized: false,
              ),
            ),
          )
        else
          MouseRegion(
            onEnter: (_) {
              if (_hovered) return;
              setState(() => _hovered = true);
            },
            onExit: (_) {
              if (!_hovered) return;
              setState(() => _hovered = false);
            },
            cursor: SystemMouseCursors.click,
            child: Switch(
              value: widget.packEnabled,
              scale: Switch.settingsScale,
              onChanged: (v) => widget.onTogglePack(v),
              emphasized: _chromeActive,
            ),
          ),
        if (widget.showOfficialBadge)
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
              ? 'Update to v${widget.update!.remoteVersion}'
              : 'Refresh',
          icon: hasUpdate ? Icons.system_update_rounded : Icons.refresh_rounded,
          onPressed: widget.onRefresh,
          color: hasUpdate
              ? ForjaShellColors.brandGreen
              : ForjaShellColors.textPrimary,
        ),
        _AddonRemoveActions(onRemove: widget.onRemove),
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
      showFocusRail: false,
      showFocusFill: true,
      showFocusBorder: true,
      tvTabId: 'settings',
      tvZone: ShellTvZone.settings,
      ensureVisibleMode: ShellPaintEnsureVisible.item,
      child: SizedBox(width: 40, height: 40, child: Center(child: child)),
    );
  }
  return IconButton(tooltip: tooltip, onPressed: onPressed, icon: child);
}

class _AddonRemoveActions extends StatefulWidget {
  const _AddonRemoveActions({required this.onRemove});

  final Future<void> Function() onRemove;

  @override
  State<_AddonRemoveActions> createState() => _AddonRemoveActionsState();
}

class _AddonRemoveActionsState extends State<_AddonRemoveActions> {
  bool _confirming = false;

  Future<void> _confirm() async {
    setState(() => _confirming = false);
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
            onPressed: () => setState(() => _confirming = false),
          ),
        ],
      );
    }
    return _settingsTvIconButton(
      context,
      tooltip: 'Remove pack',
      icon: Icons.delete_outline,
      color: const Color(0xFFF87171),
      onPressed: () => setState(() => _confirming = true),
    );
  }
}

/// Session-only install errors at the top of Settings → Forja Packs.
class _PackInstallFailuresBanner extends StatelessWidget {
  const _PackInstallFailuresBanner({required this.failures});

  final List<PackInstallFailure> failures;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF7F1D1D).withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF87171).withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.error_outline_rounded,
              size: 18,
              color: Color(0xFFF87171),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  failures.length == 1
                      ? 'Pack install failed'
                      : '${failures.length} packs failed to install',
                  style: const TextStyle(
                    color: Color(0xFFFECACA),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                for (var i = 0; i < failures.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  Text(
                    failures[i].label,
                    style: const TextStyle(
                      color: ForjaShellColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (failures[i].manifestUrl.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      failures[i].manifestUrl,
                      style: TextStyle(
                        color: ForjaShellColors.textSecondary.withValues(
                          alpha: 0.9,
                        ),
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    failures[i].message,
                    style: const TextStyle(
                      color: Color(0xFFFECACA),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 4),
          _settingsTvIconButton(
            context,
            tooltip: 'Dismiss',
            icon: Icons.close_rounded,
            color: ForjaShellColors.iconMuted,
            onPressed: PackInstallFailures.clear,
          ),
        ],
      ),
    );
  }
}
