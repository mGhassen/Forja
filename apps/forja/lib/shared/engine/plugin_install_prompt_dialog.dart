import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/engine/plugin_install_coordinator.dart';
import 'package:forja/shared/engine/plugin_install_prompt.dart';
import 'package:forja/shared/engine/plugin_registry.dart';
import 'package:forja/shared/engine/remote_pack_intent_store.dart';
import 'package:forja/shared/sync/src/sync_domain_bridge.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';

/// Full-screen confirm overlay for a remote plugin pack (deep link / profile sync).
class PluginInstallPromptOverlay extends StatelessWidget {
  const PluginInstallPromptOverlay({
    super.key,
    required this.prompt,
    required this.alreadyInstalled,
    required this.onDismiss,
  });

  final PluginInstallPrompt prompt;
  final bool alreadyInstalled;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return TvOverlayScope(
      debugLabel: prompt.kind == PluginPackPromptKind.uninstall
          ? 'plugin-uninstall-prompt'
          : 'plugin-install-prompt',
      onDismiss: onDismiss,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ModalBarrier(
            dismissible: false,
            color: Color(0x9E000000),
          ),
          Center(
            child: _PluginInstallPromptBody(
              prompt: prompt,
              alreadyInstalled: alreadyInstalled,
              onCancel: onDismiss,
              onConfirm: onDismiss,
            ),
          ),
        ],
      ),
    );
  }
}

class _PluginInstallPromptBody extends StatefulWidget {
  const _PluginInstallPromptBody({
    required this.prompt,
    required this.alreadyInstalled,
    required this.onCancel,
    required this.onConfirm,
  });

  final PluginInstallPrompt prompt;
  final bool alreadyInstalled;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  State<_PluginInstallPromptBody> createState() =>
      _PluginInstallPromptBodyState();
}

class _PluginInstallPromptBodyState extends State<_PluginInstallPromptBody> {
  final FocusNode _cancelFocus = FocusNode(debugLabel: 'plugin-install-cancel');
  final FocusNode _confirmFocus =
      FocusNode(debugLabel: 'plugin-install-confirm');
  final FocusNode _laterFocus = FocusNode(debugLabel: 'plugin-install-later');
  bool _busy = false;

  bool get _uninstall =>
      widget.prompt.kind == PluginPackPromptKind.uninstall;
  bool get _remote =>
      widget.prompt.source == PluginInstallSource.remoteProfile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ShellScope.metricsOf(context).usesTvDensity) return;
      final node = widget.alreadyInstalled ? _cancelFocus : _confirmFocus;
      if (node.canRequestFocus) node.requestFocus();
    });
  }

  @override
  void dispose() {
    _cancelFocus.dispose();
    _confirmFocus.dispose();
    _laterFocus.dispose();
    super.dispose();
  }

  Future<void> _install() async {
    if (_busy || widget.alreadyInstalled) return;
    setState(() => _busy = true);
    try {
      await PluginInstallCoordinator.instance.installManifest(
        widget.prompt.manifestUrl,
      );
      await DeferredRemoteInstallStore.clear(widget.prompt.manifestUrl);
      scheduleForjaSyncPush();
      if (!mounted) return;
      widget.onConfirm();
    } catch (e) {
      if (!mounted) return;
      ForjaToast.error('Install failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uninstallNow() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await PluginRegistry.instance.removePack(widget.prompt.manifestUrl);
      await PendingRemotePurgeStore.clear(widget.prompt.manifestUrl);
      if (!mounted) return;
      widget.onConfirm();
    } catch (e) {
      if (!mounted) return;
      ForjaToast.error('Uninstall failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deferInstall() async {
    if (_busy) return;
    await DeferredRemoteInstallStore.defer(widget.prompt.manifestUrl);
    if (!mounted) return;
    widget.onCancel();
  }

  Future<void> _deferUninstall() async {
    if (_busy) return;
    await PendingRemotePurgeStore.defer(widget.prompt.manifestUrl);
    if (!mounted) return;
    widget.onCancel();
  }

  String get _title {
    if (widget.alreadyInstalled) {
      return _uninstall ? 'Already removed' : 'Already installed';
    }
    if (_uninstall) return 'Uninstall on this device?';
    if (_remote) return 'Install on this device?';
    return 'Install plugin pack?';
  }

  String get _body {
    if (widget.alreadyInstalled) {
      return _uninstall
          ? 'This pack is not on this device.'
          : 'This pack is already on this device. Open Settings → '
              'Forja Packs to refresh or remove it.';
    }
    if (_uninstall) {
      return 'This pack was removed from your profile. Uninstall it here? '
          'Playback using it should finish first.';
    }
    if (_remote) {
      return 'This pack was added to your profile from another device. '
          'Download and validate it here?';
    }
    return 'Forja will download and validate this manifest. '
        'Only install packs you trust.';
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.prompt.displayName?.trim().isNotEmpty == true
        ? widget.prompt.displayName!.trim()
        : 'Plugin pack';
    final settled = widget.alreadyInstalled;

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
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: ForjaShellColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _body,
              style: const TextStyle(
                color: ForjaShellColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ForjaShellColors.borderSubtle),
              ),
              child: Text(
                widget.prompt.manifestUrl,
                style: const TextStyle(
                  color: ForjaShellColors.textSecondary,
                  fontFamily: 'monospace',
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (!settled)
              ForjaButton.primary(
                label: _busy
                    ? (_uninstall ? 'Uninstalling…' : 'Installing…')
                    : (_uninstall ? 'Uninstall' : 'Install pack'),
                expand: true,
                autofocus: true,
                focusNode: _confirmFocus,
                activateOnKeyUp: true,
                onPressed: _busy
                    ? null
                    : (_uninstall ? _uninstallNow : _install),
              ),
            if (!settled && _remote) ...[
              const SizedBox(height: 4),
              Center(
                child: ForjaGhostButton(
                  label: _uninstall ? 'After this session' : 'Not now',
                  focusNode: _laterFocus,
                  onTap: _uninstall ? _deferUninstall : _deferInstall,
                ),
              ),
            ],
            if (!settled) const SizedBox(height: 4),
            Center(
              child: ForjaGhostButton(
                label: settled ? 'Close' : 'Cancel',
                focusNode: _cancelFocus,
                onTap: widget.onCancel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
