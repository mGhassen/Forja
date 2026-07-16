import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:rust/rust.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/desktop_window_chrome.dart';
import 'package:forja/shared/widgets/stream_provider_probe.dart';

const loadingOverlayFadeOutDuration = Duration(milliseconds: 750);

Future<T?> showLoadingOverlayDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool useRootNavigator = false,
}) {
  return showDialog<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    useSafeArea: false,
    barrierDismissible: false,
    barrierColor: Colors.black,
    builder: builder,
  );
}

/// Removes the loading dialog without popping whatever route was pushed above it.
void dismissLoadingOverlayRoute(BuildContext loadingDialogContext) {
  if (!loadingDialogContext.mounted) return;
  final route = ModalRoute.of(loadingDialogContext);
  if (route != null) {
    Navigator.of(loadingDialogContext).removeRoute(route);
    return;
  }
  if (Navigator.of(loadingDialogContext).canPop()) {
    Navigator.of(loadingDialogContext).pop();
  }
}

/// Fades the loading overlay out while the player route fades in underneath.
///
/// Dismisses the loading route as soon as either the fade finishes **or** the
/// player closes — so Escape before playback never lands on a stuck overlay.
Future<T?> crossfadeLoadingOverlayToPlayer<T>({
  required BuildContext loadingDialogContext,
  ValueNotifier<bool>? fadeOutNotifier,
  Future<void> Function()? beforeFade,
  required Future<T?> Function() openPlayer,
}) async {
  if (beforeFade != null) await beforeFade();
  fadeOutNotifier?.value = true;
  final playerFuture = openPlayer();
  await Future.any<void>([
    Future<void>.delayed(loadingOverlayFadeOutDuration),
    playerFuture.then<void>((_) {}),
  ]);
  dismissLoadingOverlayRoute(loadingDialogContext);
  return playerFuture;
}

class LoadingOverlay extends StatefulWidget {
  final Movie movie;
  final String? message;
  final ValueNotifier<String>? messageNotifier;
  final ValueNotifier<List<StreamProviderProbe>>? providerProbesNotifier;
  final ValueNotifier<bool>? fadeOutNotifier;
  final String? subtitle;
  final String? recheckBanner;
  final bool showReloadButton;
  final VoidCallback? onReload;
  final VoidCallback? onCancel;

  /// Tap a waiting / down / up server in the list to check it manually
  /// (cancels Auto order and resolves that provider).
  final ValueChanged<String>? onManualCheckProvider;

  const LoadingOverlay({
    super.key,
    required this.movie,
    this.message,
    this.messageNotifier,
    this.providerProbesNotifier,
    this.fadeOutNotifier,
    this.subtitle,
    this.recheckBanner,
    this.showReloadButton = false,
    this.onReload,
    this.onCancel,
    this.onManualCheckProvider,
  });

  @override
  State<LoadingOverlay> createState() => _LoadingOverlayState();
}

class _LoadingOverlayState extends State<LoadingOverlay> with TickerProviderStateMixin {
  /// Space reserved at the bottom for progress / cancel so the title logo
  /// centers in the clear area above instead of overlapping it.
  static const double _statusStripReserve = 240;

  late AnimationController _pulseController;
  late AnimationController _fadeOutController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeOutAnimation;
  late String _message;
  List<StreamProviderProbe> _probes = const [];
  bool _providerListOpen = false;

  double get _logoBottomReserve =>
      _providerListOpen ? _statusStripReserve + 200 : _statusStripReserve;

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
    if (!mounted) return;
    if (widget.fadeOutNotifier?.value == true) {
      _fadeOutController.reverse();
    } else {
      // Player closed before hand-off finished — restore the overlay so
      // Cancel / Reload are visible again (not a blank black route).
      _fadeOutController.forward();
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

  int get _probeTotal => _probes.length;

  int get _probeChecked => _probes
      .where(
        (p) =>
            p.status != StreamProviderProbeStatus.trying &&
            p.status != StreamProviderProbeStatus.pending,
      )
      .length;

  int get _probeReady => _probes
      .where((p) => p.status == StreamProviderProbeStatus.success)
      .length;

  int get _probeSkipped => _probes
      .where((p) => p.status == StreamProviderProbeStatus.skippedOnTv)
      .length;

  List<String> get _skippedProbeLabels => _probes
      .where((p) => p.status == StreamProviderProbeStatus.skippedOnTv)
      .map((p) => p.label.toUpperCase())
      .toList(growable: false);

  double get _probeProgress =>
      _probeTotal > 0 ? _probeChecked / _probeTotal : 0;

  StreamProviderProbe? get _tryingProbe {
    for (final probe in _probes) {
      if (probe.status == StreamProviderProbeStatus.trying) return probe;
    }
    return null;
  }

  bool _canManualCheck(StreamProviderProbe probe) {
    if (widget.onManualCheckProvider == null) return false;
    // Allow tapping CHECKING rows so the user can jump to another server
    // (or re-pin the current one) without waiting for the active probe.
    return probe.status != StreamProviderProbeStatus.skippedOnTv;
  }

  String _probeStatusLabel(StreamProviderProbeStatus status) {
    return switch (status) {
      StreamProviderProbeStatus.pending => 'WAITING',
      StreamProviderProbeStatus.trying => 'CHECKING',
      StreamProviderProbeStatus.success => 'UP',
      StreamProviderProbeStatus.failed => 'DOWN',
      StreamProviderProbeStatus.skippedOnTv => 'SKIPPED',
    };
  }

  Color _probeStatusColor(StreamProviderProbeStatus status) {
    return switch (status) {
      StreamProviderProbeStatus.success => const Color(0xFF22C55E),
      StreamProviderProbeStatus.failed => const Color(0xFFEF4444),
      StreamProviderProbeStatus.trying => AppTheme.primaryColor,
      StreamProviderProbeStatus.skippedOnTv =>
        Colors.white.withValues(alpha: 0.35),
      StreamProviderProbeStatus.pending => Colors.white.withValues(alpha: 0.45),
    };
  }

  Widget _probeStatusGlyph(StreamProviderProbeStatus status) {
    final color = _probeStatusColor(status);
    return switch (status) {
      StreamProviderProbeStatus.trying => SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: color,
          ),
        ),
      StreamProviderProbeStatus.failed => Icon(
          Icons.cancel_rounded,
          size: 16,
          color: color,
        ),
      StreamProviderProbeStatus.success => Icon(
          Icons.check_circle_rounded,
          size: 16,
          color: color,
        ),
      StreamProviderProbeStatus.skippedOnTv => Icon(
          Icons.remove_circle_outline_rounded,
          size: 16,
          color: color,
        ),
      StreamProviderProbeStatus.pending => Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
    };
  }

  Widget _providerListPanel() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 220, maxWidth: 360),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 6),
          itemCount: _probes.length,
          separatorBuilder: (_, _) => Divider(
            height: 1,
            color: Colors.white.withValues(alpha: 0.08),
          ),
          itemBuilder: (context, index) {
            final probe = _probes[index];
            final canTap = _canManualCheck(probe);
            final statusColor = _probeStatusColor(probe.status);
            final row = Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: Center(child: _probeStatusGlyph(probe.status)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      probe.label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: canTap
                            ? Colors.white.withValues(alpha: 0.9)
                            : Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                  if (probe.isPreferred) ...[
                    Icon(
                      Icons.star_rounded,
                      size: 14,
                      color: Colors.amber.shade200.withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    _probeStatusLabel(probe.status),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            );
            if (!canTap) return row;
            // Local Material so InkWell hover/splash paints on the row
            // (ancestor Material is behind the opaque list panel fill).
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => widget.onManualCheckProvider!(probe.id),
                  borderRadius: BorderRadius.circular(8),
                  hoverColor: ForjaShellColors.inkHover,
                  splashColor: ForjaShellColors.inkSplash,
                  child: row,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _cancelActionRow() {
    final showListToggle = _showProviderProbes;
    final cancelButton = TextButton(
      onPressed: widget.onCancel,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white.withValues(alpha: 0.7),
        padding: const EdgeInsets.symmetric(
          horizontal: 32,
          vertical: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.3),
          ),
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
    );

    if (!showListToggle) return cancelButton;

    final listButton = IconButton(
      onPressed: () => setState(() => _providerListOpen = !_providerListOpen),
      tooltip: _providerListOpen ? 'Hide servers' : 'Show servers',
      style: IconButton.styleFrom(
        foregroundColor: Colors.white.withValues(
          alpha: _providerListOpen ? 0.95 : 0.7,
        ),
        backgroundColor: _providerListOpen
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.transparent,
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.3),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.all(12),
      ),
      icon: Icon(
        _providerListOpen ? Icons.layers : Icons.layers_outlined,
        size: 20,
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_providerListOpen) ...[
          _providerListPanel(),
          const SizedBox(height: 16),
          if (widget.onManualCheckProvider != null)
            Text(
              'TAP A SERVER TO CHECK MANUALLY',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.6,
                fontFamily: 'Poppins',
              ),
            ),
          if (widget.onManualCheckProvider != null) const SizedBox(height: 12),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            cancelButton,
            const SizedBox(width: 10),
            listButton,
          ],
        ),
      ],
    );
  }

  Widget _probeProgressFooter() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.recheckBanner != null) ...[
          Text(
            widget.recheckBanner!.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.amber.shade200.withValues(alpha: 0.95),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.5,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (widget.showReloadButton) ...[
          Text(
            'SAVED STREAM UNAVAILABLE',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: widget.onReload,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('RELOAD'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          _message,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
            fontFamily: 'Poppins',
          ),
        ),
        if (_tryingProbe != null) ...[
          const SizedBox(height: 8),
          Text(
            _tryingProbe!.label.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
              fontFamily: 'Poppins',
            ),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: 220,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: _probeProgress),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value > 0 ? value : null,
                minHeight: 3,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _probeSkipped > 0
              ? '$_probeChecked / $_probeTotal CHECKED  ·  $_probeReady UP  ·  $_probeSkipped SKIPPED ON TV'
              : '$_probeChecked / $_probeTotal CHECKED  ·  $_probeReady UP',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
            fontFamily: 'Poppins',
          ),
        ),
        if (_probeSkipped > 0) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _skippedProbeLabels.join(' · '),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 10,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.2,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
        if (widget.subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            widget.subtitle!.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.5,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ],
    );
  }

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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Text(
        widget.movie.title,
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final backdropUrl = _resolveBackdropUrl();
    final overlay = FadeTransition(
      opacity: _fadeOutAnimation,
      child: Material(
        color: Colors.black,
        child: SizedBox.expand(
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
                  alpha: 0.72,
                ),
              ),
              // Logo sits in the upper region so it does not collide with the
              // status/cancel strip at the bottom.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: _logoBottomReserve,
                child: Center(
                  child: FadeTransition(
                    opacity: _pulseAnimation,
                    child: _logoImageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: _logoImageUrl!,
                            width: MediaQuery.of(context).size.width * 0.55,
                            height: MediaQuery.of(context).size.height * 0.28,
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                            placeholder: (_, _) => _titleFallback(),
                            errorWidget: (_, _, _) => _titleFallback(),
                          )
                        : _titleFallback(),
                  ),
                ),
              ),
              DesktopWindowChrome.overlayDragStrip(),
              Positioned(
                bottom: 48,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_showProviderProbes)
                        _probeProgressFooter()
                      else ...[
                        if (widget.recheckBanner != null) ...[
                          Text(
                            widget.recheckBanner!.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.amber.shade200.withValues(alpha: 0.95),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.5,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        if (widget.showReloadButton) ...[
                          Text(
                            'SAVED STREAM UNAVAILABLE',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: widget.onReload,
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('RELOAD'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 10,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
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
                      ],
                      if (widget.onCancel != null) ...[
                        SizedBox(height: _showProviderProbes ? 20 : 24),
                        _cancelActionRow(),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (widget.onCancel == null) return overlay;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): widget.onCancel!,
      },
      child: Focus(
        autofocus: true,
        child: overlay,
      ),
    );
  }
}
