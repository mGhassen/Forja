import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/design/src/shell_section_title.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:rust/rust.dart';
import 'package:url_launcher/url_launcher.dart';

const _kTrailerCardWidth = 200.0;

class MediaDetailsTrailersSection extends StatelessWidget {
  const MediaDetailsTrailersSection({
    super.key,
    required this.trailers,
  });

  final List<MediaTrailer> trailers;

  @override
  Widget build(BuildContext context) {
    if (trailers.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Trailers', style: ShellSectionTitle.titleStyle),
        const SizedBox(height: 12),
        SizedBox(
          height: 156,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: trailers.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) => _TrailerCard(trailer: trailers[index]),
          ),
        ),
      ],
    );
  }
}

class _TrailerCard extends StatelessWidget {
  const _TrailerCard({required this.trailer});

  final MediaTrailer trailer;

  Future<void> _open(BuildContext context) async {
    final uri = Uri.parse(trailer.youtubeUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open trailer')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final thumbHeight = _kTrailerCardWidth * 9 / 16;

    return FocusableControl(
      onTap: () => _open(context),
      borderRadius: 10,
      child: SizedBox(
        width: _kTrailerCardWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: _kTrailerCardWidth,
                height: thumbHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: trailer.youtubeThumbnail,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => ColoredBox(
                        color: Colors.white.withValues(alpha: 0.06),
                        child: const Icon(Icons.movie_outlined, color: Colors.white24),
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.45),
                          ],
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.black,
                          size: 26,
                        ),
                      ),
                    ),
                    if (trailer.official)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Official',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              trailer.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
