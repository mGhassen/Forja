import 'dart:convert';

import 'package:core/models/torrent_result.dart';
import 'package:rust/rust.dart';

class TorrentApi {
  Future<List<TorrentResult>> searchTorrents(String query) async {
    final rows = ForjaEngine.searchTorrents(query);
    return rows.map(TorrentResult.fromJson).toList();
  }
}
