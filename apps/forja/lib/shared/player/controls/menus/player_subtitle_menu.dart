import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:forja/shared/player/controls/menus/player_popup_panel.dart';
import 'package:forja/shared/player/screens/utils.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/utils/language_display.dart';
import 'package:media_kit/media_kit.dart';
import 'package:forja/shared/shell/forja_buttons.dart';
import 'package:forja/shared/shell/forja_shell_scope.dart';
/// Fired when the user picks Off, an embedded track, or an external file.
typedef PlayerSubtitleSelectionCallback = void Function({
  required bool off,
  String? language,
  String? title,
});

class PlayerSubtitleMenu {
  static Future<void> show(
    BuildContext context, {
    required Player player,
    required List<Map<String, dynamic>> externalSubtitles,
    required String? selectedExternalSubUrl,
    required bool isFetchingSubs,
    required void Function(SubtitleTrack track) updateSubVisibility,
    required void Function(String? url) onExternalUrlChanged,
    required void Function(bool isNative) onNativeSubtitleChanged,
    required Future<bool> Function(Map<String, dynamic> sub) loadOnlineSubtitle,
    required VoidCallback onSubtitleSettings,
    PlayerSubtitleSelectionCallback? onSubtitleSelected,
    /// IPTV / junk titles — opens a "search by name" dialog.
    VoidCallback? onTitleSearch,
    /// Shown under the list when set (e.g. cleaned query in use).
    String? titleSearchHint,
    BuildContext? anchorContext,
    EdgeInsets margin = const EdgeInsets.only(left: 16, bottom: 88),
  }) async {
    await _openRoot(
      context,
      player: player,
      externalSubtitles: externalSubtitles,
      selectedExternalSubUrl: selectedExternalSubUrl,
      isFetchingSubs: isFetchingSubs,
      updateSubVisibility: updateSubVisibility,
      onExternalUrlChanged: onExternalUrlChanged,
      onNativeSubtitleChanged: onNativeSubtitleChanged,
      loadOnlineSubtitle: loadOnlineSubtitle,
      onSubtitleSettings: onSubtitleSettings,
      onSubtitleSelected: onSubtitleSelected,
      onTitleSearch: onTitleSearch,
      titleSearchHint: titleSearchHint,
      margin: margin,
      anchorContext: anchorContext,
    );
  }

  static Future<void> _pickLocalFile({
    required Player player,
    required void Function(SubtitleTrack track) updateSubVisibility,
    required void Function(String? url) onExternalUrlChanged,
    required void Function(bool isNative) onNativeSubtitleChanged,
    PlayerSubtitleSelectionCallback? onSubtitleSelected,
  }) async {
    // Dismiss before the native picker — overlays can block the dialog,
    // and file_picker returns null when the sheet stays up.
    PlayerPopupPanel.dismiss();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['srt', 'ass', 'ssa', 'vtt'],
    );
    if (result == null || result.files.single.path == null) return;
    onSubtitleSelected?.call(off: false);
    final path = result.files.single.path!;
    final name = result.files.single.name;
    final subTrack = SubtitleTrack.uri(
      Uri.file(path).toString(),
      title: name,
      language: 'und',
    );
    player.setSubtitleTrack(subTrack);
    updateSubVisibility(subTrack);
    final isAssFile =
        name.toLowerCase().endsWith('.ass') ||
        name.toLowerCase().endsWith('.ssa');
    onExternalUrlChanged(null);
    onNativeSubtitleChanged(isAssFile);
    if (player.platform is NativePlayer) {
      (player.platform as NativePlayer).setProperty(
        'sub-visibility',
        isAssFile ? 'yes' : 'no',
      );
    }
  }

  static Future<void> _openRoot(
    BuildContext context, {
    required Player player,
    required List<Map<String, dynamic>> externalSubtitles,
    required String? selectedExternalSubUrl,
    required bool isFetchingSubs,
    required void Function(SubtitleTrack track) updateSubVisibility,
    required void Function(String? url) onExternalUrlChanged,
    required void Function(bool isNative) onNativeSubtitleChanged,
    required Future<bool> Function(Map<String, dynamic> sub) loadOnlineSubtitle,
    required VoidCallback onSubtitleSettings,
    PlayerSubtitleSelectionCallback? onSubtitleSelected,
    VoidCallback? onTitleSearch,
    String? titleSearchHint,
    required EdgeInsets margin,
    BuildContext? anchorContext,
  }) async {
    final current = player.state.track.subtitle;
    final subtitlesOff = current.id == 'no' && selectedExternalSubUrl == null;
    final active = subtitlesOff ? null : await resolveActiveSubtitleTrack(player);
    final selectedSubtitleId = subtitlesOff || selectedExternalSubUrl != null
        ? null
        : (active?.id ?? current.id);
    // Muxed HLS tracks only — not sideloaded copies of the active external sub.
    final embedded = menuEmbeddedSubtitleTracks(
      player,
      selectedExternalSubUrl: selectedExternalSubUrl,
      externalSubtitles: externalSubtitles,
    );

    void turnOffSubtitles() {
      onSubtitleSelected?.call(off: true);
      player.setSubtitleTrack(SubtitleTrack.no());
      updateSubVisibility(SubtitleTrack.no());
      onExternalUrlChanged(null);
      PlayerPopupPanel.dismiss();
    }

    final byLangOnline = <String, List<Map<String, dynamic>>>{};
    for (final s in externalSubtitles) {
      final key = languageGroupKey(
        (s['language'] ?? s['lang'])?.toString(),
      );
      byLangOnline.putIfAbsent(key, () => []).add(s);
    }

    final byLangEmbedded = <String, List<SubtitleTrack>>{};
    for (final t in embedded) {
      final key = languageGroupKey(t.language ?? t.title);
      byLangEmbedded.putIfAbsent(key, () => []).add(t);
    }

    final folderKeys = <String>{
      ...byLangOnline.keys,
      ...byLangEmbedded.keys,
    }.toList()
      ..sort(compareLanguageCodes);

    if (!context.mounted) return;

    final hideLoadFile =
        ShellScope.inputPolicyOf(context).useFocusableMoodChips;

    await PlayerPopupPanel.show(
      context: context,
      title: '',
      alignment: Alignment.bottomLeft,
      margin: margin,
      anchorContext: anchorContext,
      maxHeight: 420,
      width: 320,
      autofocusClose: hideLoadFile,
      trailing: _SubtitleHeaderTrailing(
        tv: hideLoadFile,
        subtitlesOff: subtitlesOff,
        onOff: turnOffSubtitles,
        showFile: !hideLoadFile,
        onFile: () => _pickLocalFile(
          player: player,
          updateSubVisibility: updateSubVisibility,
          onExternalUrlChanged: onExternalUrlChanged,
          onNativeSubtitleChanged: onNativeSubtitleChanged,
          onSubtitleSelected: onSubtitleSelected,
        ),
        onTitleSearch: onTitleSearch,
        onSubtitleSettings: onSubtitleSettings,
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        shrinkWrap: true,
        children: [
          if (isFetchingSubs)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: LinearProgressIndicator(
                color: Colors.white54,
                backgroundColor: Colors.white10,
              ),
            ),
          if (titleSearchHint != null && titleSearchHint.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Searching: $titleSearchHint',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          if (!isFetchingSubs &&
              folderKeys.isEmpty &&
              onTitleSearch != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'No online subtitles yet. Tap Search to type the film or series name.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
          for (var i = 0; i < folderKeys.length; i++) ...[
            if (i != 0) const SizedBox(height: 8),
            Builder(
              builder: (_) {
                final key = folderKeys[i];
                final online = byLangOnline[key] ?? const [];
                final stream = byLangEmbedded[key] ?? const [];
                final hasSelected = !subtitlesOff &&
                    (online.any((s) => s['url'] == selectedExternalSubUrl) ||
                        (selectedExternalSubUrl == null &&
                            selectedSubtitleId != null &&
                            stream.any((t) => t.id == selectedSubtitleId)));
                return PlayerPopupNavRow(
                  title: languageDisplayName(key),
                  value: '${stream.length + online.length}',
                  selected: hasSelected,
                  onTap: () {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!context.mounted) return;
                      unawaited(_openLanguage(
                        context,
                        langKey: key,
                        embedded: stream,
                        online: online,
                        selectedSubtitleId: selectedSubtitleId,
                        selectedExternalSubUrl: selectedExternalSubUrl,
                        player: player,
                        updateSubVisibility: updateSubVisibility,
                        onExternalUrlChanged: onExternalUrlChanged,
                        loadOnlineSubtitle: loadOnlineSubtitle,
                        onSubtitleSelected: onSubtitleSelected,
                        onRoot: () => _openRoot(
                          context,
                          player: player,
                          externalSubtitles: externalSubtitles,
                          selectedExternalSubUrl: selectedExternalSubUrl,
                          isFetchingSubs: isFetchingSubs,
                          updateSubVisibility: updateSubVisibility,
                          onExternalUrlChanged: onExternalUrlChanged,
                          onNativeSubtitleChanged: onNativeSubtitleChanged,
                          loadOnlineSubtitle: loadOnlineSubtitle,
                          onSubtitleSettings: onSubtitleSettings,
                          onSubtitleSelected: onSubtitleSelected,
                          onTitleSearch: onTitleSearch,
                          titleSearchHint: titleSearchHint,
                          margin: margin,
                          anchorContext: anchorContext,
                        ),
                        margin: margin,
                        anchorContext: anchorContext,
                      ));
                    });
                  },
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  static Future<void> _openLanguage(
    BuildContext context, {
    required String langKey,
    required List<SubtitleTrack> embedded,
    required List<Map<String, dynamic>> online,
    required String? selectedSubtitleId,
    required String? selectedExternalSubUrl,
    required Player player,
    required void Function(SubtitleTrack track) updateSubVisibility,
    required void Function(String? url) onExternalUrlChanged,
    required Future<bool> Function(Map<String, dynamic> sub) loadOnlineSubtitle,
    PlayerSubtitleSelectionCallback? onSubtitleSelected,
    required Future<void> Function() onRoot,
    required EdgeInsets margin,
    BuildContext? anchorContext,
  }) async {
    await PlayerPopupPanel.show(
      context: context,
      title: languageDisplayName(langKey),
      alignment: Alignment.bottomLeft,
      margin: margin,
      anchorContext: anchorContext,
      maxHeight: 420,
      width: 320,
      autofocusClose: ShellScope.inputPolicyOf(context).useFocusableMoodChips,
      onBack: () {
        onRoot();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        shrinkWrap: true,
        children: [
          for (final t in embedded)
            PlayerPopupListTile(
              label: formatPlayerTrackLabel(
                id: t.id,
                title: t.title,
                language: t.language,
              ),
              subtitle: 'In-stream',
              selected: selectedSubtitleId != null &&
                  selectedExternalSubUrl == null &&
                  t.id == selectedSubtitleId,
              onTap: () async {
                onSubtitleSelected?.call(
                  off: false,
                  language: t.language,
                  title: t.title,
                );
                onExternalUrlChanged(null);
                try {
                  await preparePlayerExternalSubtitleSwitch(player);
                  await player.setSubtitleTrack(t);
                  updateSubVisibility(t);
                  PlayerPopupPanel.dismiss();
                } catch (e) {
                  debugPrint('[PlayerSubtitleMenu] in-stream sub failed: $e');
                }
              },
            ),
          for (final s in online)
            PlayerPopupListTile(
              label: s['display']?.toString() ?? languageDisplayName(langKey),
              subtitle: (s['translated'] == true ? 'Translated · ' : '') +
                  (s['sourceName']?.toString() ?? 'opensubtitles'),
              selected: s['url'] == selectedExternalSubUrl,
              onTap: () async {
                final ok = await loadOnlineSubtitle(s);
                if (!ok) return;
                onSubtitleSelected?.call(
                  off: false,
                  language: s['language']?.toString() ?? langKey,
                  title: s['display']?.toString(),
                );
                onExternalUrlChanged(s['url']?.toString());
                if (context.mounted) PlayerPopupPanel.dismiss();
              },
            ),
        ],
      ),
    );
  }
}

/// Off (+ File / Search) + tune — TV: Off → tune → Close X via [PlayerPopupCloseFocus].
class _SubtitleHeaderTrailing extends StatefulWidget {
  const _SubtitleHeaderTrailing({
    required this.tv,
    required this.subtitlesOff,
    required this.onOff,
    required this.showFile,
    required this.onFile,
    required this.onSubtitleSettings,
    this.onTitleSearch,
  });

  final bool tv;
  final bool subtitlesOff;
  final VoidCallback onOff;
  final bool showFile;
  final VoidCallback onFile;
  final VoidCallback onSubtitleSettings;
  final VoidCallback? onTitleSearch;

  @override
  State<_SubtitleHeaderTrailing> createState() =>
      _SubtitleHeaderTrailingState();
}

class _SubtitleHeaderTrailingState extends State<_SubtitleHeaderTrailing> {
  final FocusNode _tuneFocus = FocusNode(debugLabel: 'subtitle-tune');

  @override
  void dispose() {
    _tuneFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PlayerPopupHeaderChip(
          label: 'Off',
          selected: widget.subtitlesOff,
          autoFocus: !widget.tv && widget.subtitlesOff,
          onTap: widget.onOff,
          onRightEdge: widget.tv
              ? () {
                  if (_tuneFocus.canRequestFocus) {
                    _tuneFocus.requestFocus();
                  } else {
                    PlayerPopupCloseFocus.request(context);
                  }
                }
              : null,
        ),
        if (widget.showFile) ...[
          const SizedBox(width: 6),
          PlayerPopupHeaderChip(
            label: 'File',
            icon: Icons.upload_file_rounded,
            selected: false,
            onTap: widget.onFile,
          ),
        ],
        if (widget.onTitleSearch != null) ...[
          const SizedBox(width: 6),
          PlayerPopupHeaderChip(
            label: 'Search',
            icon: Icons.search_rounded,
            selected: false,
            onTap: () {
              PlayerPopupPanel.dismiss();
              widget.onTitleSearch!();
            },
          ),
        ],
        const SizedBox(width: 6),
        _SubtitleTuneChip(
          tv: widget.tv,
          focusNode: _tuneFocus,
          onTap: () {
            PlayerPopupPanel.dismiss();
            widget.onSubtitleSettings();
          },
        ),
      ],
    );
  }
}

class _SubtitleTuneChip extends StatelessWidget {
  const _SubtitleTuneChip({
    required this.tv,
    required this.onTap,
    this.focusNode,
  });

  final bool tv;
  final VoidCallback onTap;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    if (!tv) {
      return ForjaPlainIcon(
        icon: Icons.tune_rounded,
        size: 18,
        color: Colors.white54,
        onTap: onTap,
      );
    }
    return FocusableControl(
      focusNode: focusNode,
      onTap: onTap,
      borderRadius: PlayerPopupTokens.chipRadius,
      scaleOnFocus: 1.0,
      showFocusBorder: false,
      showFocusFill: false,
      onRightEdge: () => PlayerPopupCloseFocus.request(context),
      child: SizedBox(
        width: 32,
        height: 32,
        child: Icon(
          Icons.tune_rounded,
          size: 18,
          color: PlayerPopupTokens.muted,
        ),
      ),
    );
  }
}
