import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:forja/shared/player/player/utils.dart';
import 'package:forja/shared/utils/language_display.dart';
import 'package:media_kit/media_kit.dart';

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
    required Future<void> Function(Map<String, dynamic> sub) loadOnlineSubtitle,
    required VoidCallback onSubtitleSettings,
    VoidCallback? onSubtitleSelected,
    bool excludeKnownExternalEmbedded = false,
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
      excludeKnownExternalEmbedded: excludeKnownExternalEmbedded,
      margin: margin,
      anchorContext: anchorContext,
    );
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
    required Future<void> Function(Map<String, dynamic> sub) loadOnlineSubtitle,
    required VoidCallback onSubtitleSettings,
    VoidCallback? onSubtitleSelected,
    required bool excludeKnownExternalEmbedded,
    required EdgeInsets margin,
    BuildContext? anchorContext,
  }) async {
    final current = player.state.track.subtitle;
    final active = await resolveActiveSubtitleTrack(player);
    final selectedSubtitleId = selectedExternalSubUrl == null
        ? (active?.id ?? current.id)
        : null;
    final embedded = player.state.tracks.subtitle.where((t) {
      final isExternal = t.id.startsWith('http');
      final isKnownExternal =
          excludeKnownExternalEmbedded &&
          externalSubtitles.any(
            (s) => s['display'] == t.title && s['language'] == t.language,
          );
      return t.id != 'no' && !isExternal && !isKnownExternal;
    }).toList();

    final byLang = <String, List<Map<String, dynamic>>>{};
    for (final s in externalSubtitles) {
      final key = languageGroupKey(s['language'] as String?);
      byLang.putIfAbsent(key, () => []).add(s);
    }
    final folderKeys = byLang.keys.toList()..sort(compareLanguageCodes);

    if (!context.mounted) return;

    await PlayerPopupPanel.show(
      context: context,
      title: 'Subtitles',
      leadingIcon: Icons.subtitles_outlined,
      alignment: Alignment.bottomLeft,
      margin: margin,
      anchorContext: anchorContext,
      maxHeight: 420,
      width: 320,
      trailing: ForjaPlainIcon(
        icon: Icons.tune_rounded,
        size: 18,
        color: Colors.white54,
        onTap: () {
          PlayerPopupPanel.dismiss();
          onSubtitleSettings();
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
          PlayerPopupOptionChip(
            label: 'Off',
            selected: current.id == 'no' && selectedExternalSubUrl == null,
            expanded: true,
            onTap: () {
              onSubtitleSelected?.call();
              player.setSubtitleTrack(SubtitleTrack.no());
              updateSubVisibility(SubtitleTrack.no());
              onExternalUrlChanged(null);
              PlayerPopupPanel.dismiss();
            },
          ),
          for (final t in embedded) ...[
            const SizedBox(height: 8),
            PlayerPopupOptionChip(
              label: formatPlayerTrackLabel(
                id: t.id,
                title: t.title,
                language: t.language,
              ),
              selected:
                  selectedExternalSubUrl == null && t.id == selectedSubtitleId,
              expanded: true,
              onTap: () {
                onSubtitleSelected?.call();
                player.setSubtitleTrack(t);
                updateSubVisibility(t);
                onExternalUrlChanged(null);
                PlayerPopupPanel.dismiss();
              },
            ),
          ],
          const SizedBox(height: 10),
          PlayerPopupNavRow(
            icon: Icons.upload_file_rounded,
            title: 'Load from file',
            subtitle: 'SRT · ASS · SSA · VTT',
            onTap: () async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['srt', 'ass', 'ssa', 'vtt'],
              );
              if (result != null && result.files.single.path != null) {
                onSubtitleSelected?.call();
                final file = File(result.files.single.path!);
                final content = await file.readAsString();
                final name = result.files.single.name;
                final subTrack = SubtitleTrack.data(
                  content,
                  title: name,
                  language: 'und',
                );
                player.setSubtitleTrack(subTrack);
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
                if (context.mounted) PlayerPopupPanel.dismiss();
              }
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
                  icon: hasSelected
                      ? Icons.check_circle_rounded
                      : Icons.translate_rounded,
                  title: languageDisplayName(key),
                  value: '${list.length}',
                  onTap: () async {
                    PlayerPopupPanel.dismiss();
                    await _openLanguage(
                      context,
                      langKey: key,
                      subs: list,
                      selectedExternalSubUrl: selectedExternalSubUrl,
                      loadOnlineSubtitle: loadOnlineSubtitle,
                      onExternalUrlChanged: onExternalUrlChanged,
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
                        excludeKnownExternalEmbedded:
                            excludeKnownExternalEmbedded,
                        margin: margin,
                        anchorContext: anchorContext,
                      ),
                      margin: margin,
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

  static Future<void> _openLanguage(
    BuildContext context, {
    required String langKey,
    required List<Map<String, dynamic>> subs,
    required String? selectedExternalSubUrl,
    required Future<void> Function(Map<String, dynamic> sub) loadOnlineSubtitle,
    required void Function(String? url) onExternalUrlChanged,
    VoidCallback? onSubtitleSelected,
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
              onSubtitleSelected?.call();
              await loadOnlineSubtitle(s);
              onExternalUrlChanged(s['url']?.toString());
              if (context.mounted) PlayerPopupPanel.dismiss();
            },
          );
        }).toList(),
      ),
    );
  }
}
