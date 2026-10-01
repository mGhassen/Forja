import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:forja/shared/downloads/download_page_store.dart';
import 'package:forja/shared/downloads/download_service.dart';
import 'package:forja/shared/engine/details/pack_details_host.dart';
import 'package:forja/shared/engine/runtime/open/meta_surface_open.dart';
import 'package:forja_foundation/protocol/protocol.dart';

/// `open.surface: offline` — title details from the saved page, no pack fetch.
abstract final class OfflineLibraryOpen {
  OfflineLibraryOpen._();

  static const surface = 'offline';

  static bool _registered = false;

  static void ensureRegistered() {
    if (_registered) return;
    _registered = true;
    MetaSurfaceOpen.register(surface, openFromMeta);
  }

  static void openFromMeta(BuildContext context, MetaItem item) {
    final id = (item.open?.id ?? item.id).trim();
    if (id.isEmpty) return;
    unawaited(_open(context, item, id));
  }

  static Future<void> _open(
    BuildContext context,
    MetaItem seed,
    String mediaId,
  ) async {
    final saved = await DownloadPageStore.readMeta(mediaId);
    final base = saved ?? seed;
    final forced = base.copyWith(
      open: MetaOpen(
        surface: surface,
        id: mediaId,
        extras: const {'preferredSourcesKind': 'downloaded'},
      ),
    );
    final page = filterMetaToDownloadedEpisodes(
      forced,
      DownloadService.instance.tasksNotifier.value,
      mediaId,
    );
    if (!context.mounted) return;
    await openKitDetails(
      context,
      pluginId: '',
      item: page,
    );
  }
}
