import 'package:flutter/material.dart';
import 'package:forja/shared/services/tracker/simkl_service.dart';
import 'package:forja/shared/services/tracker/trakt_service.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:rust/rust.dart';
import 'package:forja/shared/design/design.dart';

class MediaDetailsTrackerState {
  int? userTraktRating;
  int? userSimklRating;
  bool isInTraktCollection = false;
}

class MediaDetailsTrackerHandlers {
  MediaDetailsTrackerHandlers({
    required this.context,
    required this.state,
    required this.movie,
    required this.season,
    required this.episode,
    required this.onChanged,
  });

  final BuildContext context;
  final MediaDetailsTrackerState state;
  final Movie Function() movie;
  final int Function() season;
  final int Function() episode;
  final VoidCallback onChanged;

  bool get mounted => context.mounted;

  Future<void> load() async {
    await Future.wait([
      _fetchUserTraktRating(),
      _fetchUserSimklRating(),
      _fetchTraktCollectionStatus(),
    ]);
  }

  Future<void> handleOverflow(String value) async {
    switch (value) {
      case 'trakt_rate':
        if (await TraktService().isLoggedIn()) {
          showTraktRatingDialog();
        } else if (mounted) {
          ForjaToast.error('Login to Trakt first in Settings');
        }
      case 'simkl_rate':
        if (await SimklService().isLoggedIn()) {
          showSimklRatingDialog();
        } else if (mounted) {
          ForjaToast.error('Login to Simkl first in Settings');
        }
      case 'collect':
        await _toggleTraktCollection();
      case 'checkin':
        await _traktCheckin();
      case 'trakt_list':
        await _addToTraktList();
    }
  }

  Future<void> _fetchUserTraktRating() async {
    try {
      if (!await TraktService().isLoggedIn()) return;
      final type = movie().mediaType == 'tv' ? 'shows' : 'movies';
      final allRatings = await TraktService().getAllRatings();
      final ratings = allRatings[type] as List? ?? [];
      for (final r in ratings) {
        final show = r['show'] ?? r['movie'];
        if (show != null) {
          final ids = show['ids'] as Map<String, dynamic>?;
          if (ids != null && ids['tmdb'] == movie().id) {
            state.userTraktRating = r['rating'] as int?;
            onChanged();
            return;
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _rateTraktItem(int rating) async {
    final success = await TraktService().rateItem(
      tmdbId: movie().id,
      mediaType: movie().mediaType,
      rating: rating,
    );
    if (success && mounted) {
      state.userTraktRating = rating;
      onChanged();
    }
  }

  Future<void> _removeTraktRating() async {
    final success = await TraktService().removeRating(
      tmdbId: movie().id,
      mediaType: movie().mediaType,
    );
    if (success && mounted) {
      state.userTraktRating = null;
      onChanged();
    }
  }

  Future<void> _fetchUserSimklRating() async {
    try {
      if (!await SimklService().isLoggedIn()) return;
      final ratings = await SimklService().getRatings();
      for (final r in ratings) {
        final ids = r['ids'] as Map<String, dynamic>? ?? {};
        if (ids['tmdb'] == movie().id) {
          state.userSimklRating = r['rating'] as int?;
          onChanged();
          return;
        }
      }
    } catch (_) {}
  }

  Future<void> _rateSimklItem(int rating) async {
    final success = await SimklService().addRating(
      tmdbId: movie().id,
      mediaType: movie().mediaType,
      rating: rating,
    );
    if (success && mounted) {
      state.userSimklRating = rating;
      onChanged();
    }
  }

  Future<void> _removeSimklRating() async {
    final success = await SimklService().removeRating(
      tmdbId: movie().id,
      mediaType: movie().mediaType,
    );
    if (success && mounted) {
      state.userSimklRating = null;
      onChanged();
    }
  }

  Future<void> _fetchTraktCollectionStatus() async {
    try {
      if (!await TraktService().isLoggedIn()) return;
      final collection = await TraktService().getCollection();
      final type = movie().mediaType == 'tv' ? 'shows' : 'movies';
      final items = collection[type] as List? ?? [];
      for (final item in items) {
        final media = item['show'] ?? item['movie'];
        if (media != null) {
          final ids = media['ids'] as Map<String, dynamic>? ?? {};
          if (ids['tmdb'] == movie().id) {
            state.isInTraktCollection = true;
            onChanged();
            return;
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _toggleTraktCollection() async {
    if (!await TraktService().isLoggedIn()) {
      if (!mounted) return;
      ForjaToast.error('Login to Trakt first in Settings');
      return;
    }
    if (state.isInTraktCollection) {
      final success = await TraktService().removeFromCollection(
        tmdbId: movie().id,
        mediaType: movie().mediaType,
      );
      if (success && mounted) {
        state.isInTraktCollection = false;
        onChanged();
      }
    } else {
      final success = await TraktService().addToCollection(
        tmdbId: movie().id,
        mediaType: movie().mediaType,
      );
      if (success && mounted) {
        state.isInTraktCollection = true;
        onChanged();
      }
    }
  }

  Future<void> _traktCheckin() async {
    if (!await TraktService().isLoggedIn()) {
      if (!mounted) return;
      ForjaToast.error('Login to Trakt first in Settings');
      return;
    }
    final success = await TraktService().checkin(
      tmdbId: movie().id,
      mediaType: movie().mediaType,
      season: movie().mediaType == 'tv' ? season() : null,
      episode: movie().mediaType == 'tv' ? episode() : null,
    );
    if (!mounted) return;
    if (success) {
      ForjaToast.success('Checked in on Trakt!');
    } else {
      await _retryTraktCheckinAfterCancel();
    }
  }

  Future<void> _retryTraktCheckinAfterCancel() async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        title: const Text(
          'Check-in Failed',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'You may already have an active check-in.\nCancel existing and retry?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, retry'),
          ),
        ],
      ),
    );
    if (shouldCancel != true || !mounted) return;

    final cancelled = await TraktService().cancelCheckin();
    if (!cancelled || !mounted) return;
    final retrySuccess = await TraktService().checkin(
      tmdbId: movie().id,
      mediaType: movie().mediaType,
      season: movie().mediaType == 'tv' ? season() : null,
      episode: movie().mediaType == 'tv' ? episode() : null,
    );
    if (!mounted) return;
    ForjaToast.show(
      retrySuccess ? 'Checked in on Trakt!' : 'Check-in failed',
      kind: retrySuccess ? ForjaToastKind.success : ForjaToastKind.error,
    );
  }

  void showTraktRatingDialog() => _showTraktRatingDialog();

  Future<void> _addToTraktList() async {
    if (!await TraktService().isLoggedIn()) {
      if (!mounted) return;
      ForjaToast.error('Login to Trakt first in Settings');
      return;
    }

    final lists = await TraktService().getUserLists();
    if (!context.mounted || lists.isEmpty) {
      if (mounted) {
        ForjaToast.warning('No Trakt lists found. Create one in Lists screen.');
      }
      return;
    }

    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        title: const Text(
          'Add to Trakt List',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: lists.length,
            itemBuilder: (_, i) {
              final list = lists[i];
              final name = list['name']?.toString() ?? 'Untitled';
              final count = list['item_count'] ?? 0;
              return ListTile(
                title: Text(name, style: const TextStyle(color: Colors.white)),
                subtitle: Text(
                  '$count items',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
                onTap: () => Navigator.pop(ctx, list),
              );
            },
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;

    final slug = selected['ids']?['slug']?.toString() ?? '';
    if (slug.isEmpty) return;

    final type = movie().mediaType == 'tv' ? 'shows' : 'movies';
    final entry = <String, dynamic>{
      'ids': {'tmdb': movie().id},
    };
    final success = await TraktService().addToList(
      listId: slug,
      movies: type == 'movies' ? [entry] : [],
      shows: type == 'shows' ? [entry] : [],
    );
    if (!mounted) return;
    ForjaToast.show(
      success ? 'Added to "${selected['name']}"' : 'Failed to add to list',
      kind: success ? ForjaToastKind.success : ForjaToastKind.error,
    );
  }

  void _showTraktRatingDialog() {
    int selected = state.userTraktRating ?? 5;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF141414),
          title: const Text(
            'Rate on Trakt',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(10, (i) {
                  final val = i + 1;
                  return GestureDetector(
                    onTap: () => setDialogState(() => selected = val),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Icon(
                        val <= selected
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: const Color(0xFFFFD700),
                        size: 28,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Text(
                '$selected / 10',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: [
            if (state.userTraktRating != null)
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _removeTraktRating();
                },
                child: const Text(
                  'Remove',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _rateTraktItem(selected);
              },
              child: Text(
                'Rate',
                style: TextStyle(color: AppTheme.primaryColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void showSimklRatingDialog() => _showSimklRatingDialog();

  void _showSimklRatingDialog() {
    int selected = state.userSimklRating ?? 5;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF141414),
          title: const Text(
            'Rate on Simkl',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(10, (i) {
                  final val = i + 1;
                  return GestureDetector(
                    onTap: () => setDialogState(() => selected = val),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Icon(
                        val <= selected
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: const Color(0xFF0BF5E5),
                        size: 28,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Text(
                '$selected / 10',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: [
            if (state.userSimklRating != null)
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _removeSimklRating();
                },
                child: const Text(
                  'Remove',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _rateSimklItem(selected);
              },
              child: const Text(
                'Rate',
                style: TextStyle(color: Color(0xFF0BF5E5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
