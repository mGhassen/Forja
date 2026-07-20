// Screen for managing M3U / M3U8 IPTV playlists.
// Lets the user add a playlist by URL or upload a local file, browse the
// channels inside, and delete playlists. Tapping a channel hands off to the
// existing IptvPtPlayerScreen — same player, watchdog, recovery, etc.
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:forja/features/iptv/iptv/iptv_shell_style.dart';
import 'package:forja/features/iptv/iptv/iptv_tv_focus.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/widgets/tv_browse_text_field.dart';
import 'package:forja/shared/design/design.dart';

import 'package:forja/features/iptv/iptv/channel_guide/iptv_channel_guide.dart';
import 'package:forja/features/iptv/iptv/screens/iptv_pt_player_screen.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/shell/shell_overlay_navigator.dart';
import 'm3u_models.dart';
import 'm3u_parser.dart';
import 'm3u_store.dart';

class M3uPlaylistsScreen extends StatefulWidget {
  const M3uPlaylistsScreen({super.key});

  @override
  State<M3uPlaylistsScreen> createState() => _M3uPlaylistsScreenState();
}

class _M3uPlaylistsScreenState extends State<M3uPlaylistsScreen> {
  List<M3uPlaylist> _playlists = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  final FocusNode _addUrlFocus = FocusNode(debugLabel: 'm3u-add-url');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _addUrlFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await M3uStore.loadAll();
    if (!mounted) return;
    setState(() {
      _playlists = list;
      _loading = false;
    });
    if (list.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!iptvUseTvFocus(context)) return;
        if (_addUrlFocus.canRequestFocus) _addUrlFocus.requestFocus();
      });
    }
  }

  Future<void> _persist() async {
    await M3uStore.saveAll(_playlists);
  }

  // ──────────────────────────────────────────────────────────────────────
  // Add by URL
  // ──────────────────────────────────────────────────────────────────────
  Future<void> _showAddUrlDialog() async {
    final urlCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    String? localError;
    bool busy = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ShellScope.rehost(
        context,
        StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: IptvShellStyle.surface,
          title: Text('Add M3U Playlist',
              style: IptvShellStyle.pageTitle.copyWith(fontSize: 26)),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _input(nameCtrl, 'My Playlist (optional)', 'Display name'),
                const SizedBox(height: 8),
                _input(urlCtrl, 'https://example.com/playlist.m3u', 'URL'),
                if (localError != null) ...[
                  const SizedBox(height: 10),
                  Text(localError!,
                      style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFEF4444), fontSize: 12)),
                ],
              ],
            ),
          ),
          actions: [
            IptvTextAction(
              icon: Icons.close_rounded,
              label: 'Cancel',
              color: Colors.white70,
              onPressed: busy ? null : () => Navigator.of(ctx).pop(),
            ),
            IptvPrimaryButton(
              icon: Icons.add_rounded,
              label: busy ? 'Adding…' : 'Add',
              busy: busy,
              onPressed: busy
                  ? null
                  : () async {
                      final url = urlCtrl.text.trim();
                      if (url.isEmpty) {
                        setLocal(() => localError = 'URL is required');
                        return;
                      }
                      final parsed = Uri.tryParse(url);
                      if (parsed == null ||
                          (parsed.scheme != 'http' &&
                              parsed.scheme != 'https')) {
                        setLocal(() =>
                            localError = 'URL must start with http:// or https://');
                        return;
                      }
                      setLocal(() {
                        busy = true;
                        localError = null;
                      });
                      try {
                        final channels = await M3uFetcher.fetchAndParse(url);
                        final now = DateTime.now().millisecondsSinceEpoch;
                        final playlist = M3uPlaylist(
                          id: M3uStore.newId(),
                          name: nameCtrl.text.trim().isNotEmpty
                              ? nameCtrl.text.trim()
                              : _deriveNameFromUrl(url),
                          sourceUrl: url,
                          addedAt: now,
                          updatedAt: now,
                          channels: channels,
                        );
                        if (!mounted) return;
                        setState(() {
                          _playlists = [playlist, ..._playlists];
                        });
                        await _persist();
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      } catch (e) {
                        setLocal(() {
                          busy = false;
                          localError = _friendlyError(e);
                        });
                      }
                    },
            ),
          ],
        ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // Upload from file
  // ──────────────────────────────────────────────────────────────────────
  Future<void> _pickAndImportFile() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['m3u', 'm3u8', 'txt'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _busy = false);
        return;
      }
      final f = result.files.single;
      String content;
      if (f.bytes != null) {
        content = String.fromCharCodes(f.bytes!);
      } else if (f.path != null) {
        content = await File(f.path!).readAsString();
      } else {
        throw const FormatException('Could not read file contents');
      }
      final channels = await M3uParser.parse(content);
      final now = DateTime.now().millisecondsSinceEpoch;
      final baseName = f.name.replaceAll(
          RegExp(r'\.(m3u8?|txt)$', caseSensitive: false), '');
      final playlist = M3uPlaylist(
        id: M3uStore.newId(),
        name: baseName.isEmpty ? 'Uploaded Playlist' : baseName,
        sourceUrl: null,
        addedAt: now,
        updatedAt: now,
        channels: channels,
      );
      if (!mounted) return;
      setState(() {
        _playlists = [playlist, ..._playlists];
        _error = null;
      });
      await _persist();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // Refresh / delete
  // ──────────────────────────────────────────────────────────────────────
  Future<void> _refresh(M3uPlaylist p) async {
    final url = p.sourceUrl;
    if (url == null) return;
    setState(() => _busy = true);
    try {
      final channels = await M3uFetcher.fetchAndParse(url);
      final updated = p.copyWith(
        channels: channels,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      if (!mounted) return;
      setState(() {
        _playlists = [
          for (final x in _playlists) x.id == p.id ? updated : x,
        ];
        _error = null;
      });
      await _persist();
      if (mounted) {
        ForjaToast.info('Refreshed "${p.name}" — ${channels.length} channels');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(M3uPlaylist p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => ShellScope.rehost(
        context,
        AlertDialog(
        backgroundColor: IptvShellStyle.surface,
        title: Text('Delete playlist?',
            style: IptvShellStyle.pageTitle.copyWith(fontSize: 24)),
        content: Text(
          '"${p.name}" will be removed. ${p.sourceUrl == null ? "You'll need to re-upload the file to add it again." : "You can re-add it from the URL anytime."}',
          style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          IptvTextAction(
            icon: Icons.close_rounded,
            label: 'Cancel',
            color: Colors.white70,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          IptvPrimaryButton(
            icon: Icons.delete_rounded,
            label: 'Delete',
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
        ),
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    setState(() {
      _playlists = _playlists.where((x) => x.id != p.id).toList();
    });
    await _persist();
  }

  // ──────────────────────────────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────────────────────────────
  static String _deriveNameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segs.isNotEmpty) {
        final last = segs.last
            .replaceAll(RegExp(r'\.(m3u8?|txt)$', caseSensitive: false), '');
        if (last.isNotEmpty) return last;
      }
      return uri.host.isNotEmpty ? uri.host : 'Playlist';
    } catch (_) {
      return 'Playlist';
    }
  }

  static String _friendlyError(Object e) {
    final s = e.toString();
    if (s.length > 200) return s.substring(0, 200);
    return s;
  }

  // ──────────────────────────────────────────────────────────────────────
  // UI
  // ──────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(color: IptvShellStyle.surface),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              if (_error != null) _buildErrorBanner(),
              Expanded(
                child: _loading
                    ? Center(
                        child: CircularProgressIndicator(
                            color: IptvShellStyle.accent))
                    : _playlists.isEmpty
                        ? _buildEmpty()
                        : _buildList(),
              ),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          iptvBackButton(context, onTap: () => Navigator.of(context).pop()),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'M3U Playlists',
                  style: IptvShellStyle.pageTitle.copyWith(fontSize: 28),
                ),
                Text(
                  _playlists.isEmpty
                      ? 'No playlists yet'
                      : '${_playlists.length} playlist${_playlists.length == 1 ? "" : "s"}',
                  style: GoogleFonts.plusJakartaSans(
                      color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          if (_busy)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: IptvShellStyle.accent),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFFEF4444).withValues(alpha: 0.15),
      child: Row(
        children: [
          Icon(Icons.error_outline,
              color: Color(0xFFEF4444), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFEF4444), fontSize: 12),
            ),
          ),
          iptvCloseButton(
            context,
            color: const Color(0xFFEF4444),
            size: 16,
            hitSize: 28,
            onTap: () => setState(() => _error = null),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.playlist_play_rounded,
                size: 80, color: IptvShellStyle.accent),
            const SizedBox(height: 24),
            Text('No playlists yet',
                style: IptvShellStyle.pageTitle.copyWith(fontSize: 36)),
            const SizedBox(height: 8),
            Text(
              'Add an M3U / M3U8 playlist by URL,\nor upload one from your device.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    iptvSyncRow(
      rowId: 'm3u-playlists',
      sortOrder: 0,
      itemCount: _playlists.length,
      orientation: ShellTvRowOrientation.vertical,
    );
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: _playlists.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final p = _playlists[i];
        return _PlaylistCard(
          playlist: p,
          listIndex: i,
          onTap: () {
            pushShellRoute(
              context,
              AppRouter.slideShellRoute(
                (_) => M3uChannelsScreen(playlist: p),
              ),
            );
          },
          onRefresh: p.sourceUrl == null ? null : () => _refresh(p),
          onDelete: () => _delete(p),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: IptvPrimaryButton(
              icon: Icons.link_rounded,
              label: 'Add from URL',
              focusNode: _addUrlFocus,
              tvRowId: 'm3u-bottom',
              tvItemIndex: 0,
              onPressed: _busy ? null : _showAddUrlDialog,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: IptvPrimaryButton(
              icon: Icons.upload_file_rounded,
              label: 'Upload File',
              subtle: true,
              tvRowId: 'm3u-bottom',
              tvItemIndex: 1,
              onPressed: _busy ? null : _pickAndImportFile,
            ),
          ),
        ],
      ),
    );
  }

  Widget _input(TextEditingController c, String hint, String label) {
    return TextField(
      controller: c,
      style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.plusJakartaSans(color: Colors.white60, fontSize: 12),
        hintText: hint,
        hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white24, fontSize: 12),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  final M3uPlaylist playlist;
  final VoidCallback onTap;
  final VoidCallback? onRefresh;
  final VoidCallback onDelete;
  final int? listIndex;
  const _PlaylistCard({
    required this.playlist,
    required this.onTap,
    required this.onRefresh,
    required this.onDelete,
    this.listIndex,
  });

  @override
  Widget build(BuildContext context) {
    final p = playlist;
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: IptvShellStyle.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: iptvTap(
          context: context,
          onTap: onTap,
          borderRadius: 14,
          listIndex: listIndex,
          tvRowId: 'm3u-playlists',
          tvItemIndex: listIndex,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: IptvShellStyle.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    p.sourceUrl == null
                        ? Icons.insert_drive_file_rounded
                        : Icons.cloud_rounded,
                    color: IptvShellStyle.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        p.sourceUrl ?? 'Uploaded file',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                            color: Colors.white54, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${p.channels.length} channels',
                        style: GoogleFonts.plusJakartaSans(
                            color: IptvShellStyle.accent, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (onRefresh != null)
                  IptvIconAction(
                    tooltip: 'Refresh from URL',
                    onPressed: onRefresh,
                    icon: Icons.refresh_rounded,
                    color: Colors.white70,
                  ),
                IptvIconAction(
                  tooltip: 'Delete',
                  onPressed: onDelete,
                  icon: Icons.delete_outline_rounded,
                  color: const Color(0xFFEF4444),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// CHANNELS SCREEN
// ═════════════════════════════════════════════════════════════════════════════
class M3uChannelsScreen extends StatefulWidget {
  final M3uPlaylist playlist;
  const M3uChannelsScreen({super.key, required this.playlist});

  @override
  State<M3uChannelsScreen> createState() => _M3uChannelsScreenState();
}

class _M3uChannelsScreenState extends State<M3uChannelsScreen> {
  String _query = '';
  String? _group; // null = "All"
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ScrollController _groupScrollCtrl = ScrollController();

  /// Whether the group strip currently has room to scroll left / right.
  /// Used to show/hide the arrow buttons.
  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  late final List<String> _groups;

  @override
  void initState() {
    super.initState();
    final groupOrder = <String>[];
    final seenGroups = <String>{};
    for (final c in widget.playlist.channels) {
      if (c.group.isEmpty) continue;
      if (seenGroups.add(c.group)) groupOrder.add(c.group);
    }
    _groups = groupOrder;
    _groupScrollCtrl.addListener(_updateScrollArrows);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollArrows());
  }

  void _updateScrollArrows() {
    if (!_groupScrollCtrl.hasClients) return;
    final pos = _groupScrollCtrl.position;
    final left = pos.pixels > 1.0;
    final right = pos.pixels < pos.maxScrollExtent - 1.0;
    if (left != _canScrollLeft || right != _canScrollRight) {
      setState(() {
        _canScrollLeft = left;
        _canScrollRight = right;
      });
    }
  }

  void _scrollGroups({required bool forward}) {
    if (!_groupScrollCtrl.hasClients) return;
    const step = 220.0;
    final pos = _groupScrollCtrl.position;
    final target = (_groupScrollCtrl.offset + (forward ? step : -step))
        .clamp(0.0, pos.maxScrollExtent);
    _groupScrollCtrl.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    _searchCtrl.dispose();
    _groupScrollCtrl.removeListener(_updateScrollArrows);
    _groupScrollCtrl.dispose();
    super.dispose();
  }

  List<M3uChannel> get _filtered {
    final q = _query.trim().toLowerCase();
    return widget.playlist.channels.where((c) {
      if (_group != null && c.group != _group) return false;
      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q) ||
          c.tvgName.toLowerCase().contains(q) ||
          c.group.toLowerCase().contains(q);
    }).toList();
  }

  void _play(M3uChannel ch) {
    pushShellRoute(
      context,
      AppRouter.slideShellRoute(
        (_) => IptvPtPlayerScreen(
          sources: [
            IptvPlaySource(url: ch.url, label: widget.playlist.name),
          ],
          title: ch.name,
          subtitle: ch.group.isNotEmpty ? ch.group : widget.playlist.name,
          logoUrl: ch.logo.isEmpty ? null : ch.logo,
          channelGuide: IptvChannelGuide.fromM3uPlaylist(
            widget.playlist.channels,
            initialChannel: ch,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(color: IptvShellStyle.surface),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              _buildSearchAndGroup(),
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Text(
                          'No channels match your filter',
                          style: GoogleFonts.plusJakartaSans(color: Colors.white60),
                        ),
                      )
                    : Builder(builder: (_) {
                        iptvSyncRow(
                          rowId: 'm3u-channels',
                          sortOrder: 1,
                          itemCount: list.length,
                          orientation: ShellTvRowOrientation.vertical,
                        );
                        return ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        itemCount: list.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 6),
                        itemBuilder: (_, i) =>
                            _ChannelTile(
                              channel: list[i],
                              listIndex: i,
                              onTap: () => _play(list[i]),
                            ),
                      );
                      }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          iptvBackButton(context, onTap: () => Navigator.of(context).pop()),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.playlist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: IptvShellStyle.pageTitle.copyWith(fontSize: 26),
                ),
                Text(
                  '${widget.playlist.channels.length} channels',
                  style: GoogleFonts.plusJakartaSans(
                      color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndGroup() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Column(
        children: [
          TvBrowseTextField(
            controller: _searchCtrl,
            focusNode: _searchFocus,
            onChanged: (v) => setState(() => _query = v),
            browsePlaceholder: 'Search channels...',
            browseHintStyle:
                GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 13),
            caretHeight: 18,
            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              prefixIcon:
                  Icon(Icons.search, color: Colors.white54, size: 20),
              hintText: 'Search channels...',
              hintStyle:
                  GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 13),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
          ),
          if (_groups.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: Builder(builder: (_) {
                final chipCount = _groups.length + 1;
                iptvSyncRow(
                  rowId: 'm3u-groups',
                  sortOrder: 0,
                  itemCount: chipCount,
                );
                return NotificationListener<ScrollNotification>(
                onNotification: (_) {
                  _updateScrollArrows();
                  return false;
                },
                child: Stack(
                  children: [
                    ListView.separated(
                      controller: _groupScrollCtrl,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      itemCount: chipCount,
                      separatorBuilder: (context, index) => const SizedBox(width: 6),
                      itemBuilder: (_, i) {
                        if (i == 0) {
                          return _GroupChip(
                            label: 'All',
                            selected: _group == null,
                            listIndex: i,
                            onTap: () => setState(() => _group = null),
                          );
                        }
                        final g = _groups[i - 1];
                        return _GroupChip(
                          label: g,
                          selected: _group == g,
                          listIndex: i,
                          onTap: () => setState(() => _group = g),
                        );
                      },
                    ),
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: _ScrollArrow(
                        icon: Icons.chevron_left_rounded,
                        visible: _canScrollLeft,
                        onTap: () => _scrollGroups(forward: false),
                        alignLeft: true,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: _ScrollArrow(
                        icon: Icons.chevron_right_rounded,
                        visible: _canScrollRight,
                        onTap: () => _scrollGroups(forward: true),
                        alignLeft: false,
                      ),
                    ),
                  ],
                ),
              );
              }),
            ),
          ],
        ],
      ),
    );
  }
}

class _GroupChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? listIndex;
  const _GroupChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.listIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: IptvShellStyle.chipDecoration(selected: selected),
        child: iptvTap(
          context: context,
          onTap: onTap,
          borderRadius: 10,
          scaleOnFocus: 1.0,
          listIndex: listIndex,
          tvRowId: 'm3u-groups',
          tvItemIndex: listIndex,
          onDownEdge: () => iptvFocusRowItem('m3u-channels'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScrollArrow extends StatelessWidget {
  final IconData icon;
  final bool visible;
  final VoidCallback onTap;
  final bool alignLeft;
  const _ScrollArrow({
    required this.icon,
    required this.visible,
    required this.onTap,
    required this.alignLeft,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: 36,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin:
                  alignLeft ? Alignment.centerLeft : Alignment.centerRight,
              end: alignLeft ? Alignment.centerRight : Alignment.centerLeft,
              colors: [
                const Color(0xFF141414),
                const Color(0xFF141414).withValues(alpha: 0.0),
              ],
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: iptvTap(
              context: context,
              onTap: onTap,
              borderRadius: 20,
              scaleOnFocus: 1.0,
              child: Center(
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18)),
                  ),
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  final M3uChannel channel;
  final VoidCallback onTap;
  final int? listIndex;
  const _ChannelTile({
    required this.channel,
    required this.onTap,
    this.listIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: iptvTap(
          context: context,
          onTap: onTap,
          borderRadius: 10,
          listIndex: listIndex,
          tvRowId: 'm3u-channels',
          tvItemIndex: listIndex,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                _ChannelLogo(url: channel.logo),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        channel.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                      if (channel.group.isNotEmpty)
                        Text(
                          channel.group,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                              color: Colors.white54, fontSize: 11),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.play_arrow_rounded,
                    color: IptvShellStyle.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChannelLogo extends StatelessWidget {
  final String url;
  const _ChannelLogo({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return _placeholder();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _placeholder(),
        loadingBuilder: (ctx, child, prog) {
          if (prog == null) return child;
          return _placeholder();
        },
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.live_tv_rounded,
          color: Colors.white38, size: 20),
    );
  }
}
