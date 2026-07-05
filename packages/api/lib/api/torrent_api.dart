import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:core/models/torrent_result.dart';
import 'package:streaming/streaming.dart';

class TorrentApi {
  final LocalServerService _localServer = LocalServerService();

  Future<List<TorrentResult>> searchTorrents(String query) async {
    try {
      final baseUrl = _localServer.baseUrl;
      final response = await http.get(Uri.parse('$baseUrl/api/ultimate?query=${Uri.encodeComponent(query)}'));

      if (response.statusCode == 200) {
        // Use compute to parse JSON in a background isolate to avoid UI lag
        return await compute(_parseTorrents, response.body);
      } else {
        throw Exception('Failed to load torrents: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error searching torrents: $e');
    }
  }

  // Top-level function for compute
  static List<TorrentResult> _parseTorrents(String responseBody) {
    final decoded = jsonDecode(responseBody);
    final results = decoded['results'] as List?;
    if (results != null) {
      return results.map((json) => TorrentResult.fromJson(json)).toList();
    }
    return [];
  }
}
