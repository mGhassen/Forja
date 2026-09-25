import 'dart:io';

import 'package:flutter/material.dart';
import 'package:forja_foundation/utils/cover_urls.dart';

/// Network image that crossfades to the next URL after it has decoded.
///
/// Cached / sync frames skip the fade — already-shown hero stills must not
/// animate in from empty when the widget remounts or the URL rotates back.
class SettledNetworkImage extends StatefulWidget {
  const SettledNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.low,
    this.errorWidget,
    this.fadeDuration = const Duration(milliseconds: 900),
  });

  final String imageUrl;
  final BoxFit fit;
  final Alignment alignment;
  final FilterQuality filterQuality;
  final Widget? errorWidget;
  final Duration fadeDuration;

  static const empty = ColoredBox(color: Color(0xFF141414));

  @override
  State<SettledNetworkImage> createState() => _SettledNetworkImageState();
}

class _SettledNetworkImageState extends State<SettledNetworkImage> {
  late String _base;
  String? _incoming;
  bool _incomingVisible = false;

  @override
  void initState() {
    super.initState();
    _base = widget.imageUrl;
  }

  @override
  void didUpdateWidget(covariant SettledNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageUrl == oldWidget.imageUrl) return;
    if (widget.imageUrl.isEmpty) {
      setState(() {
        _base = '';
        _incoming = null;
        _incomingVisible = false;
      });
      return;
    }
    if (_base.isEmpty && _incoming == null) {
      setState(() => _base = widget.imageUrl);
      return;
    }
    if (widget.imageUrl == _base || widget.imageUrl == _incoming) return;
    setState(() {
      if (_incomingVisible && _incoming != null) {
        _base = _incoming!;
      }
      _incoming = widget.imageUrl;
      _incomingVisible = false;
    });
  }

  Widget _frame(String url) {
    if (isLocalCoverUrl(url)) {
      return Image.file(
        File(localCoverFilePath(url)),
        fit: widget.fit,
        alignment: widget.alignment,
        filterQuality: widget.filterQuality,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) =>
            widget.errorWidget ?? SettledNetworkImage.empty,
      );
    }
    final paintUrl = paintableNetworkImageUrl(url);
    return Image.network(
      paintUrl,
      fit: widget.fit,
      alignment: widget.alignment,
      filterQuality: widget.filterQuality,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => widget.errorWidget ?? SettledNetworkImage.empty,
    );
  }

  void _revealIncoming() {
    if (!mounted || _incomingVisible) return;
    setState(() => _incomingVisible = true);
  }

  void _settleIncoming() {
    if (!mounted || _incoming == null) return;
    setState(() {
      _base = _incoming!;
      _incoming = null;
      _incomingVisible = false;
    });
  }

  void _settleIncomingSync() {
    if (!mounted || _incoming == null) return;
    // Already in ImageCache — snap, no fade-from-empty.
    setState(() {
      _base = _incoming!;
      _incoming = null;
      _incomingVisible = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_base.isNotEmpty) _frame(_base),
        if (_incoming != null && isLocalCoverUrl(_incoming!))
          Image.file(
            File(localCoverFilePath(_incoming!)),
            fit: widget.fit,
            alignment: widget.alignment,
            filterQuality: widget.filterQuality,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        if (_incoming != null && !isLocalCoverUrl(_incoming!))
          Image.network(
            paintableNetworkImageUrl(_incoming!),
            fit: widget.fit,
            alignment: widget.alignment,
            filterQuality: widget.filterQuality,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
            frameBuilder: (context, child, frame, sync) {
              if (frame == null && !sync) return const SizedBox.shrink();
              if (sync) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _settleIncomingSync();
                });
                return child;
              }
              if (!_incomingVisible) {
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _revealIncoming());
              }
              return AnimatedOpacity(
                opacity: _incomingVisible ? 1 : 0,
                duration: widget.fadeDuration,
                curve: Curves.easeOutCubic,
                onEnd: _settleIncoming,
                child: child,
              );
            },
          ),
      ],
    );
  }
}
