import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/engine/plugin_install_coordinator.dart';
import 'package:forja/shared/engine/plugin_install_prompt.dart';
import 'package:forja/shared/sync/src/sync_domain_bridge.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';

/// Full-screen batch confirm — pick which profile packs to install on device.
class PluginBatchInstallPromptOverlay extends StatelessWidget {
  const PluginBatchInstallPromptOverlay({
    super.key,
    required this.prompt,
    required this.onDismiss,
  });

  final PluginBatchInstallPrompt prompt;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return TvOverlayScope(
      debugLabel: 'plugin-batch-install-prompt',
      onDismiss: onDismiss,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ModalBarrier(
            dismissible: false,
            color: Color(0x9E000000),
          ),
          Center(
            child: _PluginBatchInstallPromptBody(
              prompt: prompt,
              onDismiss: onDismiss,
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
  });

  final PluginBatchInstallPrompt prompt;
  final VoidCallback onDismiss;

  @override
  State<_PluginBatchInstallPromptBody> createState() =>
      _PluginBatchInstallPromptBodyState();
}

class _PluginBatchInstallPromptBodyState
    extends State<_PluginBatchInstallPromptBody> {
  late Set<String> _selected;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _selected = {
      for (final c in widget.prompt.candidates)
        if (!c.alreadyInstalled) c.manifestUrl.trim(),
    };
  }

  int get _selectedNewCount => widget.prompt.candidates
      .where(
        (c) =>
            !c.alreadyInstalled && _selected.contains(c.manifestUrl.trim()),
      )
      .length;

  Iterable<PluginInstallCandidate> get _installable =>
      widget.prompt.candidates.where((c) => !c.alreadyInstalled);

  void _selectAllNew() {
    setState(() {
      for (final c in _installable) {
        _selected.add(c.manifestUrl.trim());
      }
    });
  }

  void _clearNew() {
    setState(() {
      for (final c in _installable) {
        _selected.remove(c.manifestUrl.trim());
      }
    });
  }

  Future<void> _installSelected() async {
    if (_busy || _selectedNewCount == 0) return;
    setState(() => _busy = true);
    try {
      final coordinator = PluginInstallCoordinator.instance;
      for (final c in widget.prompt.candidates) {
        final url = c.manifestUrl.trim();
        if (c.alreadyInstalled || !_selected.contains(url)) continue;
        await coordinator.installManifest(url);
      }
      scheduleForjaSyncPush();
      if (!mounted) return;
      widget.onDismiss();
    } catch (e) {
      if (!mounted) return;
      ForjaToast.error('Install failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final installable = _installable.toList();
    final allNewSelected =
        installable.isNotEmpty &&
        installable.every((c) => _selected.contains(c.manifestUrl.trim()));

    return AlertDialog(
      backgroundColor: ForjaShellColors.cinematic.menuSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: ForjaShellColors.borderSubtle),
      ),
      title: const Text(
        'Install plugin packs?',
        style: TextStyle(
          color: ForjaShellColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Choose which packs to download on this device. '
              'Profile sync keeps the full list — you can install the rest later '
              'in Settings → Forja plugins.',
              style: const TextStyle(
                color: ForjaShellColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '$_selectedNewCount to install',
                  style: const TextStyle(
                    color: ForjaShellColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _busy || allNewSelected ? null : _selectAllNew,
                  child: const Text('Select all new'),
                ),
                TextButton(
                  onPressed: _busy || _selectedNewCount == 0 ? null : _clearNew,
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.prompt.candidates.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: ForjaShellColors.borderSubtle),
                itemBuilder: (context, index) {
                  final c = widget.prompt.candidates[index];
                  final url = c.manifestUrl.trim();
                  final installed = c.alreadyInstalled;
                  final checked = installed || _selected.contains(url);
                  final title = c.displayName?.trim().isNotEmpty == true
                      ? c.displayName!.trim()
                      : 'Plugin pack';

                  return CheckboxListTile(
                    value: checked,
                    onChanged: installed || _busy
                        ? null
                        : (value) {
                            setState(() {
                              if (value == true) {
                                _selected.add(url);
                              } else {
                                _selected.remove(url);
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
                        color: installed
                            ? ForjaShellColors.textSecondary
                            : ForjaShellColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      installed ? 'Already on device' : url,
                      maxLines: installed ? 1 : 2,
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
              label: _busy
                  ? 'Installing…'
                  : _selectedNewCount == 1
                      ? 'Install 1 pack'
                      : 'Install $_selectedNewCount packs',
              expand: true,
              autofocus: true,
              activateOnKeyUp: true,
              onPressed: _busy || _selectedNewCount == 0 ? null : _installSelected,
            ),
            const SizedBox(height: 4),
            Center(
              child: ForjaGhostButton(
                label: 'Not now',
                onTap: _busy ? null : widget.onDismiss,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
