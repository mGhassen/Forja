import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shell/routing/app_router.dart';
import 'package:forja/shell/routing/shell_overlay_navigator.dart';
import 'package:forja/shared/engine/runtime/meta_surface_open.dart';
import 'package:forja_foundation/protocol/protocol.dart';
import 'package:rust/rust.dart' show Movie;

/// Generic `ctx.host.playback.open` + `open.surface: stream` (RFC-109 Wave C).
///
/// Packs pass opaque stream URLs; host opens the native player. No IPTV types.
abstract final class HostPlaybackOpen {
  HostPlaybackOpen._();

  static const surface = 'stream';

  static bool _registered = false;

  static void ensureRegistered() {
    if (_registered) return;
    _registered = true;
    MetaSurfaceOpen.register(surface, openFromMeta);
  }

  static void openFromMeta(BuildContext context, MetaItem item) {
    final open = item.open;
    final url = (open?.extraString('url') ??
            open?.extraString('streamUrl') ??
            open?.id ??
            '')
        .trim();
    if (url.isEmpty) return;
    final headers = _headersFromOpen(open);
    final title = item.name.trim().isEmpty ? 'Stream' : item.name.trim();
    unawaited(
      openUrl(
        context: context,
        url: url,
        title: title,
        headers: headers,
      ),
    );
  }

  /// Bridge entry — [context] optional when overlay navigator is mounted.
  static Future<bool> openUrl({
    BuildContext? context,
    required String url,
    String title = 'Stream',
    Map<String, String>? headers,
  }) async {
    final u = url.trim();
    if (u.isEmpty) return false;
    final ctx = context ?? shellOverlayNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return false;
    final t = title.trim().isEmpty ? 'Stream' : title.trim();
    try {
      await AppRouter.openPlayer(
        ctx,
        streamUrl: u,
        title: t,
        headers: headers,
        movie: Movie(
          id: u.hashCode.abs(),
          title: t,
          overview: '',
          posterPath: '',
          backdropPath: '',
          voteAverage: 0,
          releaseDate: '',
          mediaType: 'tv',
        ),
        streamsPrevalidated: true,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static Map<String, String>? _headersFromOpen(MetaOpen? open) {
    if (open == null) return null;
    final raw = open.extras['headers'] ?? open.extras['requestHeaders'];
    if (raw is! Map) return null;
    final out = <String, String>{};
    for (final e in raw.entries) {
      final k = e.key.toString().trim();
      final v = e.value?.toString() ?? '';
      if (k.isEmpty || v.isEmpty) continue;
      out[k] = v;
    }
    return out.isEmpty ? null : out;
  }
}
