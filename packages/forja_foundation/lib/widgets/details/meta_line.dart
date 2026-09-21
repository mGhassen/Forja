import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_details_tokens.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';

enum MetaLineStyle { details, home }

/// Year · runtime · certification · rating row — primitive fields only.
class MetaLine extends StatelessWidget {
  const MetaLine({
    super.key,
    required this.releaseDate,
    this.mediaType = '',
    this.runtimeMinutes = 0,
    this.voteAverage = 0,
    this.genres = const [],
    this.style = MetaLineStyle.details,
    this.certification,
    this.imdbRating,
    this.singleLine = false,
  });

  final String releaseDate;
  final String mediaType;
  final int runtimeMinutes;
  final double voteAverage;
  final List<String> genres;
  final MetaLineStyle style;
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
    if (style == MetaLineStyle.home) {
      return _HomeMetaRow(
        releaseDate: releaseDate,
        mediaType: mediaType,
        voteAverage: voteAverage,
        genres: genres,
        singleLine: singleLine,
      );
    }
    return _DetailsMetaLine(
      releaseDate: releaseDate,
      mediaType: mediaType,
      runtimeMinutes: runtimeMinutes,
      voteAverage: voteAverage,
      certification: certification,
      imdbRating: imdbRating,
    );
  }
}

class _DetailsMetaLine extends StatelessWidget {
  const _DetailsMetaLine({
    required this.releaseDate,
    required this.mediaType,
    required this.runtimeMinutes,
    required this.voteAverage,
    this.certification,
    this.imdbRating,
  });

  final String releaseDate;
  final String mediaType;
  final int runtimeMinutes;
  final double voteAverage;
  final String? certification;
  final double? imdbRating;

  @override
  Widget build(BuildContext context) {
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final bodySize =
        tv ? ShellTokens.tvBodyFontSize : 14.0;
    final metaSize =
        tv ? ShellTokens.tvMetaFontSize : 12.0;
    final items = <Widget>[];

    if (releaseDate.length >= 4) {
      items.add(_metaText(releaseDate.substring(0, 4), bodySize));
    }
    if (mediaType == 'tv') {
      items.add(const _MediaTypeBadge('SERIES'));
    } else if (mediaType == 'movie') {
      items.add(const _MediaTypeBadge('FILM'));
    }
    final runtime = MetaLine.formatRuntime(runtimeMinutes);
    if (runtime.isNotEmpty) items.add(_metaText(runtime, bodySize));
    final cert = certification?.trim();
    if (cert != null && cert.isNotEmpty) items.add(CertBadge(label: cert));
    final rating = (imdbRating != null && imdbRating! > 0)
        ? imdbRating!
        : (voteAverage > 0 ? voteAverage : null);
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
              fontSize: bodySize,
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
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.25),
                fontSize: metaSize,
              ),
            ),
          items[i],
        ],
      ],
    );
  }

  Widget _metaText(String text, double fontSize) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.72),
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _HomeMetaRow extends StatelessWidget {
  const _HomeMetaRow({
    required this.releaseDate,
    required this.mediaType,
    required this.voteAverage,
    required this.genres,
    this.singleLine = false,
  });

  final String releaseDate;
  final String mediaType;
  final double voteAverage;
  final List<String> genres;
  final bool singleLine;

  @override
  Widget build(BuildContext context) {
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final bodySize =
        tv ? ShellTokens.tvBodyFontSize : 13.0;
    final metaSize =
        tv ? ShellTokens.tvMetaFontSize : 12.0;
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
            voteAverage.toStringAsFixed(1),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.amber,
              fontSize: bodySize,
            ),
          ),
        ],
      ),
    );

    if (singleLine) {
      return Row(
        children: [
          rating,
          if (releaseDate.isNotEmpty) ...[
            const SizedBox(width: 10),
            Text(
              releaseDate.split('-').first,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: bodySize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (mediaType == 'tv') ...[
            const SizedBox(width: 10),
            const _MediaTypeBadge('SERIES'),
          ] else if (mediaType == 'movie') ...[
            const SizedBox(width: 10),
            const _MediaTypeBadge('FILM'),
          ],
          if (genres.isNotEmpty) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                genres.take(3).join('  ·  '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: metaSize,
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
          if (releaseDate.isNotEmpty)
            Text(
              releaseDate.split('-').first,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: bodySize,
                fontWeight: FontWeight.w500,
              ),
            ),
          if (mediaType == 'tv')
            const _MediaTypeBadge('SERIES')
          else if (mediaType == 'movie')
            const _MediaTypeBadge('FILM'),
          if (genres.isNotEmpty)
            Text(
              genres.take(3).join('  ·  '),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: metaSize,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}

class CertBadge extends StatelessWidget {
  const CertBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tv = ShellPaintScope.usesTvDensityOf(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal:
            tv ? DetailsTokens.certBadgePadHTv : DetailsTokens.certBadgePadH,
        vertical:
            tv ? DetailsTokens.certBadgePadVTv : DetailsTokens.certBadgePadV,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(
          tv ? DetailsTokens.certBadgeRadiusTv : DetailsTokens.certBadgeRadius,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: tv
              ? DetailsTokens.certBadgeFontSizeTv
              : DetailsTokens.certBadgeFontSize,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: tv ? 0.2 : 0.3,
        ),
      ),
    );
  }
}

class _MediaTypeBadge extends StatelessWidget {
  const _MediaTypeBadge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final tv = ShellPaintScope.usesTvDensityOf(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tv
            ? DetailsTokens.mediaTypeBadgePadHTv
            : DetailsTokens.mediaTypeBadgePadH,
        vertical: tv
            ? DetailsTokens.mediaTypeBadgePadVTv
            : DetailsTokens.mediaTypeBadgePadV,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(
          tv
              ? DetailsTokens.mediaTypeBadgeRadiusTv
              : DetailsTokens.mediaTypeBadgeRadius,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: tv
              ? DetailsTokens.mediaTypeBadgeFontSizeTv
              : DetailsTokens.mediaTypeBadgeFontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white60,
          letterSpacing: tv ? 0.4 : 0.8,
        ),
      ),
    );
  }
}
