import 'package:flutter/material.dart';
import 'package:forja/shared/player/live/lazy_url_health.dart';

/// Hover/focus URL probe for IPTV live catalog channel cards.
class ChannelCatalogHealthHost extends StatefulWidget {
  const ChannelCatalogHealthHost({
    super.key,
    required this.builder,
  });

  final Widget Function(
    BuildContext context, {
    required bool? Function(Map<String, dynamic> item) healthFor,
    required void Function(
      Map<String, dynamic> item, {
      required bool active,
    }) onInteractiveActive,
  }) builder;

  @override
  State<ChannelCatalogHealthHost> createState() =>
      _ChannelCatalogHealthHostState();
}

class _ChannelCatalogHealthHostState extends State<ChannelCatalogHealthHost> {
  final _probe = LazyUrlHealthProbe();

  @override
  void dispose() {
    _probe.dispose();
    super.dispose();
  }

  static String? _probeKey(Map<String, dynamic> item) {
    final open = item['open'];
    if (open is Map) {
      final streamId = (open['streamId'] ?? '').toString().trim();
      final portalKey = (open['portalKey'] ?? '').toString().trim();
      if (streamId.isNotEmpty) {
        return portalKey.isEmpty ? streamId : '$portalKey:$streamId';
      }
      final url = (open['url'] ?? open['id'] ?? '').toString().trim();
      if (url.isNotEmpty) return url;
    }
    final sid = (item['streamId'] ?? '').toString().trim();
    return sid.isEmpty ? null : sid;
  }

  static String? _probeUrl(Map<String, dynamic> item) {
    final open = item['open'];
    if (open is! Map) return null;
    final kind = (open['kind'] ?? '').toString().trim();
    final surface = (open['surface'] ?? '').toString().trim();
    if (kind != 'live' && surface != 'stream') return null;
    final url = (open['url'] ?? open['id'] ?? '').toString().trim();
    return url.isEmpty ? null : url;
  }

  bool? _healthFor(Map<String, dynamic> item) {
    final key = _probeKey(item);
    if (key == null) return null;
    return _probe.healthFor(key);
  }

  void _onActive(Map<String, dynamic> item, {required bool active}) {
    final key = _probeKey(item);
    final url = _probeUrl(item);
    if (key == null || url == null) return;
    if (active) {
      _probe.schedule(key, url);
    } else {
      _probe.cancel(key);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _probe,
      builder: (context, _) => widget.builder(
        context,
        healthFor: _healthFor,
        onInteractiveActive: _onActive,
      ),
    );
  }
}
