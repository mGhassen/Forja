import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/catalog/plugin_nav.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/engine/models.dart';
import 'package:forja/shared/engine/plugin_install_coordinator.dart';
import 'package:forja/shared/engine/plugin_install_prompt.dart';
import 'package:forja/shared/engine/plugin_registry.dart';
import 'package:forja/shared/engine/remote_pack_intent_store.dart';
import 'package:forja/shared/sync/src/sync_domain_bridge.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';
import 'package:rust/rust.dart';

/// Open pack install/uninstall picker inside Settings → Forja Packs (right pane).
///
/// Same drill pattern as [SettingsAddonDrill] — never a modal dialog.
class SettingsPackPromptDrill {
  static final ValueNotifier<PluginBatchInstallPrompt?> current =
      ValueNotifier<PluginBatchInstallPrompt?>(null);

  /// True while Install / Apply is downloading — Back must not tear this down.
  static final ValueNotifier<bool> applying = ValueNotifier<bool>(false);

  static void open(PluginBatchInstallPrompt prompt) {
    current.value = prompt;
  }

  static void close() {
    applying.value = false;
    current.value = null;
  }

  static bool get isOpen => current.value != null;

  static bool get isApplying => applying.value;

  /// Back / category change / Not now — defer remote rows, then close.
  /// No-op while [isApplying] so a mid-download Back cannot abort the batch.
  static Future<void> dismissWithoutApply() async {
    if (isApplying) {
      debugPrint('[PackPrompt] dismiss ignored — install in progress');
      return;
    }
    final prompt = current.value;
    if (prompt == null) return;
    for (final c in prompt.candidates) {
      if (c.alreadyInstalled || !c.fromRemoteProfile) continue;
      final url = c.manifestUrl.trim();
      if (url.isEmpty) continue;
      if (c.kind == PluginPackPromptKind.uninstall) {
        await PendingRemotePurgeStore.defer(url);
      } else {
        await DeferredRemoteInstallStore.defer(url);
      }
    }
    close();
  }

  static String titleFor(PluginBatchInstallPrompt prompt) {
    final remote = prompt.hasRemoteProfile;
    final hasInstall =
        prompt.candidates.any((c) => c.kind == PluginPackPromptKind.install);
    final hasUninstall =
        prompt.candidates.any((c) => c.kind == PluginPackPromptKind.uninstall);
    if (remote && hasInstall && hasUninstall) return 'Sync packs';
    if (remote && hasUninstall && !hasInstall) return 'Uninstall packs';
    if (remote) return 'Install packs';
    return 'Install packs';
  }
}

/// Flat checkbox list for batch install/uninstall — fills the Settings detail pane.
class SettingsPackPromptPane extends StatefulWidget {
  const SettingsPackPromptPane({
    super.key,
    required this.prompt,
    required this.onDismiss,
  });

  final PluginBatchInstallPrompt prompt;
  final VoidCallback onDismiss;

  @override
  State<SettingsPackPromptPane> createState() => _SettingsPackPromptPaneState();
}

class _SettingsPackPromptPaneState extends State<SettingsPackPromptPane> {
  late Set<String> _selected;
  bool _busy = false;

  String _key(PluginInstallCandidate c) =>
      '${c.kind.name}|${c.manifestUrl.trim()}';

  @override
  void initState() {
    super.initState();
    // User picks packs — do not pre-check every actionable row.
    _selected = {};
  }

  Iterable<PluginInstallCandidate> get _actionable =>
      widget.prompt.candidates.where((c) => !c.alreadyInstalled);

  int get _selectedInstallCount => widget.prompt.candidates
      .where(
        (c) =>
            c.kind == PluginPackPromptKind.install &&
            !c.alreadyInstalled &&
            _selected.contains(_key(c)),
      )
      .length;

  int get _selectedUninstallCount => widget.prompt.candidates
      .where(
        (c) =>
            c.kind == PluginPackPromptKind.uninstall &&
            !c.alreadyInstalled &&
            _selected.contains(_key(c)),
      )
      .length;

  int get _selectedCount => _selectedInstallCount + _selectedUninstallCount;

  void _selectAllActionable() {
    setState(() {
      for (final c in _actionable) {
        _selected.add(_key(c));
      }
    });
  }

  void _clearActionable() {
    setState(() {
      for (final c in _actionable) {
        _selected.remove(_key(c));
      }
    });
  }

  Future<void> _deferRemote(PluginInstallCandidate c) async {
    if (!c.fromRemoteProfile) return;
    final url = c.manifestUrl.trim();
    if (c.kind == PluginPackPromptKind.install) {
      await DeferredRemoteInstallStore.defer(url);
    } else {
      await PendingRemotePurgeStore.defer(url);
    }
  }

  Future<void> _applySelected() async {
    if (_busy || _selectedCount == 0) return;
    setState(() => _busy = true);
    SettingsPackPromptDrill.applying.value = true;
    var installed = 0;
    var removed = 0;
    final failures = <String>[];
    try {
      final coordinator = PluginInstallCoordinator.instance;
      final registry = PluginRegistry.instance;
      for (final c in widget.prompt.candidates) {
        final url = c.manifestUrl.trim();
        final key = _key(c);
        if (c.alreadyInstalled) continue;
        if (!_selected.contains(key)) {
          await _deferRemote(c);
          continue;
        }
        final label = c.displayName?.trim().isNotEmpty == true
            ? c.displayName!.trim()
            : url;
        try {
          if (c.kind == PluginPackPromptKind.uninstall) {
            debugPrint('[PackPrompt] uninstall $label');
            await registry.removePack(url);
            await PendingRemotePurgeStore.clear(url);
            removed++;
          } else {
            debugPrint('[PackPrompt] install $label → $url');
            final pack = await coordinator.installManifest(url);
            await DeferredRemoteInstallStore.clear(url);
            installed++;
            debugPrint('[PackPrompt] install ok $label');
            await _activatePackHubFeatures(pack);
          }
        } catch (e) {
          debugPrint('[PackPrompt] failed $label: $e');
          failures.add(label);
        }
      }
      // Always refresh hub nav even if the pane was torn down (Back / remount).
      await PluginNavRegistry.refresh();
      scheduleForjaSyncPush();
      if (!mounted) return;
      if (failures.isEmpty) {
        final bits = <String>[
          if (installed > 0)
            installed == 1 ? '1 pack installed' : '$installed packs installed',
          if (removed > 0)
            removed == 1 ? '1 pack removed' : '$removed packs removed',
        ];
        if (bits.isNotEmpty) ForjaToast.success(bits.join(' · '));
      } else {
        ForjaToast.error(
          'Pack sync: ${failures.length} failed'
          '${installed > 0 ? ', $installed ok' : ''}'
          ' (${failures.take(2).join(', ')}'
          '${failures.length > 2 ? '…' : ''})',
        );
      }
      widget.onDismiss();
    } finally {
      SettingsPackPromptDrill.applying.value = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _activatePackHubFeatures(EnginePack pack) async {
    final settings = SettingsService();
    final tabs = <String>[];
    for (final pl in pack.plugins) {
      if (!pl.isHubCatalog || !pl.enabled) continue;
      final spec = CatalogNavSpec.fromPluginNav(
        pl.nav,
        pluginId: pl.id,
        fallbackLabel: pl.name,
      );
      if (spec == null || !spec.isValid) continue;
      if (SettingsService.addonGatedNavIds.contains(spec.tabId)) continue;
      tabs.add(spec.tabId);
    }
    if (tabs.isEmpty) return;
    noteNavigationDirty();
    for (final id in tabs) {
      await settings.setNavbarTabVisible(id, true);
    }
    await scheduleNavigationSyncPush();
  }

  Future<void> _notNow() async {
    if (_busy || SettingsPackPromptDrill.isApplying) return;
    setState(() => _busy = true);
    try {
      await SettingsPackPromptDrill.dismissWithoutApply();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _body {
    if (widget.prompt.hasRemoteProfile) {
      return 'These packs changed on your profile from another device. '
          'Choose what to apply here. The rest can wait in Forja Packs.';
    }
    return 'Choose which packs to download on this device. '
        'You can install the rest later from this page.';
  }

  String get _primaryLabel {
    if (_busy) return 'Working…';
    final i = _selectedInstallCount;
    final u = _selectedUninstallCount;
    if (i > 0 && u > 0) {
      return 'Apply ($i install · $u uninstall)';
    }
    if (u > 0) {
      return u == 1 ? 'Uninstall 1 pack' : 'Uninstall $u packs';
    }
    return i == 1 ? 'Install 1 pack' : 'Install $i packs';
  }

  @override
  Widget build(BuildContext context) {
    final actionable = _actionable.toList();
    final allSelected = actionable.isNotEmpty &&
        actionable.every((c) => _selected.contains(_key(c)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _body,
          style: TextStyle(
            color: ForjaShellColors.textSecondary.withValues(alpha: 0.9),
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Text(
              '$_selectedCount selected',
              style: const TextStyle(
                color: ForjaShellColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const Spacer(),
            SettingsTextAction(
              label: 'Select all',
              onPressed: _busy || allSelected ? null : _selectAllActionable,
            ),
            SettingsTextAction(
              label: 'Clear',
              onPressed: _busy || _selectedCount == 0 ? null : _clearActionable,
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (var i = 0; i < widget.prompt.candidates.length; i++) ...[
          if (i > 0)
            const Divider(height: 1, color: ForjaShellColors.borderSubtle),
          _PackPromptRow(
            candidate: widget.prompt.candidates[i],
            checked: widget.prompt.candidates[i].alreadyInstalled ||
                _selected.contains(_key(widget.prompt.candidates[i])),
            enabled:
                !widget.prompt.candidates[i].alreadyInstalled && !_busy,
            onChanged: (value) {
              final key = _key(widget.prompt.candidates[i]);
              setState(() {
                if (value) {
                  _selected.add(key);
                } else {
                  _selected.remove(key);
                }
              });
            },
          ),
        ],
        const SizedBox(height: 20),
        SettingsFilledButton(
          label: _primaryLabel,
          icon: Icons.download_rounded,
          busy: _busy,
          expand: true,
          onPressed: _busy || _selectedCount == 0
              ? null
              : () => unawaited(_applySelected()),
        ),
        const SizedBox(height: 8),
        Center(
          child: SettingsTextAction(
            label: 'Not now',
            color: ForjaShellColors.textSecondary,
            onPressed: _busy ? null : () => unawaited(_notNow()),
          ),
        ),
      ],
    );
  }
}

/// Flat checkbox row — no card chrome (matches Community Packs list rows).
class _PackPromptRow extends StatelessWidget {
  const _PackPromptRow({
    required this.candidate,
    required this.checked,
    required this.enabled,
    required this.onChanged,
  });

  final PluginInstallCandidate candidate;
  final bool checked;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  static String _labelize(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    return t
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final settled = candidate.alreadyInstalled;
    final uninstall = candidate.kind == PluginPackPromptKind.uninstall;
    final title = candidate.displayName?.trim().isNotEmpty == true
        ? candidate.displayName!.trim()
        : 'Plugin pack';
    final actionLabel = uninstall ? 'Uninstall' : 'Install';
    final settledLabel = uninstall ? 'Already removed' : 'Already on device';
    final desc = candidate.description?.trim();
    final tagsLine = candidate.tags
        .map(_labelize)
        .where((t) => t.isNotEmpty)
        .join(' · ');
    final version = candidate.version?.trim();
    final muted = settled
        ? ForjaShellColors.textSecondary
        : ForjaShellColors.textPrimary;

    void flip() {
      if (!enabled) return;
      onChanged(!checked);
    }

    final tv = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final checkbox = SizedBox(
      width: 28,
      height: 28,
      child: Checkbox(
        value: checked,
        onChanged: enabled ? (v) => onChanged(v == true) : null,
        activeColor: ForjaShellColors.brandGreen,
        checkColor: const Color(0xFF0B0A0A),
        side: BorderSide(
          color: ForjaShellColors.borderSubtle.withValues(alpha: 0.9),
        ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TV: row owns focus — Checkbox must not steal a second node.
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: ExcludeFocus(excluding: tv, child: checkbox),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        candidate.official ? 'ForjaHQ' : 'Community',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ForjaShellColors.textSecondary
                              .withValues(alpha: 0.55),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    if (candidate.official) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: ForjaShellColors.brandGreen
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: ForjaShellColors.brandGreen
                                .withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Text(
                          'Official',
                          style: TextStyle(
                            color: ForjaShellColors.brandGreen,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                    if (candidate.recommended) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4D1C)
                              .withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: const Color(0xFFFF4D1C)
                                .withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Text(
                          'Recommended',
                          style: TextStyle(
                            color: Color(0xFFFF4D1C),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                    if (version != null && version.isNotEmpty) ...[
                      const Spacer(),
                      Text(
                        version.startsWith('v') ? version : 'v$version',
                        style: TextStyle(
                          color: ForjaShellColors.textSecondary
                              .withValues(alpha: 0.55),
                          fontSize: 10,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  style: TextStyle(
                    color: muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (tagsLine.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    tagsLine.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ForjaShellColors.textSecondary
                          .withValues(alpha: 0.45),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
                const SizedBox(height: 3),
                Text(
                  settled
                      ? settledLabel
                      : (desc != null && desc.isNotEmpty)
                          ? desc
                          : actionLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ForjaShellColors.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (!tv || !enabled) return row;

    return shellFocusableTap(
      context: context,
      onTap: flip,
      borderRadius: SettingsTokens.categoryTileRadius,
      scaleOnFocus: 1.0,
      showFocusRail: true,
      tvTabId: 'settings',
      tvZone: ShellTvZone.settings,
      ensureVisibleMode: ShellTvEnsureVisibleMode.item,
      child: row,
    );
  }
}
