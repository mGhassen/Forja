import 'package:flutter/material.dart';
import 'package:forja/shared/services/tracker/simkl_service.dart';
import 'package:rust/rust.dart';
import 'package:forja/shared/design/design.dart';

class MediaDetailsTrackerState {
  int? userSimklRating;
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
    await _fetchUserSimklRating();
  }

  Future<void> handleOverflow(String value) async {
    switch (value) {
      case 'simkl_rate':
        if (await SimklService().isLoggedIn()) {
          showSimklRatingDialog();
        } else if (mounted) {
          ForjaToast.error('Login to Simkl first in Settings');
        }
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
