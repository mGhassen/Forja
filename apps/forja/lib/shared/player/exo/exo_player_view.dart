import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/player/exo/exo_player_bridge.dart';

/// Embeds the native Media3 [PlayerView] (Android only).
///
/// **Home / VOD (default):** always TextureView + [AndroidView] (TLHC).
/// Physical ATV SurfaceView + hybrid composition went audio-only / black on
/// real devices; the first-frame watchdog cannot detect composition-dead
/// surfaces that still emit `renderedFirstFrame` (issue 133).
///
/// **IPTV live (`allowSurfaceView: true`):** physical ATV may use SurfaceView
/// + hybrid composition for frame timing (issue 108). Emulators and the
/// process-lifetime [ExoPlayerBridge.preferTextureSurface] flag force TextureView.
class ExoPlayerView extends StatelessWidget {
  const ExoPlayerView({
    super.key,
    required this.viewId,
    this.allowSurfaceView = false,
  });

  final int viewId;

  /// When true on physical ATV, prefer SurfaceView unless TextureView fallback
  /// already flipped. Home/VOD must leave this false.
  final bool allowSurfaceView;

  static const _viewType = 'forja-exoplayer';

  static const _gestures = <Factory<OneSequenceGestureRecognizer>>{
    Factory<EagerGestureRecognizer>(EagerGestureRecognizer.new),
  };

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const ColoredBox(color: Colors.black);
    }
    return ValueListenableBuilder<bool>(
      valueListenable: ExoPlayerBridge.preferTextureSurface,
      builder: (context, _, child) {
        final surfaceType = ExoPlayerBridge.creationSurfaceType(
          allowSurfaceView: allowSurfaceView,
        );
        // Key forces PlatformView dispose+create when surface type flips.
        final view = surfaceType == 'surface'
            ? _AtvExoSurfaceView(viewId: viewId)
            : AndroidView(
                viewType: _viewType,
                creationParams: {
                  'viewId': viewId,
                  'surfaceType': 'texture',
                },
                creationParamsCodec: const StandardMessageCodec(),
                gestureRecognizers: _gestures,
              );
        return KeyedSubtree(
          key: ValueKey<String>('exo-$viewId-$surfaceType'),
          child: view,
        );
      },
    );
  }
}

/// Hybrid-composition PlatformView so native SurfaceView composites correctly.
class _AtvExoSurfaceView extends StatelessWidget {
  const _AtvExoSurfaceView({required this.viewId});

  final int viewId;

  @override
  Widget build(BuildContext context) {
    return PlatformViewLink(
      viewType: ExoPlayerView._viewType,
      surfaceFactory: (context, controller) {
        return AndroidViewSurface(
          controller: controller as AndroidViewController,
          gestureRecognizers: ExoPlayerView._gestures,
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        );
      },
      onCreatePlatformView: (params) {
        return PlatformViewsService.initExpensiveAndroidView(
          id: params.id,
          viewType: ExoPlayerView._viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: {'viewId': viewId, 'surfaceType': 'surface'},
          creationParamsCodec: const StandardMessageCodec(),
        )
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..create();
      },
    );
  }
}
