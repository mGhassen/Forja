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
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Column(
              children: [
                if (_showProviderProbes) ...[
                  Text(
                    'STARTING STREAM',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 3,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 20),
                  _ProviderProbeList(probes: _probes),
                ] else ...[
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
                  const SizedBox(height: 8),
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

class _ProviderProbeList extends StatelessWidget {
  const _ProviderProbeList({required this.probes});

  final List<StreamProviderProbe> probes;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final probe in probes) _ProviderProbeRow(probe: probe),
          ],
        ),
      ),
    );
  }
}

class _ProviderProbeRow extends StatelessWidget {
  const _ProviderProbeRow({required this.probe});

  final StreamProviderProbe probe;

  @override
  Widget build(BuildContext context) {
    final isTrying = probe.status == StreamProviderProbeStatus.trying;
    final isFailed = probe.status == StreamProviderProbeStatus.failed;
    final nameColor = isTrying
        ? Colors.white
        : Colors.white.withValues(alpha: isFailed ? 0.35 : 0.85);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: _ProbeIcon(status: probe.status),
          ),
          const SizedBox(width: 10),
          if (probe.isPreferred) ...[
            Icon(
              Icons.star_rounded,
              size: 14,
              color: Colors.amber.withValues(alpha: isFailed ? 0.45 : 0.9),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              probe.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: nameColor,
                fontSize: 14,
                fontWeight: isTrying ? FontWeight.w600 : FontWeight.w500,
                fontFamily: 'Poppins',
              ),
            ),
          ),
          if (isTrying) ...[
            const SizedBox(width: 8),
            Text(
              'Trying…',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 12,
                fontWeight: FontWeight.w500,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProbeIcon extends StatelessWidget {
  const _ProbeIcon({required this.status});

  final StreamProviderProbeStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case StreamProviderProbeStatus.trying:
        return CircularProgressIndicator(
          strokeWidth: 1.8,
          color: Colors.white.withValues(alpha: 0.9),
        );
      case StreamProviderProbeStatus.failed:
        return Icon(
          Icons.close_rounded,
          size: 16,
          color: Colors.red.shade400,
        );
      case StreamProviderProbeStatus.success:
        return const Icon(
          Icons.check_rounded,
          size: 16,
          color: Color(0xFF22C55E),
        );
    }
  }
}
