import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:rust/rust.dart';

const _kP2pBullets = [
  'Your IP address will be visible to other peers in the network',
  'You are solely responsible for the content you access',
  'You confirm you have the legal right to stream this content in your jurisdiction',
  'Forja does not host, distribute, or control any P2P content',
  'Forja bears no liability for any legal consequences arising from your use of P2P streaming',
];

/// Returns true if already acknowledged, or the user accepted the dialog.
Future<bool> ensureP2pStreamingAcknowledged(BuildContext context) async {
  final settings = SettingsService();
  if (await settings.isP2pStreamingAcknowledged()) return true;
  if (!context.mounted) return false;
  final accepted = await showP2pStreamingAckDialog(context);
  if (accepted) {
    await settings.setP2pStreamingAcknowledged(true);
  }
  return accepted;
}

Future<bool> showP2pStreamingAckDialog(
  BuildContext context, {
  bool reviewOnly = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: reviewOnly,
    builder: (ctx) => ShellScope.rehost(
      context,
      _P2pStreamingAckDialog(reviewOnly: reviewOnly),
    ),
  );
  return result == true;
}

class _P2pStreamingAckDialog extends StatefulWidget {
  const _P2pStreamingAckDialog({this.reviewOnly = false});

  final bool reviewOnly;

  @override
  State<_P2pStreamingAckDialog> createState() => _P2pStreamingAckDialogState();
}

class _P2pStreamingAckDialogState extends State<_P2pStreamingAckDialog> {
  final FocusNode _cancelFocus = FocusNode(debugLabel: 'p2p-ack-cancel');
  final FocusNode _confirmFocus = FocusNode(debugLabel: 'p2p-ack-enable');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ShellScope.metricsOf(context).usesTvDensity) return;
      final node = widget.reviewOnly ? _confirmFocus : _cancelFocus;
      if (node.canRequestFocus) node.requestFocus();
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
    return AlertDialog(
      backgroundColor: ForjaShellColors.cinematic.menuSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: ForjaShellColors.borderSubtle),
      ),
      title: const Text(
        'P2P Streaming',
        style: TextStyle(
          color: ForjaShellColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 460),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const _VpnRecommendBanner(),
              const SizedBox(height: 14),
              const Text(
                'This stream uses peer-to-peer (P2P) technology. By continuing, you confirm you are aware that:',
                style: TextStyle(
                  color: ForjaShellColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              for (final line in _kP2pBullets) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '•  ',
                        style: TextStyle(
                          color: ForjaShellColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          line,
                          style: const TextStyle(
                            color: ForjaShellColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 4),
              const Text(
                'You use this feature entirely at your own risk. Direct torrent, Stremio, and Nuvio can be turned off anytime in Settings.',
                style: TextStyle(
                  color: ForjaShellColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (!widget.reviewOnly)
          ForjaButton(
            label: 'Cancel',
            focusNode: _cancelFocus,
            onPressed: () => Navigator.pop(context, false),
          ),
        ForjaButton.primary(
          label: widget.reviewOnly ? 'Close' : 'I am aware',
          focusNode: _confirmFocus,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
  }
}

class _VpnRecommendBanner extends StatelessWidget {
  const _VpnRecommendBanner();

  static const _amber = Color(0xFFFBBF24);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _amber.withValues(alpha: 0.35)),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.vpn_lock_rounded, size: 18, color: _amber),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'For better privacy, use a VPN. Your IP address is visible to other peers.',
                style: TextStyle(
                  color: ForjaShellColors.textPrimary,
                  height: 1.35,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
