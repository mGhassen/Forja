// AnimeSlayer search screen.

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:forja/features/anime_arabic/catalog/anime_arabic_service.dart';
import 'package:forja/shared/widgets/hover_scale.dart';
import 'anime_arabic_details_screen.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/design/design.dart';

class AnimeArabicSearchScreen extends StatefulWidget {
  const AnimeArabicSearchScreen({super.key});

  @override
  State<AnimeArabicSearchScreen> createState() =>
      _AnimeArabicSearchScreenState();
}

class _AnimeArabicSearchScreenState extends State<AnimeArabicSearchScreen> {
  final AnimeArabicService _service = AnimeArabicService();
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _debounce;
  String _lastQuery = '';
  bool _loading = false;
  String? _error;
  List<ArabicAnimeCard> _results = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 380), () => _run(q));
  }

  Future<void> _run(String q) async {
    final query = q.trim();
    if (query == _lastQuery) return;
    _lastQuery = query;
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _service.search(query);
      if (!mounted || query != _lastQuery) return;
      setState(() {
        _results = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: TextField(
          controller: _ctrl,
          focusNode: _focus,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          textDirection: TextDirection.rtl,
          decoration: InputDecoration(
            hintText: 'ابحث عن أنمي…',
            hintStyle:
                TextStyle(color: Colors.white.withValues(alpha: 0.4)),
            border: InputBorder.none,
            suffixIcon: _ctrl.text.isNotEmpty
                ? ForjaCloseButton.compact(
                    tooltip: null,
                    color: Colors.white70,
                    onTap: () {
                      _ctrl.clear();
                      _onChanged('');
                    },
                  )
                : null,
          ),
          onChanged: (v) {
            setState(() {});
            _onChanged(v);
          },
        ),
      ),
      body: _buildBody(isLandscape),
    );
  }

  Widget _buildBody(bool isLandscape) {
    if (_loading) {
      return Center(
          child: CircularProgressIndicator(color: ForjaShellColors.sectionAccent));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Search failed: $_error',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search,
                  color: ForjaShellColors.cinematic.textSecondary.withValues(alpha: 0.4),
                  size: 56),
              const SizedBox(height: 12),
              Text(
                _ctrl.text.isEmpty
                    ? 'ابدأ الكتابة للبحث'
                    : 'لم يتم العثور على نتائج',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isLandscape ? 6 : 3,
        mainAxisSpacing: 14,
        crossAxisSpacing: 12,
        childAspectRatio: 0.62,
      ),
      itemCount: _results.length,
      itemBuilder: (_, i) => _resultCard(_results[i]),
    );
  }

  Widget _resultCard(ArabicAnimeCard c) {
    return HoverScale(
      radius: 12,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AnimeArabicDetailsScreen(anime: c),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 0.7,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (c.cover != null && c.cover!.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: c.cover!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          Container(color: AppTheme.bgCard),
                      errorWidget: (_, _, _) =>
                          Container(color: AppTheme.bgCard),
                    )
                  else
                    Container(color: AppTheme.bgCard),
                  if (c.tag != null && c.tag!.isNotEmpty)
                    Positioned(
                      left: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          c.tag!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  if (c.rating != null && c.rating!.isNotEmpty)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFFFB300),
                              Color(0xFFFF8F00),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded,
                                color: Colors.white, size: 10),
                            const SizedBox(width: 2),
                            Text(
                              c.rating!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            c.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
