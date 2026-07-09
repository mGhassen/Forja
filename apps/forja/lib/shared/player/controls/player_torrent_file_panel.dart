import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:rust/rust.dart';

/// Right-side sliding panel to pick another file inside the active torrent.
class PlayerTorrentFilePanel {
  static OverlayEntry? _entry;
  static Completer<void>? _completer;

  static bool get isShowing => _entry != null;

  static void dismiss() {
    _entry?.remove();
    _entry = null;
    _completer?.complete();
    _completer = null;
  }

  static Future<void> show({
    required BuildContext context,
    required String magnetLink,
    required int? currentFileIndex,
    required Future<void> Function(TorrentFileEntry file) onFileSelected,
  }) {
    dismiss();
    PlayerPopupPanel.dismiss();

    final overlay = Overlay.of(context);
    _completer = Completer<void>();

    _entry = OverlayEntry(
      builder: (_) => _TorrentFilePanelOverlay(
        magnetLink: magnetLink,
        currentFileIndex: currentFileIndex,
        onFileSelected: onFileSelected,
        onClose: dismiss,
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
  });

  final String magnetLink;
  final int? currentFileIndex;
  final Future<void> Function(TorrentFileEntry file) onFileSelected;
  final VoidCallback onClose;

  @override
  State<_TorrentFilePanelOverlay> createState() =>
      _TorrentFilePanelOverlayState();
}

class _TorrentFilePanelOverlayState extends State<_TorrentFilePanelOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _slide = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final panelWidth = screenWidth < 700 ? screenWidth * 0.92 : 420.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: widget.onClose,
          behavior: HitTestBehavior.opaque,
          child: const ColoredBox(color: Colors.black54),
        ),
        SlideTransition(
          position: _slide,
          child: Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: panelWidth,
              child: Material(
                color: ForjaShellColors.cinematic.menuSurface,
                child: SafeArea(
                  left: false,
                  child: _TorrentFilePanelBody(
                    magnetLink: widget.magnetLink,
                    currentFileIndex: widget.currentFileIndex,
                    onFileSelected: widget.onFileSelected,
                    onClose: widget.onClose,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
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
    const rowHeight = 72.0;
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

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  IconData _fileIcon(TorrentFileEntry file) {
    if (file.isStreamable) return Icons.movie_outlined;
    final lower = file.name.toLowerCase();
    if (lower.endsWith('.srt') ||
        lower.endsWith('.ass') ||
        lower.endsWith('.sub') ||
        lower.endsWith('.vtt')) {
      return Icons.subtitles_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Icon(
                Icons.link_rounded,
                color: ForjaShellColors.cinematic.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Torrent files',
                  style: TextStyle(
                    color: ForjaShellColors.cinematic.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              ForjaCloseButton(
                color: ForjaShellColors.cinematic.textSecondary,
                onTap: widget.onClose,
              ),
            ],
          ),
        ),
        Divider(height: 1, color: ForjaShellColors.cinematic.borderSubtle),
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
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: files.length,
      itemBuilder: (context, i) {
        final file = files[i];
        final isCurrent = file.index == widget.currentFileIndex;
        final isSwitching = _switchingIndex == file.index;
        final enabled = file.isStreamable && _switchingIndex == null;

        return InkWell(
          onTap: enabled ? () => _select(file) : null,
          child: Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            color: isCurrent
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.transparent,
            child: Row(
              children: [
                Icon(
                  _fileIcon(file),
                  size: 22,
                  color: file.isStreamable
                      ? ForjaShellColors.cinematic.textPrimary
                      : ForjaShellColors.cinematic.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: file.isStreamable
                              ? ForjaShellColors.cinematic.textPrimary
                              : ForjaShellColors.cinematic.textSecondary,
                          fontSize: 13,
                          fontWeight:
                              isCurrent ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatSize(file.size),
                        style: TextStyle(
                          color: ForjaShellColors.cinematic.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSwitching)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white54,
                    ),
                  )
                else if (isCurrent)
                  Icon(
                    Icons.play_circle_filled_rounded,
                    color: ForjaShellColors.cinematic.textPrimary,
                    size: 20,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
