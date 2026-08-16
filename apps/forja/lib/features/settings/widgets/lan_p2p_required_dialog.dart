import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/features/settings/settings_catalog.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/tv/tv_focus_graph.dart';
import 'package:forja/shell/shell_bus.dart';

/// Pair / desktop-offline prompt. [OverlayEntry] so it stacks above player
/// Sources (also an OverlayEntry) — [showDialog] lands behind that panel.
class LanP2pRequiredDialog {
  static OverlayEntry? _entry;
  static Completer<bool>? _completer;

  static bool get isShowing => _entry != null;

  static bool dismissIfShowing() {
    if (_entry == null) return false;
    dismiss();
    return true;
  }

  static void dismiss({bool openLan = false}) {
    if (_entry == null) return;
    _entry?.remove();
    _entry = null;
    final c = _completer;
    _completer = null;
    if (c != null && !c.isCompleted) c.complete(openLan);
  }

  static Future<bool> show(
    BuildContext context, {
    required bool neverPaired,
  }) {
    dismiss();
    final overlay = Overlay.of(context, rootOverlay: true);
    _completer = Completer<bool>();
    _entry = OverlayEntry(
      builder: (_) => ShellScopeBuilder(
        builder: (ctx, _) => TvOverlayScope(
          debugLabel: 'lan-p2p-required',
          onDismiss: dismiss,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ModalBarrier(
                dismissible: false,
                color: Color(0x9E000000),
              ),
              Center(
                child: _LanP2pRequiredDialog(
                  neverPaired: neverPaired,
                  onOpenLan: () => dismiss(openLan: true),
                  onCancel: dismiss,
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

Future<void> showLanP2pRequiredDialog(
  BuildContext context, {
  required bool neverPaired,
}) async {
  final openLan = await LanP2pRequiredDialog.show(
    context,
    neverPaired: neverPaired,
  );
  if (openLan != true) return;
  ShellBus.openSettings(categoryId: SettingsCategoryId.lan);
}

class _LanP2pRequiredDialog extends StatefulWidget {
  const _LanP2pRequiredDialog({
    required this.neverPaired,
    required this.onOpenLan,
    required this.onCancel,
  });

  final bool neverPaired;
  final VoidCallback onOpenLan;
  final VoidCallback onCancel;

  @override
  State<_LanP2pRequiredDialog> createState() => _LanP2pRequiredDialogState();
}

class _LanP2pRequiredDialogState extends State<_LanP2pRequiredDialog> {
  final FocusNode _cancelFocus = FocusNode(debugLabel: 'lan-p2p-cancel');
  final FocusNode _confirmFocus = FocusNode(debugLabel: 'lan-p2p-open-lan');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ShellScope.inputPolicyOf(context).useFocusableMoodChips) return;
      if (_confirmFocus.canRequestFocus) _confirmFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _cancelFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final neverPaired = widget.neverPaired;
    return AlertDialog(
      backgroundColor: ForjaShellColors.cinematic.menuSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: ForjaShellColors.borderSubtle),
      ),
      title: Text(
        neverPaired ? 'Pair a desktop' : 'Desktop offline',
        style: const TextStyle(
          color: ForjaShellColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              neverPaired
                  ? 'Torrents and other P2P streams play on a desktop Forja server, '
                      'not on this TV. Direct HTTP streams still play here. '
                      'Pair once in Settings → LAN.'
                  : 'Torrents and other P2P streams need your paired desktop Forja '
                      'server on the same Wi-Fi. Direct HTTP streams still play '
                      'on this TV.',
              style: const TextStyle(
                color: ForjaShellColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ForjaButton.primary(
              label: 'Open LAN',
              expand: true,
              autofocus: true,
              focusNode: _confirmFocus,
              onPressed: widget.onOpenLan,
            ),
            const SizedBox(height: 4),
            Center(
              child: ForjaGhostButton(
                label: neverPaired ? 'Cancel' : 'Close',
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
