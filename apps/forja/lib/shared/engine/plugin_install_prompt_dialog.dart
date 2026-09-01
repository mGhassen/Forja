import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/engine/plugin_install_coordinator.dart';
import 'package:forja/shared/engine/plugin_install_prompt.dart';
import 'package:forja/shared/sync/src/sync_domain_bridge.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';

/// Confirms a remote plugin pack before install (deep link or queued prompt).
class PluginInstallPromptDialog {
  static OverlayEntry? _entry;
  static Completer<bool>? _completer;

  static bool get isShowing => _entry != null;

  static void dismiss({bool installed = false}) {
    if (_entry == null) return;
    _entry?.remove();
    _entry = null;
    final c = _completer;
    _completer = null;
    if (c != null && !c.isCompleted) c.complete(installed);
  }

  static Future<bool> show(
    BuildContext context, {
    required PluginInstallPrompt prompt,
    bool alreadyInstalled = false,
  }) {
    dismiss();
    final overlay = Overlay.of(context, rootOverlay: true);
    _completer = Completer<bool>();
    _entry = OverlayEntry(
      builder: (_) => ShellScopeBuilder(
        builder: (ctx, _) => TvOverlayScope(
          debugLabel: 'plugin-install-prompt',
          onDismiss: dismiss,
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
                  onCancel: dismiss,
                  onConfirm: () => dismiss(installed: true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    overlay.insert(_entry!);
    return _completer!.future;
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
  bool _busy = false;

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
    super.dispose();
  }

  Future<void> _install() async {
    if (_busy || widget.alreadyInstalled) return;
    setState(() => _busy = true);
    try {
      await PluginInstallCoordinator.instance.installManifest(
        widget.prompt.manifestUrl,
      );
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

  @override
  Widget build(BuildContext context) {
    final title = widget.prompt.displayName?.trim().isNotEmpty == true
        ? widget.prompt.displayName!.trim()
        : 'Plugin pack';
    final installed = widget.alreadyInstalled;

    return AlertDialog(
      backgroundColor: ForjaShellColors.cinematic.menuSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: ForjaShellColors.borderSubtle),
      ),
      title: Text(
        installed ? 'Already installed' : 'Install plugin pack?',
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
              installed
                  ? 'This pack is already on this device. Open Settings → '
                      'Forja plugins to refresh or remove it.'
                  : 'Forja will download and validate this manifest. '
                      'Only install packs you trust.',
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
            if (!installed)
              ForjaButton.primary(
                label: _busy ? 'Installing…' : 'Install pack',
                expand: true,
                autofocus: true,
                focusNode: _confirmFocus,
                activateOnKeyUp: true,
                onPressed: _busy ? null : _install,
              ),
            if (!installed) const SizedBox(height: 4),
            Center(
              child: ForjaGhostButton(
                label: installed ? 'Close' : 'Cancel',
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
