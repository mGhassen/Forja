// Anime search — debounced TextField with grid results.

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:forja/features/anime/catalog/anime_service.dart';
import 'package:forja/shared/widgets/hub/hub_poster_card.dart';
import 'anime_details_screen.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/design/design.dart';

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
      if (mounted) _focus.requestFocus();
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
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 380), () {
      _runSearch(v.trim());
    });
  }

  Future<void> _runSearch(String q) async {
    if (q.isEmpty) {
      setState(() {
        _query = '';
        _results = [];
        _loading = false;
        _error = null;
      });
      return;
    }
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
      if (!mounted || _query != q) return;
      setState(() {
        _loading = false;
        _error = 'Search failed';
      });
    }
  }

  void _open(AnimeCard a) => openAnimeDetails(context, a);

  HubPosterCard _posterCard(AnimeCard anime) {
    final subtitle = [
      if (anime.seasonYear != null) '${anime.seasonYear}',
      if (anime.episodes != null) '${anime.episodes} eps',
    ].join(' · ');

    return HubPosterCard(
      imageUrl: anime.coverUrl,
      title: anime.displayTitle,
      subtitle: subtitle.isEmpty ? null : subtitle,
      rating:
          (anime.averageScore ?? 0) > 0 ? (anime.averageScore! / 10) : null,
      badge: anime.format,
      onTap: () => _open(anime),
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
            iconTheme: const IconThemeData(color: Colors.white),
            titleSpacing: 0,
            title: TextField(
              controller: _controller,
              focusNode: _focus,
              autofocus: true,
              onChanged: _onChanged,
              onSubmitted: (v) => _runSearch(v.trim()),
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              cursorColor: ForjaShellColors.sectionAccent,
              decoration: InputDecoration(
                hintText: 'Search anime…',
                hintStyle: TextStyle(
                  color: ForjaShellColors.cinematic.textSecondary
                      .withValues(alpha: 0.7),
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
              ),
            ),
            actions: [
              if (_controller.text.isNotEmpty)
                ForjaCloseButton.compact(
                  tooltip: null,
                  color: ForjaShellColors.cinematic.textPrimary,
                  onTap: () {
                    _controller.clear();
                    _onChanged('');
                  },
                ),
              const SizedBox(width: 4),
            ],
          ),
          body: _buildBody(),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(
          color: ForjaShellColors.sectionAccent,
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: ForjaShellColors.sectionAccent,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ForjaShellColors.cinematic.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () => _runSearch(_query),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_query.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_rounded,
              color: ForjaShellColors.cinematic.textSecondary
                  .withValues(alpha: 0.4),
              size: 56,
            ),
            const SizedBox(height: 12),
            Text(
              'Start typing to search',
              style: TextStyle(
                color: ForjaShellColors.cinematic.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              color: ForjaShellColors.cinematic.textSecondary
                  .withValues(alpha: 0.4),
              size: 56,
            ),
            const SizedBox(height: 12),
            Text(
              'No results for "$_query"',
              style: TextStyle(
                color: ForjaShellColors.cinematic.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final cardWidth = HubPosterCard.cardWidth(context);
    final cardHeight = HubPosterCard.cardHeight(context);
    final padding = ShellTokens.homeSectionHorizontalPadding;

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(padding, 12, padding, 24),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: cardWidth + 16,
        mainAxisSpacing: 16,
        crossAxisSpacing: 12,
        childAspectRatio: cardWidth / cardHeight,
      ),
      itemCount: _results.length,
      itemBuilder: (_, i) => Align(
        alignment: Alignment.topCenter,
        child: _posterCard(_results[i]),
      ),
    );
  }
}
