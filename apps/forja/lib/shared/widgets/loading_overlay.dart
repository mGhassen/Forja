import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:rust/rust.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/stream_provider_probe.dart';

class LoadingOverlay extends StatefulWidget {
  final Movie movie;
  final String? message;
  final ValueNotifier<String>? messageNotifier;
  final ValueNotifier<List<StreamProviderProbe>>? providerProbesNotifier;
  final ValueNotifier<bool>? fadeOutNotifier;
  final String? subtitle;
  final VoidCallback? onCancel;
  const LoadingOverlay({
    super.key,
    required this.movie,
    this.message,
    this.messageNotifier,
    this.providerProbesNotifier,
    this.fadeOutNotifier,
    this.subtitle,
    this.onCancel,
  });

  @override
  State<LoadingOverlay> createState() => _LoadingOverlayState();
}

class _LoadingOverlayState extends State<LoadingOverlay> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _fadeOutController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeOutAnimation;
  late String _message;
  List<StreamProviderProbe> _probes = const [];

  @override
  void initState() {
    super.initState();
    _message = widget.messageNotifier?.value ??
        widget.message?.toUpperCase() ??
        'STARTING STREAM';
    widget.messageNotifier?.addListener(_onMessageChanged);
    widget.providerProbesNotifier?.addListener(_onProbesChanged);
    widget.fadeOutNotifier?.addListener(_onFadeOutRequested);
    _probes = widget.providerProbesNotifier?.value ?? const [];
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _fadeOutController = AnimationController(
      duration: const Duration(milliseconds: 750),
      vsync: this,
      value: 1.0,
    );
    _fadeOutAnimation = CurvedAnimation(
      parent: _fadeOutController,
      curve: Curves.easeOut,
    );
  }

  void _onMessageChanged() {
    final next = widget.messageNotifier?.value;
    if (next != null && next != _message && mounted) {
      setState(() => _message = next.toUpperCase());
    }
  }

  void _onProbesChanged() {
    final next = widget.providerProbesNotifier?.value;
    if (next != null && mounted) {
      setState(() => _probes = next);
    }
  }

  void _onFadeOutRequested() {
    if (widget.fadeOutNotifier?.value == true && mounted) {
      _fadeOutController.reverse();
    }
  }

  @override
  void dispose() {
    widget.messageNotifier?.removeListener(_onMessageChanged);
    widget.providerProbesNotifier?.removeListener(_onProbesChanged);
    widget.fadeOutNotifier?.removeListener(_onFadeOutRequested);
    _pulseController.dispose();
    _fadeOutController.dispose();
    super.dispose();
  }

  bool get _showProviderProbes =>
      widget.providerProbesNotifier != null && _probes.isNotEmpty;

  String? get _logoImageUrl {
    final path = widget.movie.logoPath;
    if (path.isEmpty || path.toLowerCase().endsWith('.svg')) return null;
    if (path.startsWith('http')) return path;
    return TmdbApi.getImageUrl(path);
  }

  String _resolveBackdropUrl() {
    final path = widget.movie.backdropPath;
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return TmdbApi.getBackdropUrl(path);
  }

  Widget _titleFallback() {
    return Text(
      widget.movie.title,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 48,
        fontWeight: FontWeight.bold,
        letterSpacing: 2,
        fontFamily: 'Poppins',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final backdropUrl = _resolveBackdropUrl();
    return FadeTransition(
      opacity: _fadeOutAnimation,
      child: Material(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (backdropUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: backdropUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: Colors.black),
                errorWidget: (context, url, error) => Container(color: Colors.black),
              )
            else
              const ColoredBox(color: Colors.black),
            Container(
              color: Colors.black.withValues(
                alpha: AppTheme.isLightMode ? 0.8 : 0.72,
              ),
            ),
            Center(
              child: FadeTransition(
                opacity: _pulseAnimation,
                child: _logoImageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: _logoImageUrl!,
                        width: MediaQuery.of(context).size.width * 0.6,
                        fit: BoxFit.contain,
                        placeholder: (_, _) => _titleFallback(),
                        errorWidget: (_, _, _) => _titleFallback(),
                      )
                    : _titleFallback(),
              ),
            ),
            if (_showProviderProbes)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: SafeArea(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 28),
                      child: _ProviderProbeRoulette(probes: _probes),
                    ),
                  ),
                ),
              ),
            Positioned(
              bottom: 48,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  if (!_showProviderProbes) ...[
                    const CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      _message,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                  if (widget.subtitle != null) ...[
                    if (!_showProviderProbes) const SizedBox(height: 8),
                    Text(
                      widget.subtitle!.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                  if (widget.onCancel != null) ...[
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: widget.onCancel,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white.withValues(alpha: 0.7),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                      ),
                      child: const Text(
                        'CANCEL',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderProbeRoulette extends StatelessWidget {
  const _ProviderProbeRoulette({required this.probes});

  final List<StreamProviderProbe> probes;

  StreamProviderProbe? get _activeProbe {
    for (final probe in probes) {
      if (probe.status == StreamProviderProbeStatus.trying) return probe;
    }
    return probes.isNotEmpty ? probes.last : null;
  }

  StreamProviderProbe? get _previousProbe {
    final active = _activeProbe;
    if (active == null) return null;
    final idx = probes.indexOf(active);
    if (idx <= 0) return null;
    return probes[idx - 1];
  }

  @override
  Widget build(BuildContext context) {
    final active = _activeProbe;
    if (active == null) return const SizedBox.shrink();

    final previous = _previousProbe;
    final triedCount = probes.where((p) => p.status != StreamProviderProbeStatus.trying).length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'CHECKING SOURCES',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.5,
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 72,
          width: 220,
          child: ClipRect(
            child: Stack(
              alignment: Alignment.centerRight,
              clipBehavior: Clip.hardEdge,
              children: [
                if (previous != null &&
                    previous.status != StreamProviderProbeStatus.trying)
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: _RouletteRow(
                        probe: previous,
                        dimmed: true,
                        compact: true,
                      ),
                    ),
                  ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 420),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.centerRight,
                    clipBehavior: Clip.hardEdge,
                    children: [
                      ...previous,
                      if (current != null) current,
                    ],
                  ),
                  transitionBuilder: (child, animation) {
                    final slide = Tween<Offset>(
                      begin: const Offset(0, 0.55),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ));
                    return ClipRect(
                      child: SlideTransition(
                        position: slide,
                        child: FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: _RouletteRow(
                    key: ValueKey('${active.id}-${active.status.name}'),
                    probe: active,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          triedCount > 0 ? '$triedCount checked' : 'Starting…',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.28),
            fontSize: 11,
            fontWeight: FontWeight.w500,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }
}

class _RouletteRow extends StatelessWidget {
  const _RouletteRow({
    super.key,
    required this.probe,
    this.dimmed = false,
    this.compact = false,
  });

  final StreamProviderProbe probe;
  final bool dimmed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isTrying = probe.status == StreamProviderProbeStatus.trying;
    final isFailed = probe.status == StreamProviderProbeStatus.failed;
    final alpha = dimmed ? 0.28 : (isFailed ? 0.45 : 0.92);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!compact) ...[
          SizedBox(
            width: 16,
            height: 16,
            child: _ProbeIcon(status: probe.status, dimmed: dimmed),
          ),
          const SizedBox(width: 10),
        ],
        if (probe.isPreferred && !dimmed) ...[
          Icon(
            Icons.star_rounded,
            size: compact ? 11 : 13,
            color: Colors.amber.withValues(alpha: isFailed ? 0.4 : 0.85),
          ),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            probe.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: Colors.white.withValues(alpha: alpha),
              fontSize: compact ? 12 : 15,
              fontWeight: isTrying && !dimmed ? FontWeight.w600 : FontWeight.w500,
              fontFamily: 'Poppins',
            ),
          ),
        ),
        if (isTrying && !dimmed) ...[
          const SizedBox(width: 10),
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 1.6,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ],
      ],
    );
  }
}

class _ProbeIcon extends StatelessWidget {
  const _ProbeIcon({required this.status, this.dimmed = false});

  final StreamProviderProbeStatus status;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final alpha = dimmed ? 0.35 : 1.0;
    switch (status) {
      case StreamProviderProbeStatus.trying:
        return CircularProgressIndicator(
          strokeWidth: 1.8,
          color: Colors.white.withValues(alpha: 0.9 * alpha),
        );
      case StreamProviderProbeStatus.failed:
        return Icon(
          Icons.close_rounded,
          size: 16,
          color: Colors.red.shade400.withValues(alpha: alpha),
        );
      case StreamProviderProbeStatus.success:
        return Icon(
          Icons.check_rounded,
          size: 16,
          color: Color(0xFF22C55E).withValues(alpha: alpha),
        );
    }
  }
}
