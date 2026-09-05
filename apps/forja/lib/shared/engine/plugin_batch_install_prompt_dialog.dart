import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/engine/plugin_install_coordinator.dart';
import 'package:forja/shared/engine/plugin_install_prompt.dart';
import 'package:forja/shared/engine/plugin_registry.dart';
import 'package:forja/shared/engine/remote_pack_intent_store.dart';
import 'package:forja/shared/sync/src/sync_domain_bridge.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';

/// Full-screen batch confirm — pick which profile packs to install/uninstall.
class PluginBatchInstallPromptOverlay extends StatefulWidget {
  const PluginBatchInstallPromptOverlay({
    super.key,
    required this.prompt,
    required this.onDismiss,
  });

  final PluginBatchInstallPrompt prompt;
  final VoidCallback onDismiss;

  @override
  State<PluginBatchInstallPromptOverlay> createState() =>
      _PluginBatchInstallPromptOverlayState();
}

class _PluginBatchInstallPromptOverlayState
    extends State<PluginBatchInstallPromptOverlay> {
  bool _closing = false;

  /// Escape / back / Not now — defer remote rows so Settings keeps
  /// Install later / Removed-from-profile badges.
  Future<void> _dismissWithoutApply() async {
    if (_closing) return;
    _closing = true;
    try {
      for (final c in widget.prompt.candidates) {
        if (c.alreadyInstalled || !c.fromRemoteProfile) continue;
        final url = c.manifestUrl.trim();
        if (url.isEmpty) continue;
        if (c.kind == PluginPackPromptKind.uninstall) {
          await PendingRemotePurgeStore.defer(url);
        } else {
          await DeferredRemoteInstallStore.defer(url);
        }
      }
    } finally {
      if (mounted) widget.onDismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    return TvOverlayScope(
      debugLabel: 'plugin-batch-install-prompt',
      onDismiss: () => unawaited(_dismissWithoutApply()),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ModalBarrier(
            dismissible: false,
            color: Color(0x9E000000),
          ),
          Center(
            child: _PluginBatchInstallPromptBody(
              prompt: widget.prompt,
              onDismiss: widget.onDismiss,
              onDismissWithoutApply: _dismissWithoutApply,
            ),
          ),
        ],
      ),
    );
  }
}

class _PluginBatchInstallPromptBody extends StatefulWidget {
  const _PluginBatchInstallPromptBody({
    required this.prompt,
    required this.onDismiss,
    required this.onDismissWithoutApply,
  });

  final PluginBatchInstallPrompt prompt;
  final VoidCallback onDismiss;
  final Future<void> Function() onDismissWithoutApply;

  @override
  State<_PluginBatchInstallPromptBody> createState() =>
      _PluginBatchInstallPromptBodyState();
}

class _PluginBatchInstallPromptBodyState
    extends State<_PluginBatchInstallPromptBody> {
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
      await widget.onDismissWithoutApply();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _title {
    final remote = widget.prompt.hasRemoteProfile;
    final hasInstall = widget.prompt.candidates
        .any((c) => c.kind == PluginPackPromptKind.install);
    final hasUninstall = widget.prompt.candidates
        .any((c) => c.kind == PluginPackPromptKind.uninstall);
    if (remote && hasInstall && hasUninstall) {
      return 'Sync packs on this device?';
    }
    if (remote && hasUninstall && !hasInstall) {
      return 'Uninstall on this device?';
    }
    if (remote) return 'Install on this device?';
    return 'Install plugin packs?';
  }

  String get _body {
    if (widget.prompt.hasRemoteProfile) {
      return 'These packs changed on your profile from another device. '
          'Choose what to apply here — the rest can wait in Settings → Forja Packs.';
    }
    return 'Choose which packs to download on this device. '
        'You can install the rest later in Settings → Forja Packs.';
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

    return AlertDialog(
      backgroundColor: ForjaShellColors.cinematic.menuSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: ForjaShellColors.borderSubtle),
      ),
      title: Text(
        _title,
        style: const TextStyle(
          color: ForjaShellColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 420),
        // Fixed height so Expanded gets real space. Column(min)+Flexible
        // collapsed the list to 0 → "Cannot hit test a render box with no size".
        child: SizedBox(
          width: 520,
          height: 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _body,
                style: const TextStyle(
                  color: ForjaShellColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
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
                  TextButton(
                    onPressed:
                        _busy || allSelected ? null : _selectAllActionable,
                    child: const Text('Select all'),
                  ),
                  TextButton(
                    onPressed: _busy || _selectedCount == 0
                        ? null
                        : _clearActionable,
                    child: const Text('Clear'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(
                child: ListView.separated(
                  itemCount: widget.prompt.candidates.length,
                  separatorBuilder: (_, _) => const Divider(
                    height: 1,
                    color: ForjaShellColors.borderSubtle,
                  ),
                  itemBuilder: (context, index) {
                    final c = widget.prompt.candidates[index];
                    final key = _key(c);
                    final settled = c.alreadyInstalled;
                    final checked = settled || _selected.contains(key);
                    final title = c.displayName?.trim().isNotEmpty == true
                        ? c.displayName!.trim()
                        : 'Plugin pack';
                    final uninstall = c.kind == PluginPackPromptKind.uninstall;
                    final actionLabel = uninstall ? 'Uninstall' : 'Install';
                    final settledLabel =
                        uninstall ? 'Already removed' : 'Already on device';

                    return CheckboxListTile(
                      value: checked,
                      onChanged: settled || _busy
                          ? null
                          : (value) {
                              setState(() {
                                if (value == true) {
                                  _selected.add(key);
                                } else {
                                  _selected.remove(key);
                                }
                              });
                            },
                      activeColor: ForjaShellColors.brandGreen,
                      checkColor: const Color(0xFF0B0A0A),
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                      title: Text(
                        title,
                        style: TextStyle(
                          color: settled
                              ? ForjaShellColors.textSecondary
                              : ForjaShellColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        settled
                            ? settledLabel
                            : '$actionLabel · ${c.manifestUrl.trim()}',
                        maxLines: settled ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ForjaShellColors.textSecondary,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              ForjaButton.primary(
                label: _primaryLabel,
                expand: true,
                autofocus: true,
                activateOnKeyUp: true,
                onPressed:
                    _busy || _selectedCount == 0 ? null : _applySelected,
              ),
              const SizedBox(height: 4),
              Center(
                child: ForjaGhostButton(
                  label: 'Not now',
                  onTap: _busy ? null : _notNow,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
