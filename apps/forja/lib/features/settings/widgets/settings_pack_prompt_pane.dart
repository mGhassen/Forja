import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/features/settings/widgets/settings_ui.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/engine/plugin_install_coordinator.dart';
import 'package:forja/shared/engine/plugin_install_prompt.dart';
import 'package:forja/shared/engine/plugin_registry.dart';
import 'package:forja/shared/engine/remote_pack_intent_store.dart';
import 'package:forja/shared/sync/src/sync_domain_bridge.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/widgets/shell_focusable_tap.dart';

/// Open pack install/uninstall picker inside Settings → Forja Packs (right pane).
///
/// Same drill pattern as [SettingsAddonDrill] — never a modal dialog.
class SettingsPackPromptDrill {
  static final ValueNotifier<PluginBatchInstallPrompt?> current =
      ValueNotifier<PluginBatchInstallPrompt?>(null);

  static void open(PluginBatchInstallPrompt prompt) {
    current.value = prompt;
  }

  static void close() => current.value = null;

  static bool get isOpen => current.value != null;

  /// Back / category change / Not now — defer remote rows, then close.
  static Future<void> dismissWithoutApply() async {
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
    _selected = {
      for (final c in widget.prompt.candidates)
        if (!c.alreadyInstalled) _key(c),
    };
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
        if (c.kind == PluginPackPromptKind.uninstall) {
          await registry.removePack(url);
          await PendingRemotePurgeStore.clear(url);
        } else {
          await coordinator.installManifest(url);
          await DeferredRemoteInstallStore.clear(url);
        }
      }
      scheduleForjaSyncPush();
      if (!mounted) return;
      widget.onDismiss();
    } catch (e) {
      if (!mounted) return;
      ForjaToast.error('Pack sync failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _notNow() async {
    if (_busy) return;
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
          'Choose what to apply here — the rest can wait in Forja Packs.';
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

/// Flat checkbox row — no card chrome (matches pending pack tiles).
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

  @override
  Widget build(BuildContext context) {
    final settled = candidate.alreadyInstalled;
    final uninstall = candidate.kind == PluginPackPromptKind.uninstall;
    final title = candidate.displayName?.trim().isNotEmpty == true
        ? candidate.displayName!.trim()
        : 'Plugin pack';
    final actionLabel = uninstall ? 'Uninstall' : 'Install';
    final settledLabel = uninstall ? 'Already removed' : 'Already on device';
    final subtitle = settled
        ? settledLabel
        : '$actionLabel · ${candidate.manifestUrl.trim()}';

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
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TV: row owns focus — Checkbox must not steal a second node.
          ExcludeFocus(excluding: tv, child: checkbox),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: settled
                        ? ForjaShellColors.textSecondary
                        : ForjaShellColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: settled ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ForjaShellColors.textSecondary,
                    fontSize: 11,
                    fontFamily: 'monospace',
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
