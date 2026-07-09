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
    required bool subtitlePinned,
    required void Function(SubtitleTrack track) updateSubVisibility,
    required void Function(String? url) onExternalUrlChanged,
    required void Function(bool isNative) onNativeSubtitleChanged,
    required Future<void> Function(Map<String, dynamic> sub) loadOnlineSubtitle,
    required VoidCallback onSubtitleSettings,
    required Future<void> Function() onSelectAuto,
    required VoidCallback onManualSelect,
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
      subtitlePinned: subtitlePinned,
      updateSubVisibility: updateSubVisibility,
      onExternalUrlChanged: onExternalUrlChanged,
      onNativeSubtitleChanged: onNativeSubtitleChanged,
      loadOnlineSubtitle: loadOnlineSubtitle,
      onSubtitleSettings: onSubtitleSettings,
      onSelectAuto: onSelectAuto,
      onManualSelect: onManualSelect,
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
    required bool subtitlePinned,
    required void Function(SubtitleTrack track) updateSubVisibility,
    required void Function(String? url) onExternalUrlChanged,
    required void Function(bool isNative) onNativeSubtitleChanged,
    required Future<void> Function(Map<String, dynamic> sub) loadOnlineSubtitle,
    required VoidCallback onSubtitleSettings,
    required Future<void> Function() onSelectAuto,
    required VoidCallback onManualSelect,
    required bool excludeKnownExternalEmbedded,
    required EdgeInsets margin,
    BuildContext? anchorContext,
  }) async {
    final current = player.state.track.subtitle;
    final subtitleAuto = !subtitlePinned;
    final active = await resolveActiveSubtitleTrack(player);
    String? activeLabel;
    if (subtitleAuto) {
      if (selectedExternalSubUrl != null) {
        Map<String, dynamic>? external;
        for (final sub in externalSubtitles) {
          if (sub['url'] == selectedExternalSubUrl) {
            external = sub;
            break;
          }
        }
        activeLabel = external?['display']?.toString() ??
            external?['language']?.toString();
      } else if (active != null) {
        activeLabel = formatPlayerTrackLabel(
          id: active.id,
          title: active.title,
          language: active.language,
        );
      } else if (current.id == 'no') {
        activeLabel = 'Off';
      }
    }
    final embedded = player.state.tracks.subtitle.where((t) {
      final isExternal = t.id.startsWith('http');
      final isKnownExternal = excludeKnownExternalEmbedded &&
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
        padding: const EdgeInsets.all(8),
        shrinkWrap: true,
        children: [
          if (isFetchingSubs)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(
                color: Colors.white54,
                backgroundColor: Colors.white10,
              ),
            ),
          PlayerPopupListTile(
            label: 'Off',
            selected: subtitlePinned && current.id == 'no' && selectedExternalSubUrl == null,
            onTap: () {
              onManualSelect();
              player.setSubtitleTrack(SubtitleTrack.no());
              updateSubVisibility(SubtitleTrack.no());
              onExternalUrlChanged(null);
              PlayerPopupPanel.dismiss();
            },
          ),
          PlayerPopupListTile(
            badge: 'AUTO',
            label: 'Auto',
            subtitle: subtitleAuto ? activeLabel : null,
            selected: subtitleAuto,
            onTap: () async {
              PlayerPopupPanel.dismiss();
              if (!subtitleAuto) await onSelectAuto();
            },
          ),
          PlayerPopupListTile(
            label: 'Load from file',
            onTap: () async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['srt', 'ass', 'ssa', 'vtt'],
              );
              if (result != null && result.files.single.path != null) {
                onManualSelect();
                final file = File(result.files.single.path!);
                final content = await file.readAsString();
                final name = result.files.single.name;
                final subTrack = SubtitleTrack.data(content, title: name, language: 'und');
                player.setSubtitleTrack(subTrack);
                final isAssFile = name.toLowerCase().endsWith('.ass') ||
                    name.toLowerCase().endsWith('.ssa');
                onExternalUrlChanged(null);
                onNativeSubtitleChanged(isAssFile);
                if (player.platform is NativePlayer) {
                  (player.platform as NativePlayer)
                      .setProperty('sub-visibility', isAssFile ? 'yes' : 'no');
                }
                if (context.mounted) PlayerPopupPanel.dismiss();
              }
            },
          ),
          ...embedded.map((t) {
            final sel = subtitlePinned &&
                t.id == current.id &&
                selectedExternalSubUrl == null;
            return PlayerPopupListTile(
              label: formatPlayerTrackLabel(
                id: t.id,
                title: t.title,
                language: t.language,
              ),
              subtitle: 'Embedded',
              selected: sel,
              onTap: () {
                onManualSelect();
                player.setSubtitleTrack(t);
                updateSubVisibility(t);
                onExternalUrlChanged(null);
                PlayerPopupPanel.dismiss();
              },
            );
          }),
          ...folderKeys.map((key) {
            final list = byLang[key]!;
            final hasSelected = subtitlePinned &&
                list.any((s) => s['url'] == selectedExternalSubUrl);
            return PlayerPopupListTile(
              label: languageDisplayName(key),
              badge: '${list.length}',
              selected: hasSelected,
              trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 18),
              onTap: () async {
            PlayerPopupPanel.dismiss();
                await _openLanguage(
                  context,
                  langKey: key,
                  subs: list,
                  selectedExternalSubUrl: selectedExternalSubUrl,
                  loadOnlineSubtitle: loadOnlineSubtitle,
                  onExternalUrlChanged: onExternalUrlChanged,
                  onManualSelect: onManualSelect,
                  onRoot: () => _openRoot(
                    context,
                    player: player,
                    externalSubtitles: externalSubtitles,
                    selectedExternalSubUrl: selectedExternalSubUrl,
                    isFetchingSubs: isFetchingSubs,
                    subtitlePinned: subtitlePinned,
                    updateSubVisibility: updateSubVisibility,
                    onExternalUrlChanged: onExternalUrlChanged,
                    onNativeSubtitleChanged: onNativeSubtitleChanged,
                    loadOnlineSubtitle: loadOnlineSubtitle,
                    onSubtitleSettings: onSubtitleSettings,
                    onSelectAuto: onSelectAuto,
                    onManualSelect: onManualSelect,
                    excludeKnownExternalEmbedded: excludeKnownExternalEmbedded,
                    margin: margin,
                    anchorContext: anchorContext,
                  ),
                  margin: margin,
                  anchorContext: anchorContext,
                );
              },
            );
          }),
          if (embedded.isEmpty && folderKeys.isEmpty && !isFetchingSubs)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text('No subtitles found', style: TextStyle(color: Colors.white38)),
              ),
            ),
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
    required VoidCallback onManualSelect,
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
        padding: const EdgeInsets.all(8),
        shrinkWrap: true,
        children: subs.map((s) {
          final sel = s['url'] == selectedExternalSubUrl;
          final source = (s['translated'] == true ? 'Translated · ' : '') +
              (s['sourceName']?.toString() ?? 'opensubtitles');
          return PlayerPopupListTile(
            label: s['display']?.toString() ?? languageDisplayName(langKey),
            subtitle: source,
            selected: sel,
            onTap: () async {
              onManualSelect();
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
