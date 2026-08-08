import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:forja/shared/player/player/utils.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/utils/language_display.dart';
import 'package:media_kit/media_kit.dart';

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
    required Future<void> Function(Map<String, dynamic> sub) loadOnlineSubtitle,
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
    required Future<void> Function(Map<String, dynamic> sub) loadOnlineSubtitle,
    required VoidCallback onSubtitleSettings,
    PlayerSubtitleSelectionCallback? onSubtitleSelected,
    VoidCallback? onTitleSearch,
    String? titleSearchHint,
    required EdgeInsets margin,
    BuildContext? anchorContext,
  }) async {
    final current = player.state.track.subtitle;
    final active = await resolveActiveSubtitleTrack(player);
    final selectedSubtitleId = selectedExternalSubUrl == null
        ? (active?.id ?? current.id)
        : null;
    // In-stream tracks only — skip Off/auto and http URI tracks (online picker).
    final embedded = player.state.tracks.subtitle
        .where(
          (t) =>
              t.id != 'no' &&
              t.id != 'auto' &&
              !t.id.startsWith('http'),
        )
        .toList();
    final subtitlesOff = current.id == 'no' && selectedExternalSubUrl == null;

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
      title: 'Subtitles',
      leadingIcon: Icons.subtitles_outlined,
      alignment: Alignment.bottomLeft,
      margin: margin,
      anchorContext: anchorContext,
      maxHeight: 420,
      width: 320,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SubtitleHeaderChip(
            label: 'Off',
            selected: subtitlesOff,
            onTap: turnOffSubtitles,
          ),
          if (!hideLoadFile) ...[
            const SizedBox(width: 6),
            _SubtitleHeaderChip(
              label: 'File',
              icon: Icons.upload_file_rounded,
              selected: false,
              onTap: () => _pickLocalFile(
                player: player,
                updateSubVisibility: updateSubVisibility,
                onExternalUrlChanged: onExternalUrlChanged,
                onNativeSubtitleChanged: onNativeSubtitleChanged,
                onSubtitleSelected: onSubtitleSelected,
              ),
            ),
          ],
          if (onTitleSearch != null) ...[
            const SizedBox(width: 6),
            _SubtitleHeaderChip(
              label: 'Search',
              icon: Icons.search_rounded,
              selected: false,
              onTap: () {
                PlayerPopupPanel.dismiss();
                onTitleSearch();
              },
            ),
          ],
          const SizedBox(width: 6),
          ForjaPlainIcon(
            icon: Icons.tune_rounded,
            size: 18,
            color: Colors.white54,
            onTap: () {
              PlayerPopupPanel.dismiss();
              onSubtitleSettings();
            },
          ),
        ],
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
                final hasSelected = online.any(
                      (s) => s['url'] == selectedExternalSubUrl,
                    ) ||
                    (selectedExternalSubUrl == null &&
                        stream.any((t) => t.id == selectedSubtitleId));
                return PlayerPopupNavRow(
                  title: languageDisplayName(key),
                  value: '${stream.length + online.length}',
                  selected: hasSelected,
                  onTap: () async {
                    PlayerPopupPanel.dismiss();
                    await _openLanguage(
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
    required List<SubtitleTrack> embedded,
    required List<Map<String, dynamic>> online,
    required String? selectedSubtitleId,
    required String? selectedExternalSubUrl,
    required Player player,
    required void Function(SubtitleTrack track) updateSubVisibility,
    required void Function(String? url) onExternalUrlChanged,
    required Future<void> Function(Map<String, dynamic> sub) loadOnlineSubtitle,
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
              selected: selectedExternalSubUrl == null &&
                  t.id == selectedSubtitleId,
              onTap: () {
                onSubtitleSelected?.call(
                  off: false,
                  language: t.language,
                  title: t.title,
                );
                player.setSubtitleTrack(t);
                updateSubVisibility(t);
                onExternalUrlChanged(null);
                PlayerPopupPanel.dismiss();
              },
            ),
          for (final s in online)
            PlayerPopupListTile(
              label: s['display']?.toString() ?? languageDisplayName(langKey),
              subtitle: (s['translated'] == true ? 'Translated · ' : '') +
                  (s['sourceName']?.toString() ?? 'opensubtitles'),
              selected: s['url'] == selectedExternalSubUrl,
              onTap: () async {
                onSubtitleSelected?.call(
                  off: false,
                  language: s['language']?.toString() ?? langKey,
                  title: s['display']?.toString(),
                );
                await loadOnlineSubtitle(s);
                onExternalUrlChanged(s['url']?.toString());
                if (context.mounted) PlayerPopupPanel.dismiss();
              },
            ),
        ],
      ),
    );
  }
}

/// Compact header chip (Off / File) beside Settings in the Subtitles menu.
class _SubtitleHeaderChip extends StatelessWidget {
  const _SubtitleHeaderChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
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
}
