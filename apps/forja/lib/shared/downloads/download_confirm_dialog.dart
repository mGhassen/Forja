import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/downloads/download_path_helper.dart';
import 'package:forja/shared/downloads/download_size_probe.dart';
import 'package:forja/shared/downloads/storage_space_helper.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';
import 'package:forja_foundation/components/button.dart';
import 'package:forja_foundation/components/dialog.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

/// Probe size + free space, then ask the user to confirm before enqueue.
///
/// Returns `true` when the user confirms. Cancel / dismiss → `false`.
Future<bool> confirmOfflineDownload({
  required BuildContext context,
  required String title,
  String? sourceName,
  required String url,
  Map<String, String>? headers,
}) async {
  if (!context.mounted) return false;
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      Widget dialog = _DownloadConfirmDialog(
        title: title,
        sourceName: sourceName,
        url: url,
        headers: headers,
      );
      final hostPaint = ShellPaintScope.maybeOf(context);
      if (hostPaint != null) {
        dialog = ShellPaintScope(
          useTvFocus: hostPaint.useTvFocus,
          scaleOnHover: hostPaint.scaleOnHover,
          usesTvDensity: hostPaint.usesTvDensity,
          focusStyled: hostPaint.focusStyled,
          focusableTapBuilder: hostPaint.focusableTapBuilder,
          wrapTvRow: hostPaint.wrapTvRow,
          wrapHorizontalScroller: hostPaint.wrapHorizontalScroller,
          absorbHorizontalScroll: hostPaint.absorbHorizontalScroll,
          isActivateKey: hostPaint.isActivateKey,
          child: dialog,
        );
      }
      if (ShellScope.maybeOf(context) != null) {
        dialog = ShellScope.rehost(context, dialog);
      }
      return dialog;
    },
  );
  return result == true;
}

class _DownloadConfirmDialog extends StatefulWidget {
  const _DownloadConfirmDialog({
    required this.title,
    this.sourceName,
    required this.url,
    this.headers,
  });

  final String title;
  final String? sourceName;
  final String url;
  final Map<String, String>? headers;

  @override
  State<_DownloadConfirmDialog> createState() => _DownloadConfirmDialogState();
}

class _DownloadConfirmDialogState extends State<_DownloadConfirmDialog> {
  var _probing = true;
  DownloadSizeProbeResult? _probe;
  StorageSpaceInfo? _space;
  var _enoughSpace = true;

  static bool _isBlockedProbe(DownloadSizeProbeResult? probe) {
    if (probe == null) return false;
    final err = probe.error?.toLowerCase() ?? '';
    return err == 'dash' || err == 'not downloadable';
  }

  @override
  void initState() {
    super.initState();
    unawaited(_runProbe());
  }

  Future<void> _runProbe() async {
    final probe = await probeDownloadSize(
      url: widget.url,
      headers: widget.headers,
    );
    StorageSpaceInfo? space;
    var enough = true;
    try {
      final dir = await DownloadPathHelper.getDownloadsDirectoryPath();
      space = await StorageSpaceHelper.getAvailableSpace(dir);
      if (probe.hasSize && space != null) {
        enough = await StorageSpaceHelper.hasEnoughSpace(dir, probe.bytes);
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _probe = probe;
      _space = space;
      _enoughSpace = enough;
      _probing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final source = widget.sourceName?.trim();
    final blocked = !_probing && _isBlockedProbe(_probe);
    final sizeLine = _probing
        ? 'Checking size…'
        : blocked
            ? (_probe?.error == 'DASH'
                ? "DASH streams can't be saved offline yet"
                : 'This stream can’t be saved offline')
            : (_probe?.sizeLabel ?? 'Size unknown');
    final freeLine = _space == null
        ? null
        : 'Free on device: ${_space!.freeFormatted}';
    final warn = !_probing && !_enoughSpace && (_probe?.hasSize ?? false);
    final canConfirm = !_probing && !warn && !blocked;

    final bodyChildren = <Widget>[
      Text(
        sizeLine,
        style: TextStyle(
          color: blocked || warn
              ? const Color(0xFFF87171)
              : ForjaShellColors.textPrimary,
          fontSize: tv ? ShellTokens.tvBodyFontSize : 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      if (source != null && source.isNotEmpty) ...[
        SizedBox(height: tv ? 4 : 6),
        Text(
          source,
          style: TextStyle(
            color: ForjaShellColors.textSecondary,
            fontSize: tv ? ShellTokens.tvMetaFontSize : 13,
          ),
        ),
      ],
      if (freeLine != null && !blocked) ...[
        SizedBox(height: tv ? 4 : 6),
        Text(
          freeLine,
          style: TextStyle(
            color: ForjaShellColors.textSecondary,
            fontSize: tv ? ShellTokens.tvMetaFontSize : 13,
          ),
        ),
      ],
      if (warn) ...[
        SizedBox(height: tv ? 6 : 8),
        Text(
          'Not enough free space for this download.',
          style: TextStyle(
            color: const Color(0xFFF87171),
            fontSize: tv ? ShellTokens.tvMetaFontSize : 13,
          ),
        ),
      ],
      if (_probing) ...[
        SizedBox(height: tv ? 10 : 14),
        const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ],
    ];

    return ForjaDialog(
      title: 'Download offline?',
      description: widget.title,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: bodyChildren,
      ),
      actions: [
        Button(
          variant: ButtonVariant.ghost,
          label: 'Cancel',
          onPressed: () => Navigator.of(context).maybePop(false),
        ),
        Button(
          variant: ButtonVariant.primary,
          label: 'Download',
          onPressed: canConfirm
              ? () => Navigator.of(context).maybePop(true)
              : null,
        ),
      ],
    );
  }
}
