import 'package:flutter/material.dart';
import 'package:forja/shared/engine/runtime/kit/pack_opaque_run.dart';
import 'package:forja_foundation/protocol/protocol.dart';

/// Runs an opaque pack [action], merges envelope fields into [fallbackSpec],
/// then builds via [builder] (caller paints — no paint_tree import).
class PackLoadedPaint extends StatefulWidget {
  const PackLoadedPaint({
    super.key,
    required this.pluginId,
    required this.action,
    required this.params,
    required this.fallbackSpec,
    required this.builder,
    this.packSourceUrl,
    this.tabId,
  });

  final String pluginId;
  final String? packSourceUrl;
  final String? tabId;
  final String action;
  final Map<String, dynamic> params;
  final Map<String, dynamic> fallbackSpec;
  final Widget Function(BuildContext context, Map<String, dynamic> merged)
      builder;

  @override
  State<PackLoadedPaint> createState() => _PackLoadedPaintState();
}

class _PackLoadedPaintState extends State<PackLoadedPaint> {
  late final Future<MetaEnvelope> _future = packOpaqueRun(
    pluginId: widget.pluginId,
    action: widget.action,
    params: widget.params,
    packSourceUrl: widget.packSourceUrl,
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MetaEnvelope>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final env = snap.data;
        if (env == null || !env.ok || env.data == null) {
          return const SizedBox.shrink();
        }
        final data = env.data!;
        final merged = Map<String, dynamic>.from(widget.fallbackSpec);
        if (data['items'] is List) merged['items'] = data['items'];
        if (data['widgets'] is List) merged['widgets'] = data['widgets'];
        if (data['paint'] is Map) merged['paint'] = data['paint'];
        if (data['heading'] != null) merged['heading'] = data['heading'];
        if (data['seedPoster'] != null) {
          merged['seedPoster'] = data['seedPoster'];
        }
        merged.remove('load');
        return widget.builder(context, merged);
      },
    );
  }
}
