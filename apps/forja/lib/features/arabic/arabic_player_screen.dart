import 'package:flutter/material.dart';
import 'package:forja/shared/catalog/protocol.dart';
import 'package:forja/shared/catalog/runtime.dart';
import 'package:forja/shared/extractors/core/embed_stream_resolve.dart';
import 'package:forja/shared/player/player_screen.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:rust/rust.dart';

/// Loads pack `stream` for an opaque video id, then opens [PlayerScreen].
class ArabicPlayerScreen extends StatefulWidget {
  const ArabicPlayerScreen({
    super.key,
    required this.pluginId,
    required this.videoId,
    required this.title,
  });

  final String pluginId;
  final String videoId;
  final String title;

  @override
  State<ArabicPlayerScreen> createState() => _ArabicPlayerScreenState();
}

class _ArabicPlayerScreenState extends State<ArabicPlayerScreen> {
  bool _loading = true;
  String _status = 'جاري تحميل السيرفرات...';

  @override
  void initState() {
    super.initState();
    _loadAndPlay();
  }

  Future<void> _loadAndPlay() async {
    setState(() {
      _loading = true;
      _status = 'جاري تحميل السيرفرات...';
    });

    final env = await CatalogRuntime.instance.run(
      pluginId: widget.pluginId,
      action: 'stream',
      params: {'id': widget.videoId},
      forceRefresh: true,
    );
    if (!mounted) return;

    if (!env.ok || env.streams.isEmpty) {
      setState(() {
        _loading = false;
        _status = 'لا توجد سيرفرات';
      });
      return;
    }

    final streams = List<CatalogStream>.from(env.streams);
    const priorityHosts = ['vidmoly'];
    streams.sort((a, b) {
      final aPri = priorityHosts.any((h) => a.url.contains(h)) ? 0 : 1;
      final bPri = priorityHosts.any((h) => b.url.contains(h)) ? 0 : 1;
      return aPri.compareTo(bPri);
    });

    for (var i = 0; i < streams.length; i++) {
      if (!mounted) return;
      final server = streams[i];
      setState(() {
        _status =
            'جاري استخراج الرابط من ${server.name.isEmpty ? 'سيرفر' : server.name}... (${i + 1}/${streams.length})';
      });

      if (server.isDirect) {
        final sources = streams
            .map(
              (s) => StreamSource(
                url: s.url,
                title: s.name.isEmpty ? 'Server' : s.name,
                type: s.isDirect
                    ? (s.url.contains('.m3u8')
                        ? 'hls'
                        : s.url.contains('.mpd')
                            ? 'dash'
                            : 'mp4')
                    : 'arabic_embed',
              ),
            )
            .toList();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PlayerScreen(
              streamUrl: server.url,
              title: widget.title,
              sources: sources,
              activeProvider: 'arabic',
            ),
          ),
        );
        return;
      }

      final result = await EmbedStreamResolve.resolve(server.url);
      if (result != null && mounted) {
        final sources = streams
            .map(
              (s) => StreamSource(
                url: s.url,
                title: s.name.isEmpty ? 'Server' : s.name,
                type: s.isDirect ? 'mp4' : 'arabic_embed',
              ),
            )
            .toList();
        sources[i] = StreamSource(
          url: result.url,
          title: server.name.isEmpty ? 'Server' : server.name,
          type: result.url.contains('.m3u8')
              ? 'hls'
              : result.url.contains('.mpd')
                  ? 'dash'
                  : 'mp4',
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PlayerScreen(
              streamUrl: result.url,
              audioUrl: result.audioUrl,
              title: widget.title,
              headers: result.headers,
              sources: sources,
              activeProvider: 'arabic',
            ),
          ),
        );
        return;
      }
    }

    if (mounted) {
      setState(() {
        _loading = false;
        _status = 'فشل استخراج الرابط من جميع السيرفرات';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.title,
          textDirection: TextDirection.rtl,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: _loading ? _buildLoading() : _buildFailed(),
      ),
    );
  }

  Widget _buildLoading() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(color: AppTheme.primaryColor),
      ],
    );
  }

  Widget _buildFailed() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
          const SizedBox(height: 16),
          Text(
            _status,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: _loadAndPlay,
            child: const Text(
              'إعادة المحاولة',
              style: TextStyle(color: AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }
}
