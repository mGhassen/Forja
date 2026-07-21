import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/player/controls/player_chrome_overlays.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:forja/shared/widgets/media_details/torrent_source_tiles.dart';
import 'package:forja/shared/widgets/media_details/torrent_sources_panel.dart';
import 'package:rust/rust.dart';

/// Right-side panel to pick another file inside the active torrent.
///
/// Same shell + source cards as media-details [TorrentSourcesPanel].
/// Pass [frozenFrame] (player screenshot) for frosted glass without
/// BackdropFilter on the live video texture.
class PlayerTorrentFilePanel {
  static OverlayEntry? _entry;
  static Completer<void>? _completer;

  static bool get isShowing => _entry != null;

  static void dismiss() {
    final wasShowing = _entry != null;
    _entry?.remove();
    _entry = null;
    _completer?.complete();
    _completer = null;
    if (wasShowing) playerMenuRestoreReturnFocus();
  }

  static Future<void> show({
    required BuildContext context,
    required String magnetLink,
    required int? currentFileIndex,
    required Future<void> Function(TorrentFileEntry file) onFileSelected,
    Uint8List? frozenFrame,
  }) {
    playerMenuCaptureReturnFocus(context);
    dismiss();
    PlayerPopupPanel.dismiss();
    playerChromeCancelSeekScrubs();

    final overlay = Overlay.of(context);
    _completer = Completer<void>();

    _entry = OverlayEntry(
      builder: (_) => ShellScopeBuilder(
        builder: (context, _) => _TorrentFilePanelOverlay(
          magnetLink: magnetLink,
          currentFileIndex: currentFileIndex,
          onFileSelected: onFileSelected,
          onClose: dismiss,
          frozenFrame: frozenFrame,
        ),
      ),
    );

    overlay.insert(_entry!);
    return _completer!.future;
  }
}

class _TorrentFilePanelOverlay extends StatefulWidget {
  const _TorrentFilePanelOverlay({
    required this.magnetLink,
    required this.currentFileIndex,
    required this.onFileSelected,
    required this.onClose,
    this.frozenFrame,
  });

  final String magnetLink;
  final int? currentFileIndex;
  final Future<void> Function(TorrentFileEntry file) onFileSelected;
  final VoidCallback onClose;
  final Uint8List? frozenFrame;

  @override
  State<_TorrentFilePanelOverlay> createState() =>
      _TorrentFilePanelOverlayState();
}

class _TorrentFilePanelOverlayState extends State<_TorrentFilePanelOverlay> {
  bool _open = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _open = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return playerOverlayShell(
      context: context,
      isOpen: _open,
      onClose: widget.onClose,
      enableBlur: false,
      frozenFrame: widget.frozenFrame,
      child: _TorrentFilePanelBody(
        magnetLink: widget.magnetLink,
        currentFileIndex: widget.currentFileIndex,
        onFileSelected: widget.onFileSelected,
        onClose: widget.onClose,
      ),
    );
  }
}

class _TorrentFilePanelBody extends StatefulWidget {
  const _TorrentFilePanelBody({
    required this.magnetLink,
    required this.currentFileIndex,
    required this.onFileSelected,
    required this.onClose,
  });

  final String magnetLink;
  final int? currentFileIndex;
  final Future<void> Function(TorrentFileEntry file) onFileSelected;
  final VoidCallback onClose;

  @override
  State<_TorrentFilePanelBody> createState() => _TorrentFilePanelBodyState();
}

class _TorrentFilePanelBodyState extends State<_TorrentFilePanelBody> {
  final _scrollController = ScrollController();
  List<TorrentFileEntry>? _files;
  String? _error;
  bool _loading = true;
  int? _switchingIndex;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFiles() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final files =
          await TorrentStreamService().listTorrentFiles(widget.magnetLink);
      if (!mounted) return;
      if (files == null || files.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'No files found in this torrent.';
        });
        return;
      }
      setState(() {
        _files = files;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _scrollToCurrent() {
    final files = _files;
    final current = widget.currentFileIndex;
    if (files == null || current == null || !_scrollController.hasClients) {
      return;
    }
    final index = files.indexWhere((f) => f.index == current);
    if (index < 0) return;
    const rowHeight = 88.0;
    final offset =
        (index * rowHeight).clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _select(TorrentFileEntry file) async {
    if (file.index == widget.currentFileIndex) {
      widget.onClose();
      return;
    }
    if (!file.isStreamable) return;
    setState(() => _switchingIndex = file.index);
    try {
      await widget.onFileSelected(file);
      widget.onClose();
    } catch (_) {
      if (mounted) setState(() => _switchingIndex = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _files?.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlayerSidePanelHeader(
          title: 'Torrent files',
          onClose: widget.onClose,
          badge: count?.toString(),
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ForjaShellColors.cinematic.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _loadFiles,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final files = _files!;
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      itemCount: files.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
        final file = files[i];
        final isCurrent = file.index == widget.currentFileIndex;
        final isSwitching = _switchingIndex == file.index;
        final enabled = file.isStreamable && _switchingIndex == null;

        return TorrentFileSourceTile(
          fileName: file.name,
          sizeBytes: file.size,
          isCurrent: isCurrent,
          isSwitching: isSwitching,
          enabled: enabled,
          onPlay: () => _select(file),
        );
      },
    );
  }
}
