import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:forja/shared/player/exo/exo_player_bridge.dart';

/// Embeds the native Media3 [PlayerView] (Android only).
///
/// **Phone / ATV emulator / SurfaceView fallback:** TextureView + [AndroidView]
/// (TLHC) — SurfaceView tiles under TLHC/VirtualDisplay; goldfish MediaCodec
/// often fails `setOutputSurface` on SurfaceView (audio-only + chrome covered).
/// Physical ATV SoCs that fail the same way flip
/// [ExoPlayerBridge.preferTextureSurface] and remount here (issue 133).
///
/// **Physical Android TV (default):** SurfaceView + hybrid composition —
/// TextureView has poor frame timing and often cannot paint at full display
/// resolution on leanback (UI layer is upscaled). Hybrid composition is
/// required so SurfaceView is not mis-composited (issue 102 tiling).
/// SurfaceView also enables Media3's Compose surface-sync workaround so frames
/// are not zoomed/cropped (issue 129).
class ExoPlayerView extends StatelessWidget {
  const ExoPlayerView({super.key, required this.viewId});

  final int viewId;

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
      builder: (context, _, __) {
        final surfaceType = ExoPlayerBridge.creationSurfaceType();
        // Key forces PlatformView dispose+create when surface type flips.
        final child = surfaceType == 'surface'
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
          child: child,
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
