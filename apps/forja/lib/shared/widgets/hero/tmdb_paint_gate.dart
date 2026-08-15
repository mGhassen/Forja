import 'dart:async';

import 'package:flutter/material.dart';

/// How much TMDB overlay is painted over KissKH / AniList / IPTV source UI.
enum TmdbPaintLevel {
  /// Source poster, title, synopsis only.
  none,

  /// Cinematic backdrop (crossfade over the source still).
  art,

  /// Logo, genres, rating, extra facts.
  chrome,

  /// Cast / trailers / recs + episode stills.
  rows,
}

extension TmdbPaintLevelX on TmdbPaintLevel {
  bool get hasArt => index >= TmdbPaintLevel.art.index;
  bool get hasChrome => index >= TmdbPaintLevel.chrome.index;
  bool get hasRows => index >= TmdbPaintLevel.rows.index;
}

/// Reveals TMDB layers one at a time so details don't rebuild as one flash.
class TmdbPaintGate extends StatefulWidget {
  const TmdbPaintGate({
    super.key,
    required this.ready,
    required this.builder,
  });

  final bool ready;
  final Widget Function(BuildContext context, TmdbPaintLevel level) builder;

  @override
  State<TmdbPaintGate> createState() => _TmdbPaintGateState();
}

class _TmdbPaintGateState extends State<TmdbPaintGate> {
  TmdbPaintLevel _level = TmdbPaintLevel.none;
  Timer? _art;
  Timer? _chrome;
  Timer? _rows;

  @override
  void initState() {
    super.initState();
    if (widget.ready) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _arm());
    }
  }

  @override
  void didUpdateWidget(covariant TmdbPaintGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ready && !oldWidget.ready) {
      _arm();
    } else if (!widget.ready && oldWidget.ready) {
      _cancel();
      _level = TmdbPaintLevel.none;
    }
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }

  void _cancel() {
    _art?.cancel();
    _chrome?.cancel();
    _rows?.cancel();
    _art = null;
    _chrome = null;
    _rows = null;
  }

  void _arm() {
    if (!mounted || !widget.ready) return;
    _cancel();
    // Let the source page actually paint before any TMDB layer.
    _art = Timer(const Duration(milliseconds: 700), () {
      if (!mounted || !widget.ready) return;
      setState(() => _level = TmdbPaintLevel.art);
    });
    _chrome = Timer(const Duration(milliseconds: 1600), () {
      if (!mounted || !widget.ready) return;
      setState(() => _level = TmdbPaintLevel.chrome);
    });
    _rows = Timer(const Duration(milliseconds: 2600), () {
      if (!mounted || !widget.ready) return;
      setState(() => _level = TmdbPaintLevel.rows);
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _level);
}
