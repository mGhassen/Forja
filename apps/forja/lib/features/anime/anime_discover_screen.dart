// Anime discover — chip-based filters + paginated grid.
// Mirrors DiscoverScreen aesthetics.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:api/api/anime_service.dart';
import 'package:storage/storage.dart';
import 'package:forja/shared/widgets/hover_scale.dart';
import 'anime_details_screen.dart';

class AnimeDiscoverScreen extends StatefulWidget {
  const AnimeDiscoverScreen({super.key});

  @override
  State<AnimeDiscoverScreen> createState() => _AnimeDiscoverScreenState();
}

class _AnimeDiscoverScreenState extends State<AnimeDiscoverScreen> {
  final AnimeService _service = AnimeService();

  String? _genre;
  int? _year;
  String? _season;
  String? _format;
  String? _status;
  String _sort = 'TRENDING_DESC';
  int _page = 1;

  Future<List<AnimeCard>>? _future;

  static const _genres = [
    'Action', 'Adventure', 'Comedy', 'Drama', 'Ecchi', 'Fantasy',
    'Hentai', 'Horror', 'Mahou Shoujo', 'Mecha', 'Music', 'Mystery',
    'Psychological', 'Romance', 'Sci-Fi', 'Slice of Life',
    'Sports', 'Supernatural', 'Thriller',
  ];

  static const _seasons = ['WINTER', 'SPRING', 'SUMMER', 'FALL'];
  static const _formats = ['TV', 'TV_SHORT', 'MOVIE', 'OVA', 'ONA', 'SPECIAL', 'MUSIC'];
  static const _statuses = ['RELEASING', 'FINISHED', 'NOT_YET_RELEASED', 'CANCELLED', 'HIATUS'];
  static const _sorts = <String, String>{
    'TRENDING_DESC': 'Trending',
    'POPULARITY_DESC': 'Most Popular',
    'SCORE_DESC': 'Top Rated',
    'FAVOURITES_DESC': 'Most Favorited',
    'START_DATE_DESC': 'Newest',
    'START_DATE': 'Oldest',
    'TITLE_ROMAJI': 'Title (A-Z)',
  };

  @override
  void initState() {
    super.initState();
    _runQuery();
  }

  void _runQuery() {
    setState(() {
      _future = _service.browse(
        genre: _genre,
        year: _year,
        season: _season,
        format: _format,
        status: _status,
        sort: _sort,
        page: _page,
        perPage: 30,
      );
    });
  }

  void _resetAndQuery() {
    setState(() => _page = 1);
    _runQuery();
  }

  void _open(AnimeCard a) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AnimeDetailsScreen(anime: a)),
    );
  }

  Future<void> _pickFromList<T>({
    required String title,
    required List<T> items,
    required String Function(T) label,
    required T? current,
    required void Function(T?) onSelected,
  }) async {
    final picked = await showModalBottomSheet<_PickResult<T>>(
      context: context,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.3,
          expand: false,
          builder: (_, controller) => Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(
                  children: [
                    Text(title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        )),
                    const Spacer(),
                    if (current != null)
                      TextButton(
                        onPressed: () => Navigator.of(context)
                            .pop(_PickResult<T>(null, true)),
                        child: Text('Clear',
                            style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final v = items[i];
                    final selected = v == current;
                    return ListTile(
                      title: Text(label(v),
                          style: TextStyle(
                              color: selected
                                  ? AppTheme.primaryColor
                                  : Colors.white,
                              fontWeight: selected
                                  ? FontWeight.w800
                                  : FontWeight.w500)),
                      trailing: selected
                          ? Icon(Icons.check_rounded,
                              color: AppTheme.primaryColor)
                          : null,
                      onTap: () => Navigator.of(context)
                          .pop(_PickResult<T>(v, false)),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
    if (picked == null) return;
    onSelected(picked.cleared ? null : picked.value);
    _resetAndQuery();
  }

  Future<void> _pickYear() async {
    final years = List.generate(60, (i) => DateTime.now().year - i);
    return _pickFromList<int>(
      title: 'Year',
      items: years,
      label: (y) => '$y',
      current: _year,
      onSelected: (v) => _year = v,
    );
  }

  // ──────────────────────────────────────────────────────────────
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
            title: const Text(
              'Discover',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          body: Column(
            children: [
              _buildFilterRow(),
              Expanded(child: _buildGrid()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterRow() {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _filterChip(
            label: 'Sort: ${_sorts[_sort]}',
            active: true,
            onTap: () => _pickFromList<String>(
              title: 'Sort by',
              items: _sorts.keys.toList(),
              label: (k) => _sorts[k]!,
              current: _sort,
              onSelected: (v) => _sort = v ?? 'TRENDING_DESC',
            ),
          ),
          _filterChip(
            label: _genre ?? 'Genre',
            active: _genre != null,
            onTap: () => _pickFromList<String>(
              title: 'Genre',
              items: _genres,
              label: (g) => g,
              current: _genre,
              onSelected: (v) => _genre = v,
            ),
          ),
          _filterChip(
            label: _year != null ? '$_year' : 'Year',
            active: _year != null,
            onTap: _pickYear,
          ),
          _filterChip(
            label: _season != null ? _capitalize(_season!) : 'Season',
            active: _season != null,
            onTap: () => _pickFromList<String>(
              title: 'Season',
              items: _seasons,
              label: (s) => _capitalize(s),
              current: _season,
              onSelected: (v) => _season = v,
            ),
          ),
          _filterChip(
            label: _format ?? 'Format',
            active: _format != null,
            onTap: () => _pickFromList<String>(
              title: 'Format',
              items: _formats,
              label: (f) => f,
              current: _format,
              onSelected: (v) => _format = v,
            ),
          ),
          _filterChip(
            label: _status != null ? _capitalize(_status!) : 'Status',
            active: _status != null,
            onTap: () => _pickFromList<String>(
              title: 'Status',
              items: _statuses,
              label: (s) => _capitalize(s.replaceAll('_', ' ')),
              current: _status,
              onSelected: (v) => _status = v,
            ),
          ),
          if (_genre != null ||
              _year != null ||
              _season != null ||
              _format != null ||
              _status != null)
            _filterChip(
              label: 'Reset',
              active: false,
              icon: Icons.close_rounded,
              onTap: () {
                setState(() {
                  _genre = null;
                  _year = null;
                  _season = null;
                  _format = null;
                  _status = null;
                });
                _resetAndQuery();
              },
            ),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0] + s.substring(1).toLowerCase();

  Widget _filterChip({
    required String label,
    required bool active,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: active
            ? AppTheme.primaryColor.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: active
                    ? AppTheme.primaryColor.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.7)),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: active
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                    fontWeight:
                        active ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.expand_more_rounded,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return FutureBuilder<List<AnimeCard>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return Center(
            child: CircularProgressIndicator(
              color: AppTheme.primaryColor,
            ),
          );
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline_rounded,
                      color: AppTheme.primaryColor, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        final items = snap.data!;
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search_off_rounded,
                    color: Colors.white.withValues(alpha: 0.3),
                    size: 64),
                const SizedBox(height: 12),
                Text(
                  'No results — try different filters',
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

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cross,
                  childAspectRatio: 2 / 3.2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _gridCard(items[i]),
                  childCount: items.length,
                ),
              ),
            ),
            SliverToBoxAdapter(child: _buildPager()),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        );
      },
    );
  }

  Widget _gridCard(AnimeCard a) {
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
        ],
      ),
    );
  }

  Widget _buildPager() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _pagerButton(
            icon: Icons.chevron_left_rounded,
            enabled: _page > 1,
            onTap: () {
              setState(() => _page--);
              _runQuery();
            },
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Page $_page',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          _pagerButton(
            icon: Icons.chevron_right_rounded,
            enabled: true,
            onTap: () {
              setState(() => _page++);
              _runQuery();
            },
          ),
        ],
      ),
    );
  }

  Widget _pagerButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: enabled
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.white.withValues(alpha: 0.03),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            color: enabled
                ? Colors.white
                : Colors.white.withValues(alpha: 0.2),
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _PickResult<T> {
  final T? value;
  final bool cleared;
  _PickResult(this.value, this.cleared);
}
