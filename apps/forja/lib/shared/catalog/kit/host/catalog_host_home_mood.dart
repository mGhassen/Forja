import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:forja/features/home/widgets/home_mood_section.dart';
import 'package:forja/shell/app_router.dart';
import 'package:rust/rust.dart';

/// Host-owned Home mood row — exact [HomeMoodSection] + HomeMovieCard results.
class CatalogHostHomeMood extends StatefulWidget {
  const CatalogHostHomeMood({
    super.key,
    required this.options,
    this.title = 'Moods',
    this.tvRowOrder = 3,
  });

  /// Pack mood options (`id`, `label`, `icon`, `accent`, `movieGenres`, `tvGenres`).
  final List<Map<String, dynamic>> options;
  final String title;
  final int tvRowOrder;

  @override
  State<CatalogHostHomeMood> createState() => _CatalogHostHomeMoodState();
}

class _CatalogHostHomeMoodState extends State<CatalogHostHomeMood> {
  final _api = TmdbApi();
  late String _selectedId;
  Future<List<Movie>>? _future;
  List<Movie>? _pool;
  int _token = 0;

  static const _fallbackMoods = <({
    String id,
    String label,
    IconData icon,
    Color accent,
    List<int> movieGenres,
    List<int> tvGenres,
  })>[
    (
      id: 'mind',
      label: 'Mind-Bending',
      icon: Icons.psychology_rounded,
      accent: Color(0xFF8B5CF6),
      movieGenres: [878, 9648],
      tvGenres: [10765, 9648],
    ),
  ];

  @override
  void initState() {
    super.initState();
    final moods = _moods;
    _selectedId = moods.first.id;
    _reload(_selectedId);
  }

  IconData _icon(String? name) => switch ((name ?? '').trim()) {
        'psychology' => Icons.psychology_rounded,
        'wb_sunny' => Icons.wb_sunny_rounded,
        'dark_mode' => Icons.dark_mode_rounded,
        'favorite' => Icons.favorite_rounded,
        'bedtime' => Icons.bedtime_rounded,
        'local_fire_department' => Icons.local_fire_department_rounded,
        'brush' => Icons.brush_rounded,
        'theaters' => Icons.theaters_rounded,
        _ => Icons.circle_outlined,
      };

  Color _accent(String? hex) {
    final raw = (hex ?? '').trim().replaceFirst('#', '');
    if (raw.length != 6) return const Color(0xFF8B5CF6);
    final v = int.tryParse(raw, radix: 16);
    if (v == null) return const Color(0xFF8B5CF6);
    return Color(0xFF000000 | v);
  }

  List<int> _ints(dynamic raw) {
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is num)
          e.toInt()
        else if (int.tryParse(e.toString()) case final n?)
          n,
    ];
  }

  List<
      ({
        String id,
        String label,
        IconData icon,
        Color accent,
        List<int> movieGenres,
        List<int> tvGenres,
      })> get _moods {
    final out = <({
      String id,
      String label,
      IconData icon,
      Color accent,
      List<int> movieGenres,
      List<int> tvGenres,
    })>[];
    for (final o in widget.options) {
      final id = (o['id'] ?? '').toString().trim();
      if (id.isEmpty) continue;
      out.add((
        id: id,
        label: (o['label'] ?? id).toString(),
        icon: _icon(o['icon']?.toString()),
        accent: _accent(o['accent']?.toString()),
        movieGenres: _ints(o['movieGenres']),
        tvGenres: _ints(o['tvGenres']),
      ));
    }
    return out.isEmpty ? _fallbackMoods : out;
  }

  List<Movie> _interleave(List<Movie> movies, List<Movie> tv) {
    final out = <Movie>[];
    final seen = <String>{};
    void add(Movie m) {
      final key = '${m.mediaType}:${m.id}';
      if (seen.add(key)) out.add(m);
    }

    final maxLen = math.max(movies.length, tv.length);
    for (var i = 0; i < maxLen; i++) {
      if (i < movies.length) add(movies[i]);
      if (i < tv.length) add(tv[i]);
    }
    return out;
  }

  Future<void> _reload(String moodId) async {
    final moods = _moods;
    final mood = moods.firstWhere(
      (m) => m.id == moodId,
      orElse: () => moods.first,
    );
    final token = ++_token;
    setState(() {
      _selectedId = mood.id;
      _pool = null;
      _future = () async {
        try {
          final results = await Future.wait([
            _api
                .discoverMovies(
                  genres: mood.movieGenres,
                  minRating: 6.0,
                  page: 1,
                )
                .catchError((_) => <Movie>[]),
            _api
                .discoverTvShows(
                  genres: mood.tvGenres,
                  minRating: 6.0,
                  page: 1,
                )
                .catchError((_) => <Movie>[]),
          ]);
          final merged = _interleave(results[0], results[1]);
          if (mounted && token == _token) {
            setState(() => _pool = merged);
          }
          return merged;
        } catch (_) {
          return const <Movie>[];
        }
      }();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Title is painted by HomeMoodSection's circle row header path via moods —
    // HomeMoodSection does not take a title string; old Home used mood circles
    // only (no "Moods" ShellSectionTitle above). Keep parity.
    return HomeMoodSection(
      key: ValueKey('home-mood-$_selectedId'),
      moods: _moods,
      selectedId: _selectedId,
      onSelect: _reload,
      future: _pool != null ? Future<List<Movie>>.value(_pool!) : _future,
      onMovieTap: (m) => AppRouter.openDetails(context, movie: m),
      compactTop: false,
      tvRowOrder: widget.tvRowOrder,
    );
  }
}
