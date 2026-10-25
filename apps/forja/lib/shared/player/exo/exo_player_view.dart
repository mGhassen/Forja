import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Embeds native Media3 video via a Flutter [Texture] (Android only).
///
/// Frames come from a [TextureRegistry.SurfaceProducer] bound in Kotlin
/// (`ExoPlayer.setVideoSurface`) — same paint class as MediaKit
/// `mediacodec_embed` / official `video_player` (issue 479). Avoids the
/// PlatformView TextureView copy that mottled on Xiaomi ATV.
///
/// Resize modes are applied in Dart ([FittedBox]); native PlayerView is not
/// used for the video plane.
class ExoPlayerView extends StatelessWidget {
  const ExoPlayerView({
    super.key,
    required this.viewId,
    this.textureId,
    this.resizeMode = 'fit',
    this.videoWidth = 0,
    this.videoHeight = 0,
    // Kept so IPTV/Live Sports call sites compile; SurfaceView path is gone.
    this.allowSurfaceView = false,
  });

  final int viewId;

  /// Native SurfaceProducer id from [ExoPlayerBridge.create].
  final int? textureId;

  /// `fit` | `fill` | `zoom` — matches Player menu resize.
  final String resizeMode;

  /// Last Media3 VideoSize (0 until first size event).
  final int videoWidth;
  final int videoHeight;

  /// Unused — SurfaceProducer replaces SurfaceView (issue 133 / 479).
  final bool allowSurfaceView;

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const ColoredBox(color: Colors.black);
    }
    final id = textureId;
    if (id == null || id < 0) {
      return const ColoredBox(color: Colors.black);
    }

    final fit = switch (resizeMode) {
      'fill' => BoxFit.fill,
      'zoom' => BoxFit.cover,
      _ => BoxFit.contain,
    };

    final hasSize = videoWidth > 0 && videoHeight > 0;
    final child = hasSize
        ? FittedBox(
            fit: fit,
            child: SizedBox(
              width: videoWidth.toDouble(),
              height: videoHeight.toDouble(),
              child: Texture(textureId: id),
            ),
          )
        : Texture(textureId: id);

    return ColoredBox(
      color: Colors.black,
      child: SizedBox.expand(child: child),
    );
  }
}
