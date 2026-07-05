import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../engine.dart';

class HlsQuality {
  final String label;
  final String url;
  final int? bandwidth;
  final int? height;
  final bool isAuto;

  const HlsQuality({
    required this.label,
    required this.url,
    this.bandwidth,
    this.height,
    this.isAuto = false,
  });
}

Future<List<HlsQuality>?> fetchHlsQualities(
  String url, {
  Map<String, String>? headers,
  Duration timeout = const Duration(seconds: 8),
}) async {
  if (!url.contains('.m3u8')) return null;

  try {
    final res = await http
        .get(Uri.parse(url), headers: headers)
        .timeout(timeout);
    if (res.statusCode != 200 || res.body.isEmpty) return null;
    return parseHlsMaster(url, res.body);
  } catch (e) {
    debugPrint('[HLS] Quality fetch failed: $e');
    return null;
  }
}

List<HlsQuality>? parseHlsMaster(String masterUrl, String body) {
  if (!ForjaRust.isInitialized) {
    throw StateError('ForjaEngine not initialized');
  }
  final json = ForjaRust.instance.parseHlsMasterJson(masterUrl, body);
  final list = jsonDecode(json) as List;
  if (list.isEmpty) return null;
  return list.map((e) {
    final m = e as Map<String, dynamic>;
    return HlsQuality(
      label: m['label'] as String,
      url: m['url'] as String,
      bandwidth: m['bandwidth'] as int?,
      height: m['height'] as int?,
      isAuto: m['is_auto'] as bool? ?? false,
    );
  }).toList();
}
