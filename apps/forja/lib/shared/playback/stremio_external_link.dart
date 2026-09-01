import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/player/controls/player_sources_panel.dart';
import 'package:forja/shell/app_router.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:rust/rust.dart';
import 'package:url_launcher/url_launcher.dart';

/// Handles `externalUrl` on Stremio addon streams (`stremio:///…` or https).
Future<bool> handleStremioStreamIfExternal(
  BuildContext context,
  Map<String, dynamic> stream, {
  bool popToRoot = false,
}) {
  final externalUrl = stream['externalUrl']?.toString();
  if (externalUrl == null || externalUrl.isEmpty) {
    return Future.value(false);
  }
  return handleStremioExternalUrl(
    context,
    url: externalUrl,
    addonBaseUrl: stream['_addonBaseUrl']?.toString(),
    popToRoot: popToRoot,
  );
}

/// Parses and routes Stremio meta links from stream rows or raw URLs.
Future<bool> handleStremioExternalUrl(
  BuildContext context, {
  required String url,
  String? addonBaseUrl,
  bool popToRoot = false,
}) async {
  final parsed = StremioService.parseMetaLink(url);
  if (parsed != null) {
    switch (parsed['action']) {
      case 'detail':
        return _openStremioDetailLink(
          context,
          parsed,
          addonBaseUrl: addonBaseUrl,
        );
      case 'search':
        return _openStremioSearchLink(
          context,
          parsed['query']?.toString() ?? '',
          addonBaseUrl: addonBaseUrl,
          popToRoot: popToRoot,
        );
      case 'discover':
        return _openStremioDiscoverLink(context, popToRoot: popToRoot);
    }
  }

  if (url.startsWith('http://') || url.startsWith('https://')) {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
  }

  if (context.mounted) {
    ForjaToast.error('Unable to handle this link');
  }
  return false;
}

Future<bool> _openStremioDetailLink(
  BuildContext context,
  Map<String, dynamic> parsed, {
  String? addonBaseUrl,
}) async {
  var id = parsed['id']?.toString() ?? '';
  final type = parsed['type']?.toString() ?? 'movie';
  if (!id.startsWith('tt')) {
    final imdbMatch = RegExp(r'(tt\d+)').firstMatch(id);
    if (imdbMatch != null) id = imdbMatch.group(1)!;
  }

  final stremioItem = <String, dynamic>{
    'id': id,
    'type': type,
    'name': '',
    if (addonBaseUrl != null && addonBaseUrl.isNotEmpty)
      '_addonBaseUrl': addonBaseUrl,
  };

  final api = TmdbApi();
  if (id.startsWith('tt')) {
    try {
      final movie = await api.findByImdbId(
        id,
        mediaType: type == 'series' ? 'tv' : 'movie',
      );
      if (movie != null && context.mounted) {
        await AppRouter.openDetails(
          context,
          movie: movie,
          stremioItem: stremioItem,
        );
        return true;
      }
    } catch (_) {}
  }

  if (!context.mounted) return false;
  final actualType = type == 'series' ? 'tv' : 'movie';
  final movie = Movie(
    id: id.hashCode,
    imdbId: id.startsWith('tt') ? id : null,
    title: 'Unknown',
    posterPath: '',
    backdropPath: '',
    voteAverage: 0,
    releaseDate: '',
    overview: '',
    mediaType: actualType,
  );
  await AppRouter.openDetails(
    context,
    movie: movie,
    stremioItem: stremioItem,
  );
  return true;
}

Future<bool> _openStremioSearchLink(
  BuildContext context,
  String query, {
  String? addonBaseUrl,
  bool popToRoot = false,
}) async {
  final trimmed = query.trim();
  if (trimmed.isEmpty || !context.mounted) return false;

  PlayerSourcesPanel.dismiss(cancelEngine: false);
  if (popToRoot) {
    Navigator.of(context, rootNavigator: true)
        .popUntil((route) => route.isFirst);
  }

  WidgetsBinding.instance.addPostFrameCallback((_) {
    ShellBus.openStremioSearch(
      query: trimmed,
      addonBaseUrl: addonBaseUrl ?? '',
    );
  });
  return true;
}

Future<bool> _openStremioDiscoverLink(
  BuildContext context, {
  bool popToRoot = false,
}) async {
  if (!context.mounted) return false;

  PlayerSourcesPanel.dismiss(cancelEngine: false);
  if (popToRoot) {
    Navigator.of(context, rootNavigator: true)
        .popUntil((route) => route.isFirst);
  }

  final host = context;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (host.mounted) unawaited(AppRouter.openSearch(host));
  });
  return true;
}
