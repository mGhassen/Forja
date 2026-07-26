import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/player/controls/player_menus.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:forja/shared/player/exo/exo_player_bridge.dart';
import 'package:forja/shared/player/player/utils.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/utils/language_display.dart';

/// Minimalist Exo track / settings menus - [PlayerPopupPanel] chips & list tiles.
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
      child: _trackChipColumn(
        tracks: tracks.audio,
        emptyLabel: 'None available',
        labelOf: (t) => formatPlayerTrackLabel(
          id: t.id,
          title: t.label,
          language: t.language,
        ),
        onSelect: onSelect,
      ),
    );
  }

  static Future<void> showSubtitles({
    required BuildContext context,
    required ExoTracksSnapshot tracks,
    required Future<void> Function(ExoTrackInfo? track) onSelectEmbedded,
    required Future<void> Function() onOff,
    List<Map<String, dynamic>> externalSubtitles = const [],
    String? selectedExternalSubUrl,
    bool isFetchingSubs = false,
    Future<void> Function(Map<String, dynamic> sub)? onSelectExternal,
    /// Local SRT/VTT file — same row as MediaKit (ASS/SSA need MediaKit/libass).
    Future<void> Function({required String path, required String name})?
        onLoadFromFile,
    BuildContext? anchorContext,
  }) {
    final byLang = <String, List<Map<String, dynamic>>>{};
    for (final s in externalSubtitles) {
      final key = languageGroupKey(
        (s['language'] ?? s['lang'])?.toString(),
      );
      byLang.putIfAbsent(key, () => []).add(s);
    }
    final folderKeys = byLang.keys.toList()..sort(compareLanguageCodes);
    final textOff = tracks.textOff ||
        (tracks.text.every((t) => !t.selected) &&
            selectedExternalSubUrl == null);

    return PlayerPopupPanel.show(
      context: context,
      title: 'Subtitles',
      leadingIcon: Icons.subtitles_outlined,
      alignment: Alignment.bottomLeft,
      anchorContext: anchorContext,
      maxHeight: 420,
      width: 320,
      trailing: _SubtitleOffChip(
        selected: textOff,
        onTap: () async {
          PlayerPopupPanel.dismiss();
          await onOff();
        },
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
          for (var i = 0; i < tracks.text.length; i++) ...[
            if (i != 0) const SizedBox(height: 8),
            PlayerPopupOptionChip(
              label: formatPlayerTrackLabel(
                id: tracks.text[i].id,
                title: tracks.text[i].label,
                language: tracks.text[i].language,
              ),
              selected: selectedExternalSubUrl == null &&
                  !tracks.textOff &&
                  tracks.text[i].selected,
              expanded: true,
              onTap: () async {
                PlayerPopupPanel.dismiss();
                await onSelectEmbedded(tracks.text[i]);
              },
            ),
          ],
          if (tracks.text.isNotEmpty) const SizedBox(height: 10),
          if (onLoadFromFile != null)
            PlayerPopupNavRow(
              icon: Icons.upload_file_rounded,
              title: 'Load from file',
              subtitle: 'SRT · VTT',
              onTap: () async {
                // Dismiss before the native picker - overlays can block the
                // dialog, and file_picker returns null when the sheet stays up.
                PlayerPopupPanel.dismiss();
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: const ['srt', 'vtt'],
                );
                if (result == null || result.files.single.path == null) return;
                await onLoadFromFile(
                  path: result.files.single.path!,
                  name: result.files.single.name,
                );
              },
            ),
          for (final key in folderKeys) ...[
            const SizedBox(height: 8),
            Builder(
              builder: (_) {
                final list = byLang[key]!;
                final hasSelected = list.any(
                  (s) => s['url'] == selectedExternalSubUrl,
                );
                return PlayerPopupNavRow(
                  title: languageDisplayName(key),
                  value: '${list.length}',
                  selected: hasSelected,
                  onTap: () async {
                    PlayerPopupPanel.dismiss();
                    await _openExternalLanguage(
                      context,
                      langKey: key,
                      subs: list,
                      selectedExternalSubUrl: selectedExternalSubUrl,
                      onSelectExternal: onSelectExternal,
                      onRoot: () => showSubtitles(
                        context: context,
                        tracks: tracks,
                        onSelectEmbedded: onSelectEmbedded,
                        onOff: onOff,
                        externalSubtitles: externalSubtitles,
                        selectedExternalSubUrl: selectedExternalSubUrl,
                        isFetchingSubs: isFetchingSubs,
                        onSelectExternal: onSelectExternal,
                        onLoadFromFile: onLoadFromFile,
                        anchorContext: anchorContext,
                      ),
                      anchorContext: anchorContext,
                    );
                  },
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  static Future<void> _openExternalLanguage(
    BuildContext context, {
    required String langKey,
    required List<Map<String, dynamic>> subs,
    required String? selectedExternalSubUrl,
    Future<void> Function(Map<String, dynamic> sub)? onSelectExternal,
    required Future<void> Function() onRoot,
    BuildContext? anchorContext,
  }) {
    return PlayerPopupPanel.show(
      context: context,
      title: languageDisplayName(langKey),
      anchorContext: anchorContext,
      maxHeight: 420,
      width: 320,
      onBack: () {
        onRoot();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        shrinkWrap: true,
        children: subs.map((s) {
          final sel = s['url'] == selectedExternalSubUrl;
          final source =
              (s['translated'] == true ? 'Translated · ' : '') +
              (s['sourceName']?.toString() ?? 'opensubtitles');
          return PlayerPopupListTile(
            label: s['display']?.toString() ?? languageDisplayName(langKey),
            subtitle: source,
            selected: sel,
            onTap: () async {
              await onSelectExternal?.call(s);
              if (context.mounted) PlayerPopupPanel.dismiss();
            },
          );
        }).toList(),
      ),
    );
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
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // While Auto/ABR is active, hide Auto and highlight the playing
            // track. Auto reappears once a fixed quality is locked.
            if (!tracks.videoAuto)
              PlayerPopupOptionChip(
                label: 'Auto',
                selected: false,
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
                  onTap: () async {
                    PlayerPopupPanel.dismiss();
                    // Lock even if this track is the Auto pick.
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
    BuildContext? anchorContext,
  }) {
    showPlayerSettingsMenu(
      context: context,
      anchorContext: anchorContext,
      buildEntries: () {
        final rate = rateOf();
        final resizeMode = resizeModeOf();
        return [
          PlayerSettingsEntry(
            icon: Icons.speed_rounded,
            title: 'Playback speed',
            value: rate == 1.0 ? 'Normal' : '${rate}x',
            pageBuilder: (_) => StatefulBuilder(
              builder: (context, setPage) {
                final current = rateOf();
                return Wrap(
                  spacing: 6,
                  runSpacing: 6,
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
            title: 'Fit',
            subtitle: 'How video fills the frame',
            value: switch (resizeMode) {
              'fill' => 'Fill',
              'zoom' => 'Zoom',
              _ => 'Fit',
            },
            pageBuilder: (_) => StatefulBuilder(
              builder: (context, setPage) {
                final current = resizeModeOf();
                const options = [
                  ('fit', 'Fit'),
                  ('fill', 'Fill'),
                  ('zoom', 'Zoom'),
                ];
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (mode, label) in options)
                      PlayerPopupOptionChip(
                        label: label,
                        selected: current == mode,
                        onTap: () async {
                          await onResize(mode);
                          setPage(() {});
                        },
                      ),
                  ],
                );
              },
            ),
          ),
        ];
      },
    );
  }

  static Widget _trackChipColumn({
    required List<ExoTrackInfo> tracks,
    required String emptyLabel,
    required String Function(ExoTrackInfo) labelOf,
    required Future<void> Function(String trackId) onSelect,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      child: tracks.isEmpty
          ? Text(
              emptyLabel,
              style: const TextStyle(color: PlayerPopupTokens.muted),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < tracks.length; i++) ...[
                  if (i != 0) const SizedBox(height: 8),
                  PlayerPopupOptionChip(
                    label: labelOf(tracks[i]),
                    selected: tracks[i].selected,
                    expanded: true,
                    onTap: () async {
                      PlayerPopupPanel.dismiss();
                      if (!tracks[i].selected) {
                        await onSelect(tracks[i].id);
                      }
                    },
                  ),
                ],
              ],
            ),
    );
  }
}

class _SubtitleOffChip extends StatelessWidget {
  const _SubtitleOffChip({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tvFocus = ShellScope.inputPolicyOf(context).useFocusableMoodChips;
    final face = Container(
      height: 28,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: selected ? PlayerPopupTokens.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(PlayerPopupTokens.chipRadius),
        border: Border.all(
          color: selected
              ? PlayerPopupTokens.accent
              : PlayerPopupTokens.border,
        ),
      ),
      child: Text(
        'Off',
        style: TextStyle(
          color: selected
              ? PlayerPopupTokens.accentFg
              : PlayerPopupTokens.muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
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
}
