import 'package:flutter/material.dart';
import 'package:forja/shared/design/src/shell_tokens.dart';

/// Shrinks the entire TV shell to match desktop visual density.
///
/// 1080p leanback panels report ~960×540 logical px (DPR 2). Layout runs in
/// an inflated coordinate space, then [Transform.scale] fits it to the viewport.
class TvUiScaler extends StatelessWidget {
  const TvUiScaler({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scale = ShellTokens.tvUiScale(context);
    if (scale >= 1.0) return child;

    final mq = MediaQuery.of(context);
    final virtualSize = Size(
      mq.size.width / scale,
      mq.size.height / scale,
    );

    return Transform.scale(
      scale: scale,
      alignment: Alignment.topLeft,
      filterQuality: FilterQuality.medium,
      child: SizedBox(
        width: virtualSize.width,
        height: virtualSize.height,
        child: MediaQuery(
          data: mq.copyWith(size: virtualSize),
          child: child,
        ),
      ),
    );
  }
}
