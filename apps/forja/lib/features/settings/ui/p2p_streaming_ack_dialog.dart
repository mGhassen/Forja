import 'package:flutter/material.dart';

import 'package:rust/rust.dart';
import 'package:forja/features/settings/ui/settings_ui.dart';
import 'package:forja/shell/core/forja_shell_profile.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja/shell/tv/tv_focus_graph.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_settings_tokens.dart';

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
      TvOverlayScope(
        debugLabel: 'p2p-streaming-ack',
        // Body owns Cancel / Confirm focus with retries (settings reclaim).
        autofocusFirst: false,
        onDismiss: () => Navigator.of(ctx).pop(false),
        child: _P2pStreamingAckDialog(reviewOnly: reviewOnly),
      ),
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
    // Settings under showDialog can reclaim focus after open — claim like I173/I256.
    _claimPrimaryFocus();
  }

  void _claimPrimaryFocus({int attempt = 0}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_tvFocusActive(context)) return;
      final node = widget.reviewOnly ? _confirmFocus : _cancelFocus;
      if (node.canRequestFocus) {
        node.requestFocus();
        if (node.hasPrimaryFocus) return;
      }
      if (attempt < 4) _claimPrimaryFocus(attempt: attempt + 1);
    });
  }

  static bool _tvFocusActive(BuildContext context) {
    final policy = ShellScope.maybeOf(context)?.inputPolicy;
    return policy?.useFocusableMoodChips ??
        resolveShellProfile(context) == ShellProfile.tv;
  }

  @override
  void dispose() {
    _cancelFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Material [Button] traps ←/→ under app-root DirectionalFocus — use
    // [SettingsFilledButton] (shellFocusableTap) with explicit peer edges.
    final actions = <Widget>[
      if (!widget.reviewOnly)
        SettingsFilledButton(
          label: 'Cancel',
          secondary: true,
          focusNode: _cancelFocus,
          onPressed: () => Navigator.pop(context, false),
          onRightEdge: () {
            if (_confirmFocus.canRequestFocus) _confirmFocus.requestFocus();
          },
        ),
      SettingsFilledButton(
        label: widget.reviewOnly ? 'Close' : 'I am aware',
        focusNode: _confirmFocus,
        onPressed: () => Navigator.pop(context, true),
        onLeftEdge: widget.reviewOnly
            ? null
            : () {
                if (_cancelFocus.canRequestFocus) _cancelFocus.requestFocus();
              },
      ),
    ];

    final titleSize = SettingsTokens.pageTitleSizeOf(context);
    final bodySize = SettingsTokens.rowSubtitleSizeOf(context);
    final size = MediaQuery.sizeOf(context);
    final maxW = SettingsTokens.dialogMaxWidthOf(context, size.width);
    final maxH = SettingsTokens.dialogMaxHeightOf(context, size.height);
    final bodyStyle = TextStyle(
      color: ForjaShellColors.textSecondary,
      fontSize: bodySize,
      height: 1.4,
    );

    return AlertDialog(
      backgroundColor: ForjaShellColors.cinematic.menuSurface,
      insetPadding: SettingsTokens.dialogInsetPaddingOf(context),
      titlePadding: SettingsTokens.dialogTitlePaddingOf(context),
      contentPadding: SettingsTokens.dialogContentPaddingOf(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          SettingsTokens.dialogRadiusOf(context),
        ),
        side: const BorderSide(color: ForjaShellColors.borderSubtle),
      ),
      title: Text(
        'P2P Streaming',
        style: TextStyle(
          color: ForjaShellColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: titleSize,
        ),
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const _VpnRecommendBanner(),
              const SizedBox(height: 14),
              Text(
                'This stream uses peer-to-peer (P2P) technology. By continuing, you confirm you are aware that:',
                style: bodyStyle,
              ),
              const SizedBox(height: 12),
              for (final line in _kP2pBullets) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('•  ', style: bodyStyle),
                      Expanded(child: Text(line, style: bodyStyle)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'You use this feature entirely at your own risk. Direct torrent, Stremio, and Nuvio can be turned off anytime in Settings.',
                style: bodyStyle,
              ),
            ],
          ),
        ),
      ),
      actions: [
        // Own the row — OverflowBar + Material buttons miss TV ←/→ peers.
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              actions[i],
            ],
          ],
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
      child: Padding(
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
                  fontSize: SettingsTokens.typeSizeOf(context, 13.5),
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
