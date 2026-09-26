import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:forja/shared/player/controls/menus/hls_instream_subtitles.dart';
import 'package:forja/shared/player/controls/menus/player_popup_panel.dart';
import 'package:forja/shared/player/screens/utils.dart';
import 'package:forja/shared/utils/language_display.dart';
import 'package:media_kit/media_kit.dart';
import 'package:forja/shell/core/forja_shell_scope.dart';

/// Headers mpv already uses for this play URL (Referer, Cookie, User-Agent).
Map<String, String>? currentPlaybackHttpHeaders(Player player) {
  final playlist = player.state.playlist;
  final medias = playlist.medias;
  if (medias.isEmpty) return null;
  var index = playlist.index;
  if (index < 0 || index >= medias.length) index = 0;
  final headers = medias[index].httpHeaders;
  if (headers == null || headers.isEmpty) return null;
  return Map<String, String>.from(headers);
}

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
    /// Current play URL. Local HLS proxy playlists carry in-stream renditions
    /// the demuxer does not list until one is loaded.
    String? streamUrl,
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
      streamUrl: streamUrl,
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
    String? streamUrl,
    required EdgeInsets margin,
    BuildContext? anchorContext,
  }) async {
    final current = player.state.track.subtitle;
    final subtitlesOff = current.id == 'no' && selectedExternalSubUrl == null;

    void turnOffSubtitles() {
      onSubtitleSelected?.call(off: true);
      player.setSubtitleTrack(SubtitleTrack.no());
      updateSubVisibility(SubtitleTrack.no());
      onExternalUrlChanged(null);
      PlayerPopupPanel.dismiss();
    }

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
      child: _MkSubtitleFolders(
        player: player,
        streamUrl: streamUrl,
        externalSubtitles: externalSubtitles,
        selectedExternalSubUrl: selectedExternalSubUrl,
        isFetchingSubs: isFetchingSubs,
        titleSearchHint: titleSearchHint,
        onTitleSearch: onTitleSearch,
        onOpenLanguage: (key, online) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            unawaited(_openLanguage(
              context,
              langKey: key,
              online: online,
              streamUrl: streamUrl,
              selectedExternalSubUrl: selectedExternalSubUrl,
              externalSubtitles: externalSubtitles,
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
                streamUrl: streamUrl,
                margin: margin,
                anchorContext: anchorContext,
              ),
              margin: margin,
              anchorContext: anchorContext,
            ));
          });
        },
      ),
    );
  }

  static Future<void> _openLanguage(
    BuildContext context, {
    required String langKey,
    required List<Map<String, dynamic>> online,
    required String? streamUrl,
    required String? selectedExternalSubUrl,
    required List<Map<String, dynamic>> externalSubtitles,
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
      child: _MkSubtitleLanguage(
        langKey: langKey,
        online: online,
        streamUrl: streamUrl,
        selectedExternalSubUrl: selectedExternalSubUrl,
        externalSubtitles: externalSubtitles,
        player: player,
        updateSubVisibility: updateSubVisibility,
        onExternalUrlChanged: onExternalUrlChanged,
        loadOnlineSubtitle: loadOnlineSubtitle,
        onSubtitleSelected: onSubtitleSelected,
      ),
    );
  }
}

class _MkSubtitleFolders extends StatefulWidget {
  const _MkSubtitleFolders({
    required this.player,
    required this.streamUrl,
    required this.externalSubtitles,
    required this.selectedExternalSubUrl,
    required this.isFetchingSubs,
    required this.titleSearchHint,
    required this.onTitleSearch,
    required this.onOpenLanguage,
  });

  final Player player;
  final String? streamUrl;
  final List<Map<String, dynamic>> externalSubtitles;
  final String? selectedExternalSubUrl;
  final bool isFetchingSubs;
  final String? titleSearchHint;
  final VoidCallback? onTitleSearch;
  final void Function(String langKey, List<Map<String, dynamic>> online)
      onOpenLanguage;

  @override
  State<_MkSubtitleFolders> createState() => _MkSubtitleFoldersState();
}

class _MkSubtitleFoldersState extends State<_MkSubtitleFolders> {
  StreamSubscription<Tracks>? _tracksSub;
  List<HlsInStreamSubtitle> _hls = const [];
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _tracksSub = widget.player.stream.tracks.listen((_) {
      if (mounted) setState(() {});
      unawaited(_syncActive());
    });
    unawaited(_syncActive());
    unawaited(_loadHls());
  }

  @override
  void dispose() {
    _tracksSub?.cancel();
    super.dispose();
  }

  Future<void> _loadHls() async {
    final subs = await loadHlsInStreamSubtitles(
      widget.streamUrl,
      headers: currentPlaybackHttpHeaders(widget.player),
    );
    if (!mounted || subs.isEmpty) return;
    setState(() => _hls = subs);
  }

  Future<void> _syncActive() async {
    final current = widget.player.state.track.subtitle;
    final off =
        current.id == 'no' && widget.selectedExternalSubUrl == null;
    String? id;
    if (!off && widget.selectedExternalSubUrl == null) {
      final active = await resolveActiveSubtitleTrack(widget.player);
      id = active?.id ?? current.id;
    }
    if (!mounted) return;
    setState(() => _selectedId = id);
  }

  @override
  Widget build(BuildContext context) {
    final embedded = menuEmbeddedSubtitleTracks(
      widget.player,
      selectedExternalSubUrl: widget.selectedExternalSubUrl,
      externalSubtitles: widget.externalSubtitles,
    );
    final byLangOnline = <String, List<Map<String, dynamic>>>{};
    for (final s in widget.externalSubtitles) {
      final key = languageGroupKey((s['language'] ?? s['lang'])?.toString());
      byLangOnline.putIfAbsent(key, () => []).add(s);
    }
    final byLangEmbedded = <String, List<SubtitleTrack>>{};
    for (final t in embedded) {
      final key = languageGroupKey(t.language ?? t.title);
      byLangEmbedded.putIfAbsent(key, () => []).add(t);
    }
    final byLangHls = <String, List<HlsInStreamSubtitle>>{};
    for (final s in _hls) {
      final key = languageGroupKey(
        s.language.isNotEmpty ? s.language : s.name,
      );
      byLangHls.putIfAbsent(key, () => []).add(s);
    }
    final folderKeys = <String>{
      ...byLangOnline.keys,
      ...byLangEmbedded.keys,
      ...byLangHls.keys,
    }.toList()
      ..sort(compareLanguageCodes);
    final subtitlesOff =
        widget.player.state.track.subtitle.id == 'no' &&
        widget.selectedExternalSubUrl == null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      shrinkWrap: true,
      children: [
        if (widget.isFetchingSubs)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: LinearProgressIndicator(
              color: Colors.white54,
              backgroundColor: Colors.white10,
            ),
          ),
        if (widget.titleSearchHint != null &&
            widget.titleSearchHint!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Searching: ${widget.titleSearchHint}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        if (!widget.isFetchingSubs &&
            folderKeys.isEmpty &&
            widget.onTitleSearch != null)
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
              final hls = byLangHls[key] ?? const [];
              final active = widget.player.state.track.subtitle;
              final hlsSelected = hls.any(
                (s) =>
                    active.id == s.uri ||
                    (active.title != null && active.title == s.name),
              );
              final hasSelected = !subtitlesOff &&
                  (online.any((s) => s['url'] == widget.selectedExternalSubUrl) ||
                      hlsSelected ||
                      (widget.selectedExternalSubUrl == null &&
                          _selectedId != null &&
                          stream.any((t) => t.id == _selectedId)));
              return PlayerPopupNavRow(
                title: languageDisplayName(key),
                value: '${stream.length + hls.length + online.length}',
                selected: hasSelected,
                onTap: () => widget.onOpenLanguage(key, online),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _MkSubtitleLanguage extends StatefulWidget {
  const _MkSubtitleLanguage({
    required this.langKey,
    required this.online,
    required this.streamUrl,
    required this.selectedExternalSubUrl,
    required this.externalSubtitles,
    required this.player,
    required this.updateSubVisibility,
    required this.onExternalUrlChanged,
    required this.loadOnlineSubtitle,
    required this.onSubtitleSelected,
  });

  final String langKey;
  final List<Map<String, dynamic>> online;
  final String? streamUrl;
  final String? selectedExternalSubUrl;
  final List<Map<String, dynamic>> externalSubtitles;
  final Player player;
  final void Function(SubtitleTrack track) updateSubVisibility;
  final void Function(String? url) onExternalUrlChanged;
  final Future<bool> Function(Map<String, dynamic> sub) loadOnlineSubtitle;
  final PlayerSubtitleSelectionCallback? onSubtitleSelected;

  @override
  State<_MkSubtitleLanguage> createState() => _MkSubtitleLanguageState();
}

class _MkSubtitleLanguageState extends State<_MkSubtitleLanguage> {
  StreamSubscription<Tracks>? _tracksSub;
  List<HlsInStreamSubtitle> _hls = const [];
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _tracksSub = widget.player.stream.tracks.listen((_) {
      if (mounted) setState(() {});
      unawaited(_syncActive());
    });
    unawaited(_syncActive());
    unawaited(_loadHls());
  }

  @override
  void dispose() {
    _tracksSub?.cancel();
    super.dispose();
  }

  Future<void> _loadHls() async {
    final subs = await loadHlsInStreamSubtitles(
      widget.streamUrl,
      headers: currentPlaybackHttpHeaders(widget.player),
    );
    if (!mounted) return;
    final key = widget.langKey;
    setState(() {
      _hls = subs
          .where(
            (s) =>
                languageGroupKey(
                  s.language.isNotEmpty ? s.language : s.name,
                ) ==
                key,
          )
          .toList();
    });
  }

  Future<void> _syncActive() async {
    final current = widget.player.state.track.subtitle;
    if (widget.selectedExternalSubUrl != null || current.id == 'no') {
      if (mounted) setState(() => _selectedId = null);
      return;
    }
    final active = await resolveActiveSubtitleTrack(widget.player);
    if (!mounted) return;
    setState(() => _selectedId = active?.id ?? current.id);
  }

  Future<void> _pickHls(HlsInStreamSubtitle sub) async {
    widget.onSubtitleSelected?.call(
      off: false,
      language: sub.language,
      title: sub.name,
    );
    widget.onExternalUrlChanged(null);
    final track = SubtitleTrack.uri(
      sub.uri,
      title: sub.name,
      language: sub.language,
    );
    try {
      await preparePlayerExternalSubtitleSwitch(widget.player);
      await widget.player.setSubtitleTrack(track);
      widget.updateSubVisibility(track);
      PlayerPopupPanel.dismiss();
    } catch (e) {
      debugPrint('[PlayerSubtitleMenu] HLS in-stream sub failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final embedded = menuEmbeddedSubtitleTracks(
      widget.player,
      selectedExternalSubUrl: widget.selectedExternalSubUrl,
      externalSubtitles: widget.externalSubtitles,
    ).where((t) {
      return languageGroupKey(t.language ?? t.title) == widget.langKey;
    });
    final active = widget.player.state.track.subtitle;

    return ListView(
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
            selected: _selectedId != null &&
                widget.selectedExternalSubUrl == null &&
                t.id == _selectedId,
            onTap: () async {
              widget.onSubtitleSelected?.call(
                off: false,
                language: t.language,
                title: t.title,
              );
              widget.onExternalUrlChanged(null);
              try {
                await preparePlayerExternalSubtitleSwitch(widget.player);
                await widget.player.setSubtitleTrack(t);
                widget.updateSubVisibility(t);
                PlayerPopupPanel.dismiss();
              } catch (e) {
                debugPrint('[PlayerSubtitleMenu] in-stream sub failed: $e');
              }
            },
          ),
        for (final s in _hls)
          PlayerPopupListTile(
            label: s.name.isNotEmpty
                ? s.name
                : formatPlayerTrackLabel(
                    id: s.uri,
                    title: s.name,
                    language: s.language,
                  ),
            subtitle: 'In-stream',
            selected: active.id == s.uri ||
                (active.title != null && active.title == s.name),
            onTap: () => unawaited(_pickHls(s)),
          ),
        for (final s in widget.online)
          PlayerPopupListTile(
            label: s['display']?.toString() ??
                languageDisplayName(widget.langKey),
            subtitle: (s['translated'] == true ? 'Translated · ' : '') +
                (s['sourceName']?.toString() ?? 'opensubtitles'),
            selected: s['url'] == widget.selectedExternalSubUrl,
            onTap: () async {
              final ok = await widget.loadOnlineSubtitle(s);
              if (!ok) return;
              widget.onSubtitleSelected?.call(
                off: false,
                language: s['language']?.toString() ?? widget.langKey,
                title: s['display']?.toString(),
              );
              widget.onExternalUrlChanged(s['url']?.toString());
              if (context.mounted) PlayerPopupPanel.dismiss();
            },
          ),
      ],
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
        PlayerPopupChromeButton(
          icon: Icons.tune_rounded,
          tooltip: 'Subtitle settings',
          focusNode: _tuneFocus,
          onTap: () {
            PlayerPopupPanel.dismiss();
            widget.onSubtitleSettings();
          },
          onRightEdge: widget.tv
              ? () => PlayerPopupCloseFocus.request(context)
              : null,
        ),
      ],
    );
  }
}
