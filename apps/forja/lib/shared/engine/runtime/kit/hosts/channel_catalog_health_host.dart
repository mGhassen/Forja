import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forja/shared/engine/portals/guide/portal_channel_guide_open.dart';
import 'package:forja/shared/engine/portals/models.dart';
import 'package:forja/shared/engine/portals/network/portal_network.dart';
import 'package:forja/shared/engine/portals/store/storage.dart';
import 'package:forja/shared/player/live/lazy_url_health.dart';

/// Hover/focus URL probe for IPTV live catalog channel cards.
///
/// Cards subscribe per stream key — a probe result must not rebuild the grid.
/// Stalker rows ship `pending:stalker:…` until create_link; resolve before probe
/// so status matches play (plain HTTP on the pending token is always red).
class ChannelCatalogHealthHost extends StatefulWidget {
  const ChannelCatalogHealthHost({
    super.key,
    required this.builder,
  });

  final Widget Function(
    BuildContext context, {
    required ValueListenable<bool?>? Function(Map<String, dynamic> item)
        healthListenableFor,
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
  int _activeGen = 0;

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

  static String? _rawProbeUrl(Map<String, dynamic> item) {
    final open = item['open'];
    if (open is! Map) return null;
    final kind = (open['kind'] ?? '').toString().trim();
    final surface = (open['surface'] ?? '').toString().trim();
    if (kind != 'live' && surface != 'stream') return null;
    final url = (open['url'] ?? open['id'] ?? '').toString().trim();
    return url.isEmpty ? null : url;
  }

  static Future<Portal?> _portalForKey(String portalKey) async {
    final key = portalKey.trim();
    if (key.isEmpty) return null;
    final portals = await PortalStore.load();
    final lower = key.toLowerCase();
    for (final v in portals) {
      if (PortalChannelGuideOpen.packPortalKey(v.portal) == lower) {
        return v.portal;
      }
      if (v.key == key || v.credKey == key) return v.portal;
    }
    return null;
  }

  /// Mint a real HTTP URL for Stalker pending handoff; pass through Xtream/M3U.
  static Future<String?> _resolveProbeUrl(Map<String, dynamic> item) async {
    final url = _rawProbeUrl(item);
    if (url == null) return null;
    if (!url.startsWith('pending:')) return url;

    final open = item['open'];
    if (open is! Map) return null;
    final platform = (open['platform'] ?? '').toString().trim().toLowerCase();
    if (platform != 'stalker') return null;

    final cmd = (open['streamId'] ?? '').toString().trim();
    final pk = (open['portalKey'] ?? '').toString().trim();
    if (cmd.isEmpty || pk.isEmpty) return null;

    final portal = await _portalForKey(pk);
    if (portal == null) return null;
    try {
      return await PortalClient.createLink(
        portal,
        cmd: cmd,
        section: 'live',
      );
    } catch (_) {
      return null;
    }
  }

  ValueListenable<bool?>? _healthListenableFor(Map<String, dynamic> item) {
    final key = _probeKey(item);
    if (key == null) return null;
    return _probe.listenableFor(key);
  }

  void _onActive(Map<String, dynamic> item, {required bool active}) {
    final key = _probeKey(item);
    if (key == null) return;
    if (!active) {
      _probe.cancel(key);
      return;
    }

    final gen = ++_activeGen;
    unawaited(() async {
      final resolved = await _resolveProbeUrl(item);
      if (!mounted || gen != _activeGen) return;
      // create_link miss → leave unknown (null), never paint false-red on
      // the pending token.
      if (resolved == null ||
          resolved.isEmpty ||
          resolved.startsWith('pending:') ||
          !(resolved.startsWith('http://') || resolved.startsWith('https://'))) {
        return;
      }
      _probe.schedule(key, resolved, onlyThis: true);
    }());
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      healthListenableFor: _healthListenableFor,
      onInteractiveActive: _onActive,
    );
  }
}
