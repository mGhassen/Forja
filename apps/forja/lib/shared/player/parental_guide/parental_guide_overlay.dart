import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/player/controls/player_chrome_overlay.dart';
import 'package:forja/shared/player/parental_guide/parental_guide_service.dart';
import 'package:rust/rust.dart';

const _kBarColor = Color(0xFFE50914);
const _kRowHeight = 18.0;
const _kRowGap = 2.0;

/// Nuvio-identical parental-guide splash: bar grows, rows fade in, hold, reverse out.
class ParentalGuideOverlay extends StatefulWidget {
  const ParentalGuideOverlay({
    super.key,
    required this.warnings,
    required this.isVisible,
    required this.onAnimationComplete,
  });

  final List<ParentalWarning> warnings;
  final bool isVisible;
  final VoidCallback onAnimationComplete;

  @override
  State<ParentalGuideOverlay> createState() => _ParentalGuideOverlayState();
}

class _ParentalGuideOverlayState extends State<ParentalGuideOverlay>
    with TickerProviderStateMixin {
  double _containerAlpha = 0;
  double _lineHeightFraction = 0;
  late List<double> _itemAlphas;
  bool _animating = false;
  int _run = 0;

  @override
  void initState() {
    super.initState();
    _itemAlphas = List<double>.filled(widget.warnings.length, 0);
    if (widget.isVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.isVisible && !_animating) {
          unawaited(_playIn());
        }
      });
    }
  }

  @override
  void didUpdateWidget(ParentalGuideOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.warnings.length != widget.warnings.length) {
      _itemAlphas = List<double>.filled(widget.warnings.length, 0);
    }
    if (widget.isVisible && !_animating) {
      unawaited(_playIn());
    } else if (!widget.isVisible && _animating) {
      _snapOut();
    }
  }

  @override
  void dispose() {
    _run++;
    super.dispose();
  }

  Future<void> _playIn() async {
    if (widget.warnings.isEmpty) return;
    _animating = true;
    final run = ++_run;
    final count = widget.warnings.length;

    await _animate(
      run,
      (v) => _containerAlpha = v,
      0,
      1,
      const Duration(milliseconds: 300),
    );
    await _animate(
      run,
      (v) => _lineHeightFraction = v,
      0,
      1,
      const Duration(milliseconds: 400),
    );

    for (var i = 0; i < count; i++) {
      if (!_alive(run)) return;
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final index = i;
      await _animate(
        run,
        (v) => _itemAlphas[index] = v,
        0,
        1,
        const Duration(milliseconds: 200),
      );
    }

    if (!_alive(run)) return;
    await Future<void>.delayed(const Duration(milliseconds: 5000));

    for (var i = count - 1; i >= 0; i--) {
      if (!_alive(run)) return;
      await Future<void>.delayed(const Duration(milliseconds: 60));
      final index = i;
      await _animate(
        run,
        (v) => _itemAlphas[index] = v,
        1,
        0,
        const Duration(milliseconds: 150),
      );
    }

    if (!_alive(run)) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await _animate(
      run,
      (v) => _lineHeightFraction = v,
      1,
      0,
      const Duration(milliseconds: 300),
    );
    if (!_alive(run)) return;
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await _animate(
      run,
      (v) => _containerAlpha = v,
      1,
      0,
      const Duration(milliseconds: 200),
    );

    if (!_alive(run)) return;
    _animating = false;
    widget.onAnimationComplete();
  }

  void _snapOut() {
    _run++;
    _animating = false;
    _containerAlpha = 0;
    _lineHeightFraction = 0;
    _itemAlphas = List<double>.filled(widget.warnings.length, 0);
    widget.onAnimationComplete();
    if (mounted) setState(() {});
  }

  bool _alive(int run) => mounted && run == _run;

  Future<void> _animate(
    int run,
    void Function(double) apply,
    double begin,
    double end,
    Duration duration,
  ) async {
    if (!_alive(run)) return;
    final controller = AnimationController(vsync: this, duration: duration);
    final anim = Tween<double>(begin: begin, end: end).animate(
      CurvedAnimation(parent: controller, curve: Curves.fastOutSlowIn),
    );
    void tick() {
      if (!_alive(run)) return;
      apply(anim.value);
      setState(() {});
    }

    anim.addListener(tick);
    apply(begin);
    setState(() {});
    try {
      await controller.forward();
    } finally {
      anim.removeListener(tick);
      controller.dispose();
    }
    if (!_alive(run)) return;
    apply(end);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.warnings.isEmpty || _containerAlpha <= 0) {
      return const SizedBox.shrink();
    }
    final count = widget.warnings.length;
    final totalLineHeight =
        (_kRowHeight * count) + (_kRowGap * (count > 1 ? count - 1 : 0));
    final padding = MediaQuery.paddingOf(context);

    return IgnorePointer(
      child: ExcludeFocus(
        child: Padding(
          padding: EdgeInsets.only(
            left: 32 + padding.left,
            top: PlayerTopBar.totalHeight(context) + 8,
          ),
          child: Opacity(
            opacity: _containerAlpha.clamp(0.0, 1.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 3,
                  height: totalLineHeight * _lineHeightFraction,
                  decoration: BoxDecoration(
                    color: _kBarColor,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < count; i++) ...[
                      if (i > 0) const SizedBox(height: _kRowGap),
                      Opacity(
                        opacity: (_itemAlphas.length > i
                                ? _itemAlphas[i]
                                : 0.0)
                            .clamp(0.0, 1.0),
                        child: SizedBox(
                          height: _kRowHeight,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: widget.warnings[i].label,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xD9FFFFFF),
                                      height: 1,
                                    ),
                                  ),
                                  const TextSpan(
                                    text: ' · ',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0x66FFFFFF),
                                      height: 1,
                                    ),
                                  ),
                                  TextSpan(
                                    text: widget.warnings[i].severity,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w400,
                                      color: Color(0x80FFFFFF),
                                      height: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fetches + shows the overlay once when playback starts.
class ParentalGuideLayer extends StatefulWidget {
  const ParentalGuideLayer({
    super.key,
    required this.imdbId,
    required this.playbackStarted,
    this.enabled = true,
  });

  final String? imdbId;
  final bool playbackStarted;
  final bool enabled;

  @override
  State<ParentalGuideLayer> createState() => _ParentalGuideLayerState();
}

class _ParentalGuideLayerState extends State<ParentalGuideLayer> {
  List<ParentalWarning> _warnings = const [];
  bool _visible = false;
  bool _hasShown = false;
  String? _loadedId;

  @override
  void initState() {
    super.initState();
    unawaited(SettingsService().getContentWarnings());
    unawaited(_load());
  }

  @override
  void didUpdateWidget(ParentalGuideLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imdbId != widget.imdbId) {
      _hasShown = false;
      _visible = false;
      _warnings = const [];
      _loadedId = null;
      unawaited(_load());
    } else {
      _tryShow();
    }
  }

  Future<void> _load() async {
    final id = extractParentalGuideImdbId(widget.imdbId);
    if (id == null) return;
    final guide = await ParentalGuideService.instance.getParentalGuide(id);
    if (!mounted || id != extractParentalGuideImdbId(widget.imdbId)) return;
    final warnings = guide == null ? const <ParentalWarning>[] : buildParentalWarnings(guide);
    setState(() {
      _loadedId = id;
      _warnings = warnings;
    });
    _tryShow();
  }

  void _tryShow() {
    if (!widget.enabled ||
        !SettingsService.contentWarningsNotifier.value ||
        !widget.playbackStarted ||
        _hasShown ||
        _visible ||
        _warnings.isEmpty ||
        _loadedId == null) {
      return;
    }
    setState(() {
      _hasShown = true;
      _visible = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SettingsService.contentWarningsNotifier,
      builder: (context, enabled, _) {
        if (!widget.enabled || !enabled || _warnings.isEmpty) {
          return const SizedBox.shrink();
        }
        return Align(
          alignment: Alignment.topLeft,
          child: ParentalGuideOverlay(
            warnings: _warnings,
            isVisible: _visible,
            onAnimationComplete: () {
              if (mounted) setState(() => _visible = false);
            },
          ),
        );
      },
    );
  }
}
