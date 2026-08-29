import 'package:flutter/material.dart';
import 'package:forja/shared/player/player/utils.dart';
import 'package:rust/rust.dart';

/// Colored scrubber markers for IntroDB segments + next-episode window.
enum SeekBarZoneKind { intro, outro, nextEpisode }

class SeekBarZone {
  const SeekBarZone({
    required this.kind,
    required this.start,
    required this.end,
  });

  final SeekBarZoneKind kind;

  /// Fraction of timeline `[0, 1]`.
  final double start;
  final double end;

  Color get color => switch (kind) {
        // Soft blue — distinct from track / outro / next.
        SeekBarZoneKind.intro => const Color(0xFF6BA3D6),
        // Seafoam for credits / outro.
        SeekBarZoneKind.outro => const Color(0xFF74B49B),
        // Amber for next-episode preview / near-end.
        SeekBarZoneKind.nextEpisode => const Color(0xFFD8A657),
      };
}

/// Build seek markers from IntroDB (+ optional near-end next-episode band).
List<SeekBarZone> buildSeekBarZones({
  IntroDbResponse? introDb,
  required Duration duration,
  bool hasNextEpisode = false,
}) {
  final totalMs = duration.inMilliseconds;
  if (totalMs <= 0) return const [];

  double frac(int ms) => (ms / totalMs).clamp(0.0, 1.0);

  void addSegments(
    List<SeekBarZone> out,
    List<IntroDbTimestamp> segs,
    SeekBarZoneKind kind, {
    required bool openEnded,
  }) {
    for (final seg in segs) {
      final startMs = seg.startMs ?? (openEnded ? null : 0);
      if (startMs == null && openEnded) continue;
      final s = startMs ?? 0;
      final e = seg.endMs ?? (openEnded ? totalMs : null);
      if (e == null || e <= s) continue;
      final start = frac(s);
      final end = frac(e);
      if (end - start < 0.004) continue;
      out.add(SeekBarZone(kind: kind, start: start, end: end));
    }
  }

  final out = <SeekBarZone>[];
  if (introDb != null) {
    addSegments(out, introDb.recap, SeekBarZoneKind.intro, openEnded: false);
    addSegments(out, introDb.intro, SeekBarZoneKind.intro, openEnded: false);
    addSegments(out, introDb.credits, SeekBarZoneKind.outro, openEnded: true);
    addSegments(
      out,
      introDb.preview,
      SeekBarZoneKind.nextEpisode,
      openEnded: true,
    );
  }

  final hasPreview = introDb?.preview.isNotEmpty ?? false;
  if (hasNextEpisode && !hasPreview) {
    final threshold = nearEndOfEpisodeThreshold(duration);
    if (threshold > Duration.zero) {
      final startMs = (totalMs - threshold.inMilliseconds).clamp(0, totalMs);
      final start = frac(startMs);
      if (1.0 - start >= 0.004) {
        out.add(
          SeekBarZone(
            kind: SeekBarZoneKind.nextEpisode,
            start: start,
            end: 1.0,
          ),
        );
      }
    }
  }

  return out;
}

/// Paints zone colors on the track (under buffered / played fill).
class SeekBarZoneLayer extends StatelessWidget {
  const SeekBarZoneLayer({
    super.key,
    required this.zones,
    required this.width,
    required this.height,
  });

  final List<SeekBarZone> zones;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (zones.isEmpty || width <= 0 || height <= 0) {
      return const SizedBox.shrink();
    }
    final radius = BorderRadius.circular(height);
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            for (final z in zones)
              Positioned(
                left: z.start * width,
                width: ((z.end - z.start) * width).clamp(1.0, width),
                top: 0,
                bottom: 0,
                child: ColoredBox(color: z.color.withValues(alpha: 0.85)),
              ),
          ],
        ),
      ),
    );
  }
}
