import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/player/controls/player_chrome_overlays.dart';
import 'package:forja/shared/player/controls/player_episode_panel.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:forja/shared/player/controls/player_sources_panel.dart';
import 'package:forja/shared/player/controls/player_stream_menu.dart';
import 'package:forja/shared/player/controls/player_torrent_file_panel.dart';
import 'package:forja/shared/player/exo/exo_player_bridge.dart';
import 'package:forja/shared/player/player/utils.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/utils/language_display.dart';
import 'package:forja/shared/widgets/media_details/torrent_sources_panel.dart';

/// Two-column Subtitles dialog — left groups, right tracks in the group.
///
/// Same chrome as [PlayerServerStreamDialog] (Sources). Used by ExoPlayer.
class PlayerSubtitleDialog {
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

  static Future<void> show(
    BuildContext context, {
    required ExoTracksSnapshot tracks,
    required Future<void> Function(ExoTrackInfo track) onSelectEmbedded,
    required Future<void> Function() onOff,
    List<Map<String, dynamic>> externalSubtitles = const [],
    String? selectedExternalSubUrl,
    bool isFetchingSubs = false,
    Future<void> Function(Map<String, dynamic> sub)? onSelectExternal,
    Future<void> Function({required String path, required String name})?
        onLoadFromFile,
  }) async {
    playerMenuCaptureReturnFocus(context);
    dismiss();
    PlayerPopupPanel.dismiss();
    PlayerStreamMenu.dismiss();
    PlayerEpisodePanel.dismiss();
    PlayerHubEpisodePanel.dismiss();
    PlayerSourcesPanel.dismiss();
    PlayerTorrentFilePanel.dismiss();
    playerChromeCancelSeekScrubs();

    final overlay = Overlay.of(context);
    _completer = Completer<void>();

    void close() => dismiss();

    _entry = OverlayEntry(
      builder: (_) => ShellScopeBuilder(
        builder: (ctx, _) => _SubtitleDialogOverlay(
          tracks: tracks,
          onSelectEmbedded: onSelectEmbedded,
          onOff: onOff,
          externalSubtitles: externalSubtitles,
          selectedExternalSubUrl: selectedExternalSubUrl,
          isFetchingSubs: isFetchingSubs,
          onSelectExternal: onSelectExternal,
          onLoadFromFile: onLoadFromFile,
          onClose: close,
        ),
      ),
    );

    overlay.insert(_entry!);
    return _completer!.future;
  }
}

enum _SubGroupKind { off, embedded, language, loadFile }

class _SubGroup {
  const _SubGroup({
    required this.kind,
    required this.id,
    required this.label,
    this.value,
    this.langKey,
  });

  final _SubGroupKind kind;
  final String id;
  final String label;
  final String? value;
  final String? langKey;
}

class _SubtitleDialogOverlay extends StatefulWidget {
  const _SubtitleDialogOverlay({
    required this.tracks,
    required this.onSelectEmbedded,
    required this.onOff,
    required this.externalSubtitles,
    required this.selectedExternalSubUrl,
    required this.isFetchingSubs,
    required this.onClose,
    this.onSelectExternal,
    this.onLoadFromFile,
  });

  final ExoTracksSnapshot tracks;
  final Future<void> Function(ExoTrackInfo track) onSelectEmbedded;
  final Future<void> Function() onOff;
  final List<Map<String, dynamic>> externalSubtitles;
  final String? selectedExternalSubUrl;
  final bool isFetchingSubs;
  final Future<void> Function(Map<String, dynamic> sub)? onSelectExternal;
  final Future<void> Function({required String path, required String name})?
      onLoadFromFile;
  final VoidCallback onClose;

  @override
  State<_SubtitleDialogOverlay> createState() => _SubtitleDialogOverlayState();
}

class _SubtitleDialogOverlayState extends State<_SubtitleDialogOverlay> {
  final bool _open = true;
  late String _selectedGroupId;
  late final Map<String, List<Map<String, dynamic>>> _byLang;
  late final List<_SubGroup> _groups;

  bool get _textOff =>
      widget.tracks.textOff ||
      (widget.tracks.text.every((t) => !t.selected) &&
          widget.selectedExternalSubUrl == null);

  @override
  void initState() {
    super.initState();
    _byLang = <String, List<Map<String, dynamic>>>{};
    for (final s in widget.externalSubtitles) {
      final key = languageGroupKey(
        (s['language'] ?? s['lang'])?.toString(),
      );
      _byLang.putIfAbsent(key, () => []).add(s);
    }
    final folderKeys = _byLang.keys.toList()..sort(compareLanguageCodes);

    _groups = [
      const _SubGroup(kind: _SubGroupKind.off, id: 'off', label: 'Off'),
      if (widget.tracks.text.isNotEmpty)
        _SubGroup(
          kind: _SubGroupKind.embedded,
          id: 'embedded',
          label: 'In-stream',
          value: '${widget.tracks.text.length}',
        ),
      for (final key in folderKeys)
        _SubGroup(
          kind: _SubGroupKind.language,
          id: 'lang:$key',
          label: languageDisplayName(key),
          value: '${_byLang[key]!.length}',
          langKey: key,
        ),
      if (widget.onLoadFromFile != null)
        const _SubGroup(
          kind: _SubGroupKind.loadFile,
          id: 'load-file',
          label: 'Load from file',
          value: 'SRT · VTT',
        ),
    ];

    _selectedGroupId = _initialGroupId();
  }

  String _initialGroupId() {
    final selectedUrl = widget.selectedExternalSubUrl;
    if (selectedUrl != null) {
      for (final entry in _byLang.entries) {
        if (entry.value.any((s) => s['url'] == selectedUrl)) {
          return 'lang:${entry.key}';
        }
      }
    }
    if (!_textOff && widget.tracks.text.any((t) => t.selected)) {
      return 'embedded';
    }
    if (_textOff) return 'off';
    if (widget.tracks.text.isNotEmpty) return 'embedded';
    for (final g in _groups) {
      if (g.kind == _SubGroupKind.language) return g.id;
    }
    return _groups.first.id;
  }

  _SubGroup get _selectedGroup =>
      _groups.firstWhere((g) => g.id == _selectedGroupId, orElse: () => _groups.first);

  Future<void> _pickFile() async {
    final load = widget.onLoadFromFile;
    if (load == null) return;
    // Dismiss before the native picker — overlays block the sheet.
    PlayerSubtitleDialog.dismiss();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['srt', 'vtt'],
    );
    if (result == null || result.files.single.path == null) return;
    await load(
      path: result.files.single.path!,
      name: result.files.single.name,
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 8, 0),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: ForjaShellColors.cinematic.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildGroupsColumn() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 12),
      children: [
        for (final g in _groups)
          PlayerPopupListTile(
            label: g.label,
            subtitle: g.kind == _SubGroupKind.loadFile ? g.value : null,
            trailing: g.kind != _SubGroupKind.loadFile && g.value != null
                ? Text(
                    g.value!,
                    style: const TextStyle(
                      color: PlayerPopupTokens.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : null,
            selected: g.id == _selectedGroupId,
            onTap: () {
              if (g.kind == _SubGroupKind.loadFile) {
                unawaited(_pickFile());
                return;
              }
              setState(() => _selectedGroupId = g.id);
            },
          ),
      ],
    );
  }

  Widget _buildTracksColumn() {
    final group = _selectedGroup;
    if (widget.isFetchingSubs && group.kind == _SubGroupKind.language) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: PlayerPopupTokens.accent,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Searching subtitles…',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      );
    }

    switch (group.kind) {
      case _SubGroupKind.off:
        return ListView(
          padding: const EdgeInsets.fromLTRB(6, 8, 10, 12),
          children: [
            PlayerPopupListTile(
              label: 'Subtitles off',
              selected: _textOff,
              onTap: () async {
                PlayerSubtitleDialog.dismiss();
                await widget.onOff();
              },
            ),
          ],
        );
      case _SubGroupKind.embedded:
        final tracks = widget.tracks.text;
        if (tracks.isEmpty) {
          return const Center(
            child: Text(
              'No in-stream tracks',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(6, 8, 10, 12),
          children: [
            for (final t in tracks)
              PlayerPopupListTile(
                label: formatPlayerTrackLabel(
                  id: t.id,
                  title: t.label,
                  language: t.language,
                ),
                selected: widget.selectedExternalSubUrl == null &&
                    !widget.tracks.textOff &&
                    t.selected,
                onTap: () async {
                  PlayerSubtitleDialog.dismiss();
                  await widget.onSelectEmbedded(t);
                },
              ),
          ],
        );
      case _SubGroupKind.language:
        final langKey = group.langKey ?? '';
        final subs = _byLang[langKey] ?? const <Map<String, dynamic>>[];
        if (subs.isEmpty) {
          return const Center(
            child: Text(
              'No tracks',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(6, 8, 10, 12),
          children: [
            for (final s in subs)
              PlayerPopupListTile(
                label: s['display']?.toString() ??
                    languageDisplayName(langKey),
                subtitle: (s['translated'] == true ? 'Translated · ' : '') +
                    (s['sourceName']?.toString() ?? 'opensubtitles'),
                selected: s['url'] == widget.selectedExternalSubUrl,
                onTap: () async {
                  await widget.onSelectExternal?.call(s);
                  PlayerSubtitleDialog.dismiss();
                },
              ),
          ],
        );
      case _SubGroupKind.loadFile:
        return Center(
          child: TextButton(
            onPressed: () => unawaited(_pickFile()),
            child: const Text(
              'Choose SRT or VTT file',
              style: TextStyle(color: PlayerPopupTokens.accent),
            ),
          ),
        );
    }
  }

  Widget _buildBody() {
    final group = _selectedGroup;
    final tracksTitle = switch (group.kind) {
      _SubGroupKind.off => 'Tracks · Off',
      _SubGroupKind.embedded => 'Tracks · In-stream',
      _SubGroupKind.language => 'Tracks · ${group.label}',
      _SubGroupKind.loadFile => 'Load from file',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlayerSidePanelHeader(
          title: 'Subtitles',
          onClose: widget.onClose,
          leading: Icon(
            Icons.subtitles_outlined,
            color: ForjaShellColors.cinematic.textSecondary,
            size: 18,
          ),
        ),
        if (widget.isFetchingSubs)
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 0, 14, 4),
            child: LinearProgressIndicator(
              color: Colors.white54,
              backgroundColor: Colors.white10,
              minHeight: 2,
            ),
          ),
        Expanded(
          // Independent columns: ↑/↓ stay in-column; ←/→ cross the divider.
          child: ShellTvDisableLinearFocus(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: FocusTraversalGroup(
                    policy: WidgetOrderTraversalPolicy(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _sectionLabel('Groups'),
                        Expanded(child: _buildGroupsColumn()),
                      ],
                    ),
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: PlayerPopupTokens.border,
                ),
                Expanded(
                  flex: 6,
                  child: FocusTraversalGroup(
                    policy: WidgetOrderTraversalPolicy(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _sectionLabel(tracksTitle),
                        Expanded(child: _buildTracksColumn()),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tv = playerTvUsesCenteredDialogs(context);
    if (!tv) {
      return playerOverlayShell(
        context: context,
        isOpen: _open,
        onClose: widget.onClose,
        enableBlur: false,
        child: _buildBody(),
      );
    }

    if (!_open) return const SizedBox.shrink();
    final size = MediaQuery.sizeOf(context);
    final width = (size.width * 0.88).clamp(560.0, 960.0);
    final maxHeight = size.height * 0.82;

    return PlayerPopupPanel.tvFocusableOverlay(
      overlayContext: context,
      onDismiss: widget.onClose,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onClose,
              behavior: HitTestBehavior.opaque,
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.62)),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Material(
                type: MaterialType.transparency,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: width,
                    maxHeight: maxHeight,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: PlayerPopupTokens.shellBg,
                      borderRadius: BorderRadius.circular(
                        PlayerPopupTokens.shellRadius,
                      ),
                      border: Border.all(color: PlayerPopupTokens.border),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        PlayerPopupTokens.shellRadius,
                      ),
                      child: playerSidePanelTvScope(
                        context: context,
                        onClose: widget.onClose,
                        child: _buildBody(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
