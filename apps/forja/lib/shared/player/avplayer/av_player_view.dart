import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Embeds native AVPlayerLayer (macOS only).
class AvPlayerView extends StatelessWidget {
  const AvPlayerView({super.key, required this.viewId});

  final int viewId;

  static const _viewType = 'forja-avplayer';

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.macOS) {
      return const ColoredBox(color: Colors.black);
    }
    return AppKitView(
      viewType: _viewType,
      creationParams: {'viewId': viewId},
      creationParamsCodec: const StandardMessageCodec(),
    );
  }
}
