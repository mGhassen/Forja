import 'package:flutter/material.dart';
import 'package:rust/rust.dart';

enum HeroMetaStyle { details, home }

/// Year · runtime · certification · rating row for hero surfaces.
class HeroMetaLine extends StatelessWidget {
  const HeroMetaLine({
    super.key,
    required this.movie,
    this.style = HeroMetaStyle.details,
    this.certification,
    this.imdbRating,
    this.singleLine = false,
  });

  final Movie movie;
  final HeroMetaStyle style;
  final String? certification;
  final double? imdbRating;
  final bool singleLine;

  static String formatRuntime(int minutes) {
    if (minutes <= 0) return '';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    if (style == HeroMetaStyle.home) {
      return _HomeMetaRow(movie: movie, singleLine: singleLine);
    }
    return _DetailsMetaLine(
      movie: movie,
      certification: certification,
      imdbRating: imdbRating,
    );
  }
}

class _DetailsMetaLine extends StatelessWidget {
  const _DetailsMetaLine({
    required this.movie,
    this.certification,
    this.imdbRating,
  });

  final Movie movie;
  final String? certification;
  final double? imdbRating;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];

    if (movie.releaseDate.length >= 4) {
      items.add(_metaText(movie.releaseDate.substring(0, 4)));
    }
    final runtime = HeroMetaLine.formatRuntime(movie.runtime);
    if (runtime.isNotEmpty) items.add(_metaText(runtime));
    final cert = certification?.trim();
    if (cert != null && cert.isNotEmpty) items.add(HeroCertBadge(label: cert));
    final rating = (imdbRating != null && imdbRating! > 0)
        ? imdbRating!
        : (movie.voteAverage > 0 ? movie.voteAverage : null);
    if (rating != null) {
      items.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 16, color: Colors.amber.shade400),
          const SizedBox(width: 4),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0)
            Text(
              '•',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 12),
            ),
          items[i],
        ],
      ],
    );
  }

  Widget _metaText(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.72),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _HomeMetaRow extends StatelessWidget {
  const _HomeMetaRow({required this.movie, this.singleLine = false});

  final Movie movie;
  final bool singleLine;

  @override
  Widget build(BuildContext context) {
    final rating = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
          const SizedBox(width: 4),
          Text(
            movie.voteAverage.toStringAsFixed(1),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.amber,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );

    if (singleLine) {
      return Row(
        children: [
          rating,
          if (movie.releaseDate.isNotEmpty) ...[
            const SizedBox(width: 10),
            Text(
              movie.releaseDate.split('-').first,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (movie.mediaType == 'tv') ...[
            const SizedBox(width: 10),
            _HeroMediaTypeBadge('SERIES'),
          ] else if (movie.mediaType == 'movie') ...[
            const SizedBox(width: 10),
            _HeroMediaTypeBadge('FILM'),
          ],
          if (movie.genres.isNotEmpty) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                movie.genres.take(3).join('  ·  '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 10,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          rating,
          if (movie.releaseDate.isNotEmpty)
            Text(
              movie.releaseDate.split('-').first,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          if (movie.mediaType == 'tv')
            _HeroMediaTypeBadge('SERIES')
          else if (movie.mediaType == 'movie')
            _HeroMediaTypeBadge('FILM'),
          if (movie.genres.isNotEmpty)
            Text(
              movie.genres.take(3).join('  ·  '),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}

class HeroCertBadge extends StatelessWidget {
  const HeroCertBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _HeroMediaTypeBadge extends StatelessWidget {
  const _HeroMediaTypeBadge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white60,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
