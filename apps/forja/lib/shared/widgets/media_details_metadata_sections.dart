import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/shared/design/src/forja_shell_colors.dart';
import 'package:rust/rust.dart';

class MediaDetailsMetadataSections extends StatelessWidget {
  const MediaDetailsMetadataSections({
    super.key,
    required this.movie,
    required this.extras,
    this.onRecommendationTap,
  });

  final Movie movie;
  final MediaDetailsExtras extras;
  final void Function(Movie movie)? onRecommendationTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (extras.tagline.isNotEmpty) ...[
          Text(
            extras.tagline,
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: ForjaShellColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (extras.crew.isNotEmpty) ...[
          _sectionTitle('Crew'),
          const SizedBox(height: 8),
          Text(
            extras.crew.map((c) => '${c['name']} (${c['job']})').join(' · '),
            style: TextStyle(color: ForjaShellColors.textSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
        ],
        if (extras.cast.isNotEmpty) ...[
          _sectionTitle('Cast'),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: extras.cast.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final m = extras.cast[i];
                final profile = m['profilePath'] ?? '';
                return SizedBox(
                  width: 72,
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: profile.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: TmdbApi.getProfileUrl(profile),
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 72,
                                height: 72,
                                color: ForjaShellColors.surfaceElevated,
                                child: Icon(Icons.person, color: ForjaShellColors.iconMuted),
                              ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        m['name'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: ForjaShellColors.textPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (extras.keywords.isNotEmpty) ...[
          _sectionTitle('Keywords'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: extras.keywords
                .map((k) => Chip(
                      label: Text(k, style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: ForjaShellColors.surfaceElevated,
                      side: BorderSide(color: ForjaShellColors.borderSubtle),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
        ],
        if (_hasProductionInfo) ...[
          _sectionTitle('Details'),
          const SizedBox(height: 8),
          if (extras.certification.isNotEmpty)
            _detailRow('Rating', extras.certification),
          if (extras.status.isNotEmpty) _detailRow('Status', extras.status),
          if (extras.voteCount > 0)
            _detailRow('Votes', '${extras.voteCount}'),
          if (extras.productionCompanies.isNotEmpty)
            _detailRow('Studio', extras.productionCompanies.join(', ')),
          if (extras.spokenLanguages.isNotEmpty)
            _detailRow('Language', extras.spokenLanguages.join(', ')),
          if (extras.originCountries.isNotEmpty)
            _detailRow('Country', extras.originCountries.join(', ')),
          const SizedBox(height: 16),
        ],
        if (extras.recommendations.isNotEmpty) ...[
          _sectionTitle('More like this'),
          const SizedBox(height: 8),
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: extras.recommendations.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final rec = extras.recommendations[i];
                return GestureDetector(
                  onTap: () {
                    if (onRecommendationTap != null) {
                      onRecommendationTap!(rec);
                    } else {
                      AppRouter.openMovie(context, movie: rec);
                    }
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AspectRatio(
                      aspectRatio: 2 / 3,
                      child: rec.posterPath.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: TmdbApi.getImageUrl(rec.posterPath),
                              fit: BoxFit.cover,
                            )
                          : Container(color: ForjaShellColors.surfaceElevated),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  bool get _hasProductionInfo =>
      extras.certification.isNotEmpty ||
      extras.status.isNotEmpty ||
      extras.voteCount > 0 ||
      extras.productionCompanies.isNotEmpty ||
      extras.spokenLanguages.isNotEmpty ||
      extras.originCountries.isNotEmpty;

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        color: ForjaShellColors.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(color: ForjaShellColors.textSecondary, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: ForjaShellColors.textPrimary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
