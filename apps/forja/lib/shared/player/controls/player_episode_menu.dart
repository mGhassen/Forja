import 'package:flutter/material.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:rust/rust.dart';

class PlayerEpisodeMenu {
  static Future<void> show(
    BuildContext context, {
    required Movie movie,
    required int currentSeason,
    required int currentEpisode,
    required Future<void> Function(int season, int episode) onEpisodeSelected,
  }) async {
    final tmdb = TmdbService();
    final seasonCount = await tmdb.getTvSeasonCount(movie.id);
    if (!context.mounted) return;

    if (seasonCount > 1) {
      await _openSeasons(
        context,
        tmdb: tmdb,
        movie: movie,
        seasonCount: seasonCount,
        currentSeason: currentSeason,
        currentEpisode: currentEpisode,
        onEpisodeSelected: onEpisodeSelected,
      );
    } else {
      await _openEpisodes(
        context,
        tmdb: tmdb,
        movie: movie,
        season: currentSeason,
        currentSeason: currentSeason,
        currentEpisode: currentEpisode,
        onEpisodeSelected: onEpisodeSelected,
        onBack: null,
      );
    }
  }

  static Future<void> _openSeasons(
    BuildContext context, {
    required TmdbService tmdb,
    required Movie movie,
    required int seasonCount,
    required int currentSeason,
    required int currentEpisode,
    required Future<void> Function(int season, int episode) onEpisodeSelected,
  }) async {
    await PlayerPopupPanel.show(
      context: context,
      title: 'Seasons',
      alignment: Alignment.bottomLeft,
      child: ListView(
        padding: const EdgeInsets.all(8),
        shrinkWrap: true,
        children: List.generate(seasonCount, (i) {
          final season = i + 1;
          final selected = season == currentSeason;
          return PlayerPopupListTile(
            badge: 'S$season',
            label: 'Season $season',
            selected: selected,
            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 18),
            onTap: () async {
              PlayerPopupPanel.dismiss();
              await _openEpisodes(
                context,
                tmdb: tmdb,
                movie: movie,
                season: season,
                currentSeason: currentSeason,
                currentEpisode: currentEpisode,
                onEpisodeSelected: onEpisodeSelected,
                onBack: () => _openSeasons(
                  context,
                  tmdb: tmdb,
                  movie: movie,
                  seasonCount: seasonCount,
                  currentSeason: currentSeason,
                  currentEpisode: currentEpisode,
                  onEpisodeSelected: onEpisodeSelected,
                ),
              );
            },
          );
        }),
      ),
    );
  }

  static Future<void> _openEpisodes(
    BuildContext context, {
    required TmdbService tmdb,
    required Movie movie,
    required int season,
    required int currentSeason,
    required int currentEpisode,
    required Future<void> Function(int season, int episode) onEpisodeSelected,
    required VoidCallback? onBack,
  }) async {
    final data = await tmdb.getTvSeasonDetails(movie.id, season);
    if (!context.mounted) return;
    final episodes = (data['episodes'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    await PlayerPopupPanel.show(
      context: context,
      title: 'Season $season',
      alignment: Alignment.bottomLeft,
      onBack: onBack,
      child: ListView(
        padding: const EdgeInsets.all(8),
        shrinkWrap: true,
        children: episodes.map((ep) {
          final num = ep['episode_number'] as int? ?? 0;
          final name = ep['name']?.toString() ?? 'Episode $num';
          final selected = season == currentSeason && num == currentEpisode;
          return PlayerPopupListTile(
            badge: 'E$num',
            label: name,
            selected: selected,
            onTap: () async {
              PlayerPopupPanel.dismiss();
              if (selected) return;
              await onEpisodeSelected(season, num);
            },
          );
        }).toList(),
      ),
    );
  }
}
