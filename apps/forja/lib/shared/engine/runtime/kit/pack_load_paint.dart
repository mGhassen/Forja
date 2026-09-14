import 'package:flutter/material.dart';
import 'package:forja/shared/engine/runtime/kit/pack_opaque_run.dart';
import 'package:forja/shared/engine/runtime/nav/chrome_filters.dart';
import 'package:forja_foundation/protocol/filter.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/widgets/chrome/layout_scope.dart';

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
        oldWidget.fallbackSpec['kindMenu'] != widget.fallbackSpec['kindMenu']) {
      _scopeEpoch = _selectionEpoch();
      _future = _run();
    }
  }

  String _selectionEpoch() {
    final scope = LayoutScope.maybeOf(context);
    final statusTab = (widget.fallbackSpec['statusTab'] ?? '').toString();
    final kindMenu = (widget.fallbackSpec['kindMenu'] ?? '').toString();
    final status = statusTab.isEmpty
        ? ''
        : (scope?.selectedId(statusTab) ??
            widget.fallbackSpec['default']?.toString() ??
            'plantowatch');
    final kind = kindMenu.isEmpty ? '' : (scope?.selectedId(kindMenu) ?? '');
    final chrome = catalogChromeFilterEpoch(widget.tabId);
    return '$status|$kind|$chrome';
  }

  Future<MetaEnvelope> _run() {
    final scope = LayoutScope.maybeOf(context);
    final statusTab = (widget.fallbackSpec['statusTab'] ?? '').toString();
    final kindMenu = (widget.fallbackSpec['kindMenu'] ?? '').toString();
    final params = <String, dynamic>{
      ...widget.params,
      'page': widget.tabId ?? widget.params['page'],
    };
    if (statusTab.isNotEmpty) {
      params['status'] = scope?.selectedId(statusTab) ??
          params['status'] ??
          'plantowatch';
      params['listStatus'] = params['status'];
    }
    if (kindMenu.isNotEmpty) {
      final kind = scope?.selectedId(kindMenu);
      if (kind != null && kind.isNotEmpty) params['kind'] = kind;
    }
    final filters = catalogChromeFilters(
      tabId: widget.tabId,
      pluginId: widget.pluginId,
    );
    return packOpaqueRun(
      pluginId: widget.pluginId,
      action: widget.action,
      params: catalogParamsWithFilters(params, filters: filters),
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
        return widget.builder(context, merged);
      },
    );
  }
}
