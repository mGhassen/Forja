import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:forja/shared/player/controls/menus/player_menus.dart';
import 'package:forja/shared/player/controls/menus/player_popup_panel.dart';
import 'package:forja/shared/player/exo/exo_player_bridge.dart';
import 'package:forja/shared/player/screens/utils.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/utils/language_display.dart';
import 'package:rust/rust.dart';
import 'package:forja/shared/shell/forja_buttons.dart';
import 'package:forja/shared/shell/forja_shell_scope.dart';
/// Exo track / settings menus — same popup chrome as MediaKit.
abstract final class ExoPlayerMenus {
  static Future<void> showAudio({
    required BuildContext context,
    required ExoTracksSnapshot tracks,
    required Future<void> Function(String trackId) onSelect,
    BuildContext? anchorContext,
  }) {
    return PlayerPopupPanel.show(
      context: context,
      title: 'Audio',
      leadingIcon: Icons.audiotrack_rounded,
      anchorContext: anchorContext,
      child: _audioTrackColumn(
        tracks: tracks.audio,
        onSelect: onSelect,
      ),
    );
  }

  /// Language-folder Subtitles popup — same shape as [PlayerSubtitleMenu].
  static Future<void> showSubtitles({
    required BuildContext context,
    required ExoTracksSnapshot tracks,
    required Future<void> Function(ExoTrackInfo? track) onSelectEmbedded,
    required Future<void> Function() onOff,
    List<Map<String, dynamic>> externalSubtitles = const [],
    String? selectedExternalSubUrl,
    bool isFetchingSubs = false,
    Future<void> Function(Map<String, dynamic> sub)? onSelectExternal,
    Future<void> Function({required String path, required String name})?
        onLoadFromFile,
    VoidCallback? onSubtitleSettings,
    BuildContext? anchorContext,
    EdgeInsets margin = const EdgeInsets.only(left: 16, bottom: 88),
  }) {
    return _openSubtitleRoot(
      context,
      tracks: tracks,
      onSelectEmbedded: onSelectEmbedded,
      onOff: onOff,
      externalSubtitles: externalSubtitles,
      selectedExternalSubUrl: selectedExternalSubUrl,
      isFetchingSubs: isFetchingSubs,
      onSelectExternal: onSelectExternal,
      onLoadFromFile: onLoadFromFile,
      onSubtitleSettings: onSubtitleSettings,
      anchorContext: anchorContext,
      margin: margin,
    );
  }

  static Future<void> _openSubtitleRoot(
    BuildContext context, {
    required ExoTracksSnapshot tracks,
    required Future<void> Function(ExoTrackInfo? track) onSelectEmbedded,
    required Future<void> Function() onOff,
    required List<Map<String, dynamic>> externalSubtitles,
    required String? selectedExternalSubUrl,
    required bool isFetchingSubs,
    Future<void> Function(Map<String, dynamic> sub)? onSelectExternal,
    Future<void> Function({required String path, required String name})?
        onLoadFromFile,
    VoidCallback? onSubtitleSettings,
    BuildContext? anchorContext,
    required EdgeInsets margin,
  }) async {
    final subtitlesOff =
        tracks.textOff && selectedExternalSubUrl == null;
    final selectedEmbedded = tracks.text.where((t) => t.selected).firstOrNull;
    final selectedSubtitleId =
        subtitlesOff || selectedExternalSubUrl != null
            ? null
            : selectedEmbedded?.id;

    final byLangOnline = <String, List<Map<String, dynamic>>>{};
    for (final s in externalSubtitles) {
      final key = languageGroupKey(
        (s['language'] ?? s['lang'])?.toString(),
      );
      byLangOnline.putIfAbsent(key, () => []).add(s);
    }

    final byLangEmbedded = <String, List<ExoTrackInfo>>{};
    for (final t in tracks.text) {
      final key = languageGroupKey(
        t.language.isNotEmpty ? t.language : t.label,
      );
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
      trailing: _ExoSubtitleHeaderTrailing(
        tv: hideLoadFile,
        subtitlesOff: subtitlesOff,
        onOff: () async {
          PlayerPopupPanel.dismiss();
          await onOff();
        },
        showFile: !hideLoadFile && onLoadFromFile != null,
        onFile: onLoadFromFile == null
            ? null
            : () async {
                PlayerPopupPanel.dismiss();
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: const ['srt', 'vtt', 'ass', 'ssa'],
                );
                if (result == null || result.files.single.path == null) {
                  return;
                }
                final path = result.files.single.path!;
                final name = result.files.single.name;
                await onLoadFromFile(path: path, name: name);
              },
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
          if (!isFetchingSubs && folderKeys.isEmpty)
            const Text(
              'None available',
              style: TextStyle(color: PlayerPopupTokens.muted),
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
                      unawaited(_openSubtitleLanguage(
                        context,
                        langKey: key,
                        embedded: stream,
                        online: online,
                        selectedSubtitleId: selectedSubtitleId,
                        selectedExternalSubUrl: selectedExternalSubUrl,
                        onSelectEmbedded: onSelectEmbedded,
                        onSelectExternal: onSelectExternal,
                        onRoot: () => _openSubtitleRoot(
                          context,
                          tracks: tracks,
                          onSelectEmbedded: onSelectEmbedded,
                          onOff: onOff,
                          externalSubtitles: externalSubtitles,
                          selectedExternalSubUrl: selectedExternalSubUrl,
                          isFetchingSubs: isFetchingSubs,
                          onSelectExternal: onSelectExternal,
                          onLoadFromFile: onLoadFromFile,
                          onSubtitleSettings: onSubtitleSettings,
                          anchorContext: anchorContext,
                          margin: margin,
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

  static Future<void> _openSubtitleLanguage(
    BuildContext context, {
    required String langKey,
    required List<ExoTrackInfo> embedded,
    required List<Map<String, dynamic>> online,
    required String? selectedSubtitleId,
    required String? selectedExternalSubUrl,
    required Future<void> Function(ExoTrackInfo? track) onSelectEmbedded,
    Future<void> Function(Map<String, dynamic> sub)? onSelectExternal,
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
                title: t.label,
                language: t.language,
              ),
              subtitle: 'In-stream',
              selected: selectedSubtitleId != null &&
                  selectedExternalSubUrl == null &&
                  t.id == selectedSubtitleId,
              onTap: () async {
                PlayerPopupPanel.dismiss();
                await onSelectEmbedded(t);
              },
            ),
          for (final s in online)
            PlayerPopupListTile(
              label: _onlineSubtitleLabel(s, langKey),
              subtitle: (s['translated'] == true ? 'Translated · ' : '') +
                  (s['sourceName']?.toString() ?? 'opensubtitles'),
              selected: selectedExternalSubUrl != null &&
                  s['url'] == selectedExternalSubUrl,
              onTap: () async {
                PlayerPopupPanel.dismiss();
                await onSelectExternal?.call(s);
              },
            ),
        ],
      ),
    );
  }

  /// Prefer human labels; never show a raw http(s) URL as the row title.
  static String _onlineSubtitleLabel(
    Map<String, dynamic> s,
    String langKey,
  ) {
    for (final key in const ['display', 'name', 'title']) {
      final v = s[key]?.toString().trim() ?? '';
      if (v.isEmpty) continue;
      final lower = v.toLowerCase();
      if (lower.startsWith('http://') || lower.startsWith('https://')) {
        continue;
      }
      return v;
    }
    return languageDisplayName(langKey);
  }

  static Future<void> showQuality({
    required BuildContext context,
    required ExoTracksSnapshot tracks,
    required Future<void> Function(String? trackId) onSelect,
    BuildContext? anchorContext,
  }) {
    return PlayerPopupPanel.show(
      context: context,
      title: 'Quality',
      leadingIcon: Icons.hd_outlined,
      anchorContext: anchorContext,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!tracks.videoAuto)
              PlayerPopupOptionChip(
                label: 'Auto',
                selected: false,
                expanded: true,
                onTap: () async {
                  PlayerPopupPanel.dismiss();
                  await onSelect(null);
                },
              ),
            if (tracks.video.isEmpty && !tracks.videoAuto)
              const Text(
                'None available',
                style: TextStyle(color: PlayerPopupTokens.muted),
              )
            else
              for (final t in tracks.video)
                PlayerPopupOptionChip(
                  label: t.label,
                  selected: t.selected,
                  expanded: true,
                  onTap: () async {
                    PlayerPopupPanel.dismiss();
                    if (!tracks.videoAuto && t.selected) return;
                    await onSelect(t.id);
                  },
                ),
          ],
        ),
      ),
    );
  }

  static void showSettings({
    required BuildContext context,
    required double Function() rateOf,
    required String Function() resizeModeOf,
    required Future<void> Function(double rate) onRate,
    required Future<void> Function(String mode) onResize,
    bool Function()? providerPinnedOf,
    bool Function()? sourcePinnedOf,
    bool Function()? audioPinnedOf,
    bool Function()? subtitlePinnedOf,
    Future<void> Function(bool on)? onAutoServer,
    Future<void> Function(bool on)? onAutoSource,
    Future<void> Function(bool on)? onAutoAudio,
    Future<void> Function(bool on)? onAutoSubtitles,
    bool showAutoServer = false,
    bool showAutoSource = false,
    BuildContext? anchorContext,
  }) {
    showPlayerSettingsMenu(
      context: context,
      anchorContext: anchorContext,
      buildEntries: () {
        final rate = rateOf();
        final resizeMode = resizeModeOf();
        return [
          if (providerPinnedOf != null ||
              sourcePinnedOf != null ||
              audioPinnedOf != null ||
              subtitlePinnedOf != null)
            PlayerSettingsEntry(
              icon: Icons.auto_awesome_rounded,
              title: 'Auto selection',
              subtitle: 'Servers, tracks, skip intro',
              pageBuilder: (_) => StatefulBuilder(
                builder: (context, setPage) => Column(
                  children: [
                    if (showAutoServer &&
                        providerPinnedOf != null &&
                        onAutoServer != null) ...[
                      PlayerPopupToggleRow(
                        label: 'Auto server',
                        value: !providerPinnedOf(),
                        onChanged: (on) async {
                          await onAutoServer(on);
                          setPage(() {});
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (showAutoSource &&
                        sourcePinnedOf != null &&
                        onAutoSource != null) ...[
                      PlayerPopupToggleRow(
                        label: 'Auto source',
                        value: !sourcePinnedOf(),
                        onChanged: (on) async {
                          await onAutoSource(on);
                          setPage(() {});
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (audioPinnedOf != null && onAutoAudio != null) ...[
                      PlayerPopupToggleRow(
                        label: 'Auto audio',
                        value: !audioPinnedOf(),
                        onChanged: (on) async {
                          await onAutoAudio(on);
                          setPage(() {});
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (subtitlePinnedOf != null &&
                        onAutoSubtitles != null) ...[
                      PlayerPopupToggleRow(
                        label: 'Auto subtitles',
                        value: !subtitlePinnedOf(),
                        onChanged: (on) async {
                          await onAutoSubtitles(on);
                          setPage(() {});
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    PlayerPopupToggleRow(
                      label: 'Auto skip intro',
                      value: SettingsService.autoSkipIntroNotifier.value,
                      onChanged: (on) async {
                        await SettingsService().setAutoSkipIntro(on);
                        setPage(() {});
                      },
                    ),
                    const SizedBox(height: 12),
                    PlayerPopupToggleRow(
                      label: 'Content warnings',
                      value: SettingsService.contentWarningsNotifier.value,
                      onChanged: (on) async {
                        await SettingsService().setContentWarnings(on);
                        setPage(() {});
                      },
                    ),
                  ],
                ),
              ),
            ),
          PlayerSettingsEntry(
            icon: Icons.speed_rounded,
            title: 'Playback speed',
            value: rate == 1.0 ? 'Normal' : '${rate}x',
            pageBuilder: (_) => StatefulBuilder(
              builder: (context, setPage) {
                final current = rateOf();
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    0.25,
                    0.5,
                    0.75,
                    1.0,
                    1.25,
                    1.5,
                    1.75,
                    2.0,
                  ].map((speed) {
                    return PlayerPopupOptionChip(
                      label: speed == 1.0 ? 'Normal' : '${speed}x',
                      selected: speed == current,
                      expanded: true,
                      onTap: () async {
                        await onRate(speed);
                        setPage(() {});
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ),
          PlayerSettingsEntry(
            icon: Icons.aspect_ratio_rounded,
            title: 'Aspect ratio',
            subtitle: 'How video fills the frame',
            value: switch (resizeMode) {
              'fill' => 'Fill',
              'zoom' => 'Crop',
              _ => 'Fit',
            },
            pageBuilder: (_) => StatefulBuilder(
              builder: (context, setPage) {
                final current = resizeModeOf();
                const options = [
                  ('fit', 'Fit'),
                  ('fill', 'Fill'),
                  ('zoom', 'Crop'),
                ];
                return playerPopupChipRow([
                  for (final (mode, label) in options)
                    PlayerPopupOptionChip(
                      label: label,
                      selected: current == mode,
                      expanded: true,
                      grouped: true,
                      onTap: () async {
                        await onResize(mode);
                        setPage(() {});
                      },
                    ),
                ]);
              },
            ),
          ),
        ];
      },
    );
  }

  static Widget _audioTrackColumn({
    required List<ExoTrackInfo> tracks,
    required Future<void> Function(String trackId) onSelect,
  }) {
    if (tracks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Text(
          'None available',
          style: TextStyle(color: PlayerPopupTokens.muted),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      children: [
        for (var i = 0; i < tracks.length; i++)
          _audioTile(track: tracks[i], index: i + 1, onSelect: onSelect),
      ],
    );
  }

  static Widget _audioTile({
    required ExoTrackInfo track,
    required int index,
    required Future<void> Function(String trackId) onSelect,
  }) {
    final label = formatPlayerTrackLabel(
      id: track.id,
      title: track.label,
      language: track.language,
      index: index,
    );
    return PlayerPopupListTile(
      label: label,
      subtitle: formatPlayerAudioFormatSubtitle(
        languageLabel: label,
        title: track.label,
        language: track.language,
        bitrate: track.bitrate > 0 ? track.bitrate : null,
      ),
      selected: track.selected,
      onTap: () async {
        PlayerPopupPanel.dismiss();
        if (!track.selected) {
          await onSelect(track.id);
        }
      },
    );
  }
}

/// Off (+ File) + tune — TV: Off → tune → Close X.
class _ExoSubtitleHeaderTrailing extends StatefulWidget {
  const _ExoSubtitleHeaderTrailing({
    required this.tv,
    required this.subtitlesOff,
    required this.onOff,
    required this.showFile,
    this.onFile,
    this.onSubtitleSettings,
  });

  final bool tv;
  final bool subtitlesOff;
  final Future<void> Function() onOff;
  final bool showFile;
  final Future<void> Function()? onFile;
  final VoidCallback? onSubtitleSettings;

  @override
  State<_ExoSubtitleHeaderTrailing> createState() =>
      _ExoSubtitleHeaderTrailingState();
}

class _ExoSubtitleHeaderTrailingState extends State<_ExoSubtitleHeaderTrailing> {
  final FocusNode _tuneFocus = FocusNode(debugLabel: 'exo-subtitle-tune');

  @override
  void dispose() {
    _tuneFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasTune = widget.onSubtitleSettings != null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PlayerPopupHeaderChip(
          label: 'Off',
          selected: widget.subtitlesOff,
          autoFocus: !widget.tv && widget.subtitlesOff,
          onTap: () => unawaited(widget.onOff()),
          onRightEdge: widget.tv
              ? () {
                  if (hasTune && _tuneFocus.canRequestFocus) {
                    _tuneFocus.requestFocus();
                  } else {
                    PlayerPopupCloseFocus.request(context);
                  }
                }
              : null,
        ),
        if (widget.showFile && widget.onFile != null) ...[
          const SizedBox(width: 6),
          PlayerPopupHeaderChip(
            label: 'File',
            icon: Icons.upload_file_rounded,
            selected: false,
            onTap: () => unawaited(widget.onFile!()),
          ),
        ],
        if (hasTune) ...[
          const SizedBox(width: 6),
          _SubtitleTuneChip(
            tv: widget.tv,
            focusNode: _tuneFocus,
            onTap: () {
              PlayerPopupPanel.dismiss();
              widget.onSubtitleSettings!();
            },
          ),
        ],
      ],
    );
  }
}

/// Tune icon — [ForjaPlainIcon] traps D-pad; TV uses [FocusableControl] → Close.
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
    final face = SizedBox(
      width: 32,
      height: 32,
      child: Icon(
        Icons.tune_rounded,
        size: 18,
        color: PlayerPopupTokens.muted,
      ),
    );
    return FocusableControl(
      focusNode: focusNode,
      onTap: onTap,
      borderRadius: PlayerPopupTokens.chipRadius,
      scaleOnFocus: 1.0,
      showFocusBorder: false,
      showFocusFill: false,
      onRightEdge: () => PlayerPopupCloseFocus.request(context),
      child: face,
    );
  }
}