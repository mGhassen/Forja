import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Embeds the native Media3 [PlayerView] (Android only).
///
/// Native side uses [TextureView] (not SurfaceView) so Flutter's AndroidView
/// compositing stays correct - SurfaceView produced tiled/shifted frames on
/// Android TV.
class ExoPlayerView extends StatelessWidget {
  const ExoPlayerView({super.key, required this.viewId});

  final int viewId;

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const ColoredBox(color: Colors.black);
    }
    return AndroidView(
      viewType: 'forja-exoplayer',
      creationParams: {'viewId': viewId},
      creationParamsCodec: const StandardMessageCodec(),
      gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{
        Factory<EagerGestureRecognizer>(EagerGestureRecognizer.new),
      },
    );
  }
}
