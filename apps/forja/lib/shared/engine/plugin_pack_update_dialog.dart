import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/engine/models.dart';
import 'package:forja/shared/engine/plugin_install_coordinator.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';

/// Confirm overlay listing plugin packs with pending version bumps.
class PluginPackUpdateOverlay extends StatelessWidget {
  const PluginPackUpdateOverlay({
    super.key,
    required this.updates,
    required this.onDismiss,
  });

  final List<EnginePackUpdateInfo> updates;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return TvOverlayScope(
      debugLabel: 'plugin-pack-update',
      onDismiss: onDismiss,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ModalBarrier(
            dismissible: false,
            color: Color(0x9E000000),
          ),
          Center(
            child: _PluginPackUpdateBody(
              updates: updates,
              onCancel: onDismiss,
              onDone: onDismiss,
            ),
          ),
        ],
      ),
    );
  }
}

class _PluginPackUpdateBody extends StatefulWidget {
  const _PluginPackUpdateBody({
    required this.updates,
    required this.onCancel,
    required this.onDone,
  });

  final List<EnginePackUpdateInfo> updates;
  final VoidCallback onCancel;
  final VoidCallback onDone;

  @override
  State<_PluginPackUpdateBody> createState() => _PluginPackUpdateBodyState();
}

class _PluginPackUpdateBodyState extends State<_PluginPackUpdateBody> {
  final FocusNode _cancelFocus = FocusNode(debugLabel: 'plugin-update-cancel');
  final FocusNode _confirmFocus =
      FocusNode(debugLabel: 'plugin-update-confirm');
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ShellScope.metricsOf(context).usesTvDensity) return;
      if (_confirmFocus.canRequestFocus) _confirmFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _cancelFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || widget.updates.isEmpty) return;
    setState(() => _busy = true);
    try {
      final ok = await PluginInstallCoordinator.instance.updatePacks(
        widget.updates,
      );
      if (!mounted) return;
      if (ok > 0) {
        ForjaToast.success(
          ok == 1 ? '1 plugin pack updated' : '$ok plugin packs updated',
        );
      }
      widget.onDone();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.updates.length;
    final title = count == 1
        ? 'Update plugin pack?'
        : 'Update $count plugin packs?';

    return AlertDialog(
      backgroundColor: ForjaShellColors.cinematic.menuSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: ForjaShellColors.borderSubtle),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: ForjaShellColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              count == 1
                  ? 'Download and install the newer version of this pack.'
                  : 'Download and install newer versions of these packs.',
              style: const TextStyle(
                color: ForjaShellColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ForjaShellColors.borderSubtle),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.updates.length,
                  separatorBuilder: (_, _) => const Divider(
                    height: 1,
                    color: ForjaShellColors.borderSubtle,
                  ),
                  itemBuilder: (context, i) {
                    final u = widget.updates[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              u.packName,
                              style: const TextStyle(
                                color: ForjaShellColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Text(
                            'v${u.installedVersion} → v${u.remoteVersion}',
                            style: const TextStyle(
                              color: ForjaShellColors.textSecondary,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            ForjaButton.primary(
              label: _busy ? 'Updating…' : (count == 1 ? 'Update' : 'Update all'),
              expand: true,
              autofocus: true,
              focusNode: _confirmFocus,
              activateOnKeyUp: true,
              onPressed: _busy ? null : _submit,
            ),
            const SizedBox(height: 4),
            Center(
              child: ForjaGhostButton(
                label: 'Cancel',
                focusNode: _cancelFocus,
                onTap: _busy ? null : widget.onCancel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
