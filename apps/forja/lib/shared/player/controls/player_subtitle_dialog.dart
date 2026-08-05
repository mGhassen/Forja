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
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/utils/language_display.dart';
import 'package:forja/shared/widgets/media_details/torrent_sources_panel.dart';

/// Two-column Subtitles dialog — left languages, right tracks in the group.
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
    VoidCallback? onSubtitleSettings,
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
          onSubtitleSettings: onSubtitleSettings,
          onClose: close,
        ),
      ),
    );

    overlay.insert(_entry!);
    return _completer!.future;
  }
}

class _SubGroup {
  const _SubGroup({
    required this.id,
    required this.label,
    required this.langKey,
    required this.count,
  });

  final String id;
  final String label;
  final String langKey;
  final int count;
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
    this.onSubtitleSettings,
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
  final VoidCallback? onSubtitleSettings;
  final VoidCallback onClose;

  @override
  State<_SubtitleDialogOverlay> createState() => _SubtitleDialogOverlayState();
}

class _SubtitleDialogOverlayState extends State<_SubtitleDialogOverlay> {
  final bool _open = true;
  late String _selectedGroupId;
  late final Map<String, List<Map<String, dynamic>>> _byLangOnline;
  late final Map<String, List<ExoTrackInfo>> _byLangEmbedded;
  late final List<_SubGroup> _groups;

  bool get _textOff =>
      widget.tracks.textOff ||
      (widget.tracks.text.every((t) => !t.selected) &&
          widget.selectedExternalSubUrl == null);

  bool get _hideLoadFile =>
      ShellScope.inputPolicyOf(context).useFocusableMoodChips ||
      widget.onLoadFromFile == null;

  @override
  void initState() {
    super.initState();
    _byLangOnline = <String, List<Map<String, dynamic>>>{};
    for (final s in widget.externalSubtitles) {
      final key = languageGroupKey(
        (s['language'] ?? s['lang'])?.toString(),
      );
      _byLangOnline.putIfAbsent(key, () => []).add(s);
    }

    _byLangEmbedded = <String, List<ExoTrackInfo>>{};
    for (final t in widget.tracks.text) {
      final key = languageGroupKey(
        t.language.isNotEmpty ? t.language : t.label,
      );
      _byLangEmbedded.putIfAbsent(key, () => []).add(t);
    }

    final folderKeys = <String>{
      ..._byLangOnline.keys,
      ..._byLangEmbedded.keys,
    }.toList()
      ..sort(compareLanguageCodes);

    _groups = [
      for (final key in folderKeys)
        _SubGroup(
          id: 'lang:$key',
          label: languageDisplayName(key),
          langKey: key,
          count: (_byLangEmbedded[key]?.length ?? 0) +
              (_byLangOnline[key]?.length ?? 0),
        ),
    ];

    _selectedGroupId = _initialGroupId();
  }

  String _initialGroupId() {
    final selectedUrl = widget.selectedExternalSubUrl;
    if (selectedUrl != null) {
      for (final entry in _byLangOnline.entries) {
        if (entry.value.any((s) => s['url'] == selectedUrl)) {
          return 'lang:${entry.key}';
        }
      }
    }
    if (!_textOff) {
      for (final entry in _byLangEmbedded.entries) {
        if (entry.value.any((t) => t.selected)) {
          return 'lang:${entry.key}';
        }
      }
    }
    if (_groups.isNotEmpty) return _groups.first.id;
    return '';
  }

  _SubGroup? get _selectedGroup {
    if (_groups.isEmpty) return null;
    for (final g in _groups) {
      if (g.id == _selectedGroupId) return g;
    }
    return _groups.first;
  }

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

  Widget _headerChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    final tvFocus = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final face = Container(
      height: 28,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: selected ? PlayerPopupTokens.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(PlayerPopupTokens.chipRadius),
        border: Border.all(
          color: selected
              ? PlayerPopupTokens.accent
              : PlayerPopupTokens.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 14,
              color: selected
                  ? PlayerPopupTokens.accentFg
                  : PlayerPopupTokens.muted,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: selected
                  ? PlayerPopupTokens.accentFg
                  : PlayerPopupTokens.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
    if (!tvFocus) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(PlayerPopupTokens.chipRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(PlayerPopupTokens.chipRadius),
          hoverColor: selected
              ? Colors.black.withValues(alpha: 0.06)
              : ForjaShellColors.inkHover,
          child: face,
        ),
      );
    }
    return FocusableControl(
      onTap: onTap,
      borderRadius: PlayerPopupTokens.chipRadius,
      scaleOnFocus: 1.0,
      showFocusBorder: true,
      child: face,
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
    if (_groups.isEmpty) {
      return const Center(
        child: Text(
          'No subtitles',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 12),
      children: [
        for (final g in _groups)
          PlayerPopupListTile(
            label: g.label,
            trailing: Text(
              '${g.count}',
              style: const TextStyle(
                color: PlayerPopupTokens.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            selected: g.id == _selectedGroupId,
            onTap: () => setState(() => _selectedGroupId = g.id),
          ),
      ],
    );
  }

  Widget _buildTracksColumn() {
    final group = _selectedGroup;
    if (group == null) {
      return const Center(
        child: Text(
          'No tracks',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
      );
    }

    if (widget.isFetchingSubs) {
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

    final langKey = group.langKey;
    final embedded = _byLangEmbedded[langKey] ?? const <ExoTrackInfo>[];
    final online = _byLangOnline[langKey] ?? const <Map<String, dynamic>>[];
    if (embedded.isEmpty && online.isEmpty) {
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
        for (final t in embedded)
          PlayerPopupListTile(
            label: formatPlayerTrackLabel(
              id: t.id,
              title: t.label,
              language: t.language,
            ),
            subtitle: 'In-stream',
            selected: widget.selectedExternalSubUrl == null &&
                !widget.tracks.textOff &&
                t.selected,
            onTap: () async {
              PlayerSubtitleDialog.dismiss();
              await widget.onSelectEmbedded(t);
            },
          ),
        for (final s in online)
          PlayerPopupListTile(
            label: s['display']?.toString() ?? languageDisplayName(langKey),
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
  }

  Widget _buildBody() {
    final group = _selectedGroup;
    final tracksTitle =
        group == null ? 'Tracks' : 'Tracks · ${group.label}';

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
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _headerChip(
                label: 'Off',
                selected: _textOff,
                onTap: () {
                  PlayerSubtitleDialog.dismiss();
                  unawaited(widget.onOff());
                },
              ),
              if (!_hideLoadFile) ...[
                const SizedBox(width: 6),
                _headerChip(
                  label: 'File',
                  icon: Icons.upload_file_rounded,
                  selected: false,
                  onTap: () => unawaited(_pickFile()),
                ),
              ],
              if (widget.onSubtitleSettings != null) ...[
                const SizedBox(width: 6),
                ForjaPlainIcon(
                  icon: Icons.tune_rounded,
                  size: 18,
                  hitSize: 32,
                  color: ForjaShellColors.cinematic.textSecondary,
                  tooltip: 'Subtitle settings',
                  onTap: () {
                    PlayerSubtitleDialog.dismiss();
                    widget.onSubtitleSettings!();
                  },
                ),
              ],
            ],
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
                        _sectionLabel('Languages'),
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
    final padding = TorrentSourcesPanel.defaultContentPadding(playerOverlay: true);

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
                      child: Padding(
                        padding: padding,
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
          ),
        ],
      ),
    );
  }
}
