import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:forja/shared/widgets/movie_atmosphere.dart';

/// Ken Burns hero that crossfades through [imageUrls] on a random beat.
class RotatingHeroBackdrop extends StatefulWidget {
  const RotatingHeroBackdrop({
    super.key,
    required this.imageUrls,
    this.showColorTint = false,
    this.minBeat = const Duration(seconds: 12),
    this.maxBeat = const Duration(seconds: 20),
    this.fit = BoxFit.cover,
    this.imageAlignment = Alignment.centerRight,
  });

  /// Absolute image URLs (already resolved to CDN).
  final List<String> imageUrls;
  final bool showColorTint;
  final Duration minBeat;
  final Duration maxBeat;
  final BoxFit fit;
  final Alignment imageAlignment;

  /// Dedupe + drop empties; keep order (primary first).
  static List<String> normalizeUrls(Iterable<String> raw) {
    final out = <String>[];
    final seen = <String>{};
    for (final r in raw) {
      final u = r.trim();
      if (u.isEmpty) continue;
      if (seen.add(u)) out.add(u);
    }
    return out;
  }

  @override
  State<RotatingHeroBackdrop> createState() => _RotatingHeroBackdropState();
}

class _RotatingHeroBackdropState extends State<RotatingHeroBackdrop> {
  final math.Random _rng = math.Random();
  Timer? _timer;
  int _index = 0;
  List<String> _urls = const [];

  @override
  void initState() {
    super.initState();
    _urls = RotatingHeroBackdrop.normalizeUrls(widget.imageUrls);
    _index = _urls.isEmpty ? 0 : _rng.nextInt(_urls.length);
    _scheduleNext();
  }

  @override
  void didUpdateWidget(covariant RotatingHeroBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = RotatingHeroBackdrop.normalizeUrls(widget.imageUrls);
    if (!_listEquals(_urls, next)) {
      final current =
          _urls.isEmpty ? '' : _urls[_index.clamp(0, _urls.length - 1)];
      final oldFirst = _urls.isEmpty ? '' : _urls.first;
      final newFirst = next.isEmpty ? '' : next.first;
      _urls = next;
      if (newFirst.isNotEmpty && newFirst != oldFirst) {
        _index = 0;
      } else {
        final keep = current.isNotEmpty ? _urls.indexOf(current) : -1;
        _index = keep >= 0 ? keep : 0;
      }
      _scheduleNext();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _scheduleNext() {
    _timer?.cancel();
    if (_urls.length < 2) return;
    final minMs = widget.minBeat.inMilliseconds;
    final maxMs = widget.maxBeat.inMilliseconds;
    final span = (maxMs - minMs).clamp(0, 1 << 30) + 1;
    final wait = Duration(milliseconds: minMs + _rng.nextInt(span));
    _timer = Timer(wait, _advance);
  }

  void _advance() {
    if (!mounted || _urls.length < 2) return;
    var next = _rng.nextInt(_urls.length);
    if (next == _index) {
      next = (_index + 1) % _urls.length;
    }
    setState(() => _index = next);
    _scheduleNext();
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (_urls.isEmpty) {
      return const ColoredBox(color: Color(0xFF141414));
    }
    final url = _urls[_index.clamp(0, _urls.length - 1)];
    // Same KenBurns state so SettledNetworkImage can crossfade the still.
    return KenBurnsBackdrop(
      imageUrl: url,
      showColorTint: widget.showColorTint,
      fit: widget.fit,
      imageAlignment: widget.imageAlignment,
    );
  }
}
