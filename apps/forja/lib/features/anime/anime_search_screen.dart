// Anime search — debounced TextField with grid results.

import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:api/api/anime_service.dart';
import 'package:storage/storage.dart';
import 'package:forja/shared/widgets/hover_scale.dart';
import 'anime_details_screen.dart';

class AnimeSearchScreen extends StatefulWidget {
  const AnimeSearchScreen({super.key});

  @override
  State<AnimeSearchScreen> createState() => _AnimeSearchScreenState();
}

class _AnimeSearchScreenState extends State<AnimeSearchScreen> {
  final AnimeService _service = AnimeService();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _debounce;

  String _query = '';
  bool _loading = false;
  List<AnimeCard> _results = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    final q = v.trim();
    if (q.isEmpty) {
      setState(() {
        _query = '';
        _results = [];
        _loading = false;
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () => _run(q));
  }

  Future<void> _run(String q) async {
    setState(() {
      _query = q;
      _loading = true;
      _error = null;
    });
    try {
      final res = await _service.search(q, perPage: 30);
      if (!mounted || _query != q) return;
      setState(() {
        _results = res;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Search failed';
      });
    }
  }

  void _open(AnimeCard a) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AnimeDetailsScreen(anime: a)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemePreset>(
      valueListenable: AppTheme.themeNotifier,
      builder: (context, _, _) {
        return Scaffold(
          backgroundColor: AppTheme.bgDark,
          appBar: AppBar(
            backgroundColor: AppTheme.bgDark,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 18),
              onPressed: () => Navigator.of(context).pop(),
            ),
            titleSpacing: 0,
            title: TextField(
              controller: _controller,
              focusNode: _focus,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Search anime…',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.38),
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
              ),
            ),
            actions: [
              if (_controller.text.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: Colors.white.withValues(alpha: 0.7)),
                  onPressed: () {
                    _controller.clear();
                    _onChanged('');
                  },
                ),
            ],
          ),
          body: _buildBody(),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_query.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_rounded,
                color: Colors.white.withValues(alpha: 0.2), size: 80),
            const SizedBox(height: 16),
            Text(
              'Search anime by title…',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                color: Colors.white.withValues(alpha: 0.2), size: 80),
            const SizedBox(height: 16),
            Text(
              'No results for "$_query"',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    final w = MediaQuery.of(context).size.width;
    final cross = w > 1200
        ? 6
        : w > 900
            ? 5
            : w > 600
                ? 4
                : 3;

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cross,
        childAspectRatio: 2 / 3.2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 12,
      ),
      itemCount: _results.length,
      itemBuilder: (_, i) => _buildCard(_results[i]),
    );
  }

  Widget _buildCard(AnimeCard a) {
    return HoverScale(
      onTap: () => _open(a),
      radius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (a.coverUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: a.coverUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          Container(color: AppTheme.bgCard),
                      errorWidget: (_, _, _) => Container(
                        color: AppTheme.bgCard,
                        child: const Icon(Icons.broken_image,
                            color: Colors.white24),
                      ),
                    ),
                  if ((a.averageScore ?? 0) > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded,
                                color: Colors.amber, size: 11),
                            const SizedBox(width: 2),
                            Text(
                              ((a.averageScore ?? 0) / 10)
                                  .toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (a.format != null && a.format!.isNotEmpty)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor
                              .withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          a.format!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            a.displayTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          if (a.seasonYear != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${a.seasonYear}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 10.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
