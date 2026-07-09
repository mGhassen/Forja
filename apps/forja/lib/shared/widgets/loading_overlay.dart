import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:rust/rust.dart';
import 'package:forja/shared/theme/app_theme.dart';
import 'package:forja/shared/widgets/desktop_window_chrome.dart';
import 'package:forja/shared/widgets/stream_provider_probe.dart';
import 'package:forja/shared/player/controls/player_status_roulette.dart';

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
Future<T?> crossfadeLoadingOverlayToPlayer<T>({
  required BuildContext loadingDialogContext,
  ValueNotifier<bool>? fadeOutNotifier,
  Future<void> Function()? beforeFade,
  required Future<T?> Function() openPlayer,
}) async {
  if (beforeFade != null) await beforeFade();
  fadeOutNotifier?.value = true;
  final playerFuture = openPlayer();
  await Future<void>.delayed(loadingOverlayFadeOutDuration);
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
              DesktopWindowChrome.overlayDragStrip(),
              if (_showProviderProbes)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: DesktopWindowChrome.topInset(context),
                        right: 28,
                      ),
                      child: StatusRouletteView(
                        entries: statusEntriesFromProbes(_probes),
                        header: 'CHECKING SOURCES',
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
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
