import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:rust/rust.dart';
import 'package:forja/shared/theme/app_theme.dart';

class LoadingOverlay extends StatefulWidget {
  final Movie movie;
  final String? message;
  final ValueNotifier<String>? messageNotifier;
  final String? subtitle;
  final VoidCallback? onCancel;
  const LoadingOverlay({
    super.key,
    required this.movie,
    this.message,
    this.messageNotifier,
    this.subtitle,
    this.onCancel,
  });

  @override
  State<LoadingOverlay> createState() => _LoadingOverlayState();
}

class _LoadingOverlayState extends State<LoadingOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late String _message;

  @override
  void initState() {
    super.initState();
    _message = widget.messageNotifier?.value ??
        widget.message?.toUpperCase() ??
        'STARTING STREAM';
    widget.messageNotifier?.addListener(_onMessageChanged);
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  void _onMessageChanged() {
    final next = widget.messageNotifier?.value;
    if (next != null && next != _message && mounted) {
      setState(() => _message = next.toUpperCase());
    }
  }

  @override
  void dispose() {
    widget.messageNotifier?.removeListener(_onMessageChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Blurred Backdrop
          CachedNetworkImage(
            imageUrl: TmdbApi.getBackdropUrl(widget.movie.backdropPath),
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(color: Colors.black),
            errorWidget: (context, url, error) => Container(color: Colors.black),
          ),
          Container(
            color: Colors.black.withValues(
              alpha: AppTheme.isLightMode ? 0.8 : 0.72,
            ),
          ),
          
          // Logo/Title (Restored clear logo logic)
          Center(
            child: FadeTransition(
              opacity: _animation,
              child: widget.movie.logoPath.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: TmdbApi.getImageUrl(widget.movie.logoPath),
                      width: MediaQuery.of(context).size.width * 0.6,
                      fit: BoxFit.contain,
                    )
                  : Text(
                      widget.movie.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        fontFamily: 'Poppins',
                      ),
                    ),
            ),
          ),
          
          // Status
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const CircularProgressIndicator(color: AppTheme.primaryColor, strokeWidth: 3),
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
                    child: const Text('CANCEL', style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                      fontFamily: 'Poppins',
                    )),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
