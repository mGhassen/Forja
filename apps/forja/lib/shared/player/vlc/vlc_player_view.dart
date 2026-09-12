import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/player/vlc/vlc_player_bridge.dart';

/// Native libVLC surface — AppKit PlatformView on macOS, Flutter [Texture] on Windows.
class VlcPlayerView extends StatelessWidget {
  const VlcPlayerView({
    super.key,
    required this.viewId,
    this.textureId,
  });

  final int viewId;
  final int? textureId;

  static const _viewType = 'forja-vlc';

  @override
  Widget build(BuildContext context) {
    if (!VlcPlayerBridge.isSupportedPlatform) {
      return const ColoredBox(color: Colors.black);
    }
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      return AppKitView(
        viewType: _viewType,
        creationParams: {'viewId': viewId},
        creationParamsCodec: const StandardMessageCodec(),
      );
    }
    final id = textureId;
    if (id == null || id < 0) {
      return const ColoredBox(color: Colors.black);
    }
    return ColoredBox(
      color: Colors.black,
      child: Texture(textureId: id),
    );
  }
}
