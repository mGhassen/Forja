import 'package:flutter/material.dart';
import 'package:forja/shared/engine/runtime/kit/pack_chrome_scope.dart';
import 'package:forja/shared/engine/runtime/kit/pack_opaque_run.dart';
import 'package:forja/shared/engine/runtime/kit/pack_chrome_feed.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';

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
  Future<MetaEnvelope>? _future;
  String _scopeEpoch = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final epoch = _selectionEpoch();
    if (_future == null || epoch != _scopeEpoch) {
      _scopeEpoch = epoch;
      _future = _run();
    }
  }

  @override
  void didUpdateWidget(covariant PackLoadedPaint oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pluginId != widget.pluginId ||
        oldWidget.action != widget.action ||
        oldWidget.packSourceUrl != widget.packSourceUrl ||
        oldWidget.tabId != widget.tabId ||
        !_mapEquals(oldWidget.params, widget.params) ||
        oldWidget.fallbackSpec['statusTab'] !=
            widget.fallbackSpec['statusTab'] ||
        oldWidget.fallbackSpec['kindMenu'] != widget.fallbackSpec['kindMenu'] ||
        oldWidget.fallbackSpec['catalogMenu'] !=
            widget.fallbackSpec['catalogMenu'] ||
        oldWidget.fallbackSpec['sortMenu'] != widget.fallbackSpec['sortMenu'] ||
        oldWidget.fallbackSpec['horizonMenu'] !=
            widget.fallbackSpec['horizonMenu']) {
      _scopeEpoch = _selectionEpoch();
      _future = _run();
    }
  }

  String _selectionEpoch() => packChromeSelectionEpoch(
        context,
        listSpec: widget.fallbackSpec,
        tabId: widget.tabId,
      );

  Future<MetaEnvelope> _run() {
    final params = packChromeFeedParams(
      context,
      baseParams: widget.params,
      listSpec: widget.fallbackSpec,
      tabId: widget.tabId,
      pluginId: widget.pluginId,
    );
    return packOpaqueRun(
      pluginId: widget.pluginId,
      action: widget.action,
      params: params,
      packSourceUrl: widget.packSourceUrl,
    );
  }

  bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final future = _future;
    if (future == null) {
      return const SizedBox.expand(
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return FutureBuilder<MetaEnvelope>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox.expand(
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final env = snap.data;
        if (env == null || !env.ok) {
          final msg = env?.error?.message.trim();
          return SizedBox.expand(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  (msg != null && msg.isNotEmpty)
                      ? msg
                      : 'Could not load this section.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: ForjaShellColors.textSecondary),
                ),
              ),
            ),
          );
        }
        final data = env.data ?? const <String, dynamic>{};
        final merged = Map<String, dynamic>.from(widget.fallbackSpec);
        if (data['items'] is List) merged['items'] = data['items'];
        if (data['widgets'] is List) merged['widgets'] = data['widgets'];
        if (data['paint'] is Map) merged['paint'] = data['paint'];
        if (data['heading'] != null) merged['heading'] = data['heading'];
        if (data['seedPoster'] != null) {
          merged['seedPoster'] = data['seedPoster'];
        }
        if (data.containsKey('canShuffle')) {
          merged['canShuffle'] = data['canShuffle'];
        }
        merged.remove('load');
        _publishDynamicKinds(context, merged);
        return widget.builder(context, merged);
      },
    );
  }

  void _publishDynamicKinds(BuildContext context, Map<String, dynamic> merged) {
    final chrome = PackChromeScope.maybeOf(context);
    if (chrome == null) return;
    final barId = (merged['kindMenu'] ?? '').toString().trim();
    if (barId.isEmpty) return;
    final raw = merged['items'];
    if (raw is! List) return;
    final kinds = <String>{};
    for (final e in raw) {
      if (e is! Map) continue;
      final item = Map<String, dynamic>.from(e);
      final kind = (item['kind'] ??
              (item['meta'] is Map
                  ? (item['meta'] as Map)['kind'] ??
                      (item['meta'] as Map)['type']
                  : null) ??
              '')
          .toString()
          .trim();
      if (kind.isEmpty || kind == 'all') continue;
      kinds.add(kind);
    }
    if (kinds.isEmpty) return;
    final sorted = kinds.toList()..sort();
    final items = <Map<String, dynamic>>[
      {'id': 'all', 'label': 'All', 'icon': 'grid'},
      for (final id in sorted)
        {
          'id': id,
          'label': id.isEmpty
              ? id
              : '${id[0].toUpperCase()}${id.length > 1 ? id.substring(1) : ''}',
        },
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      chrome.onDynamicBarItems(barId, items);
    });
  }
}
