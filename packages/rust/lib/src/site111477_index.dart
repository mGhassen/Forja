import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'isolate_runner.dart';

Future<List<Site111477Match>> site111477IndexRequest(
  Map<String, dynamic> payload,
) async {
  final raw = await runSite111477IndexRequestJson(jsonEncode(payload));
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  if (decoded['error'] != null) {
    throw Exception(decoded['error']);
  }
  final matches = decoded['matches'] as List<dynamic>? ?? [];
  return matches
      .map(
        (e) => Site111477Match(
          e['file_url'] as String? ?? '',
          e['file_name'] as String? ?? '',
          (e['size_bytes'] as num?)?.toInt() ?? -1,
        ),
      )
      .toList();
}

Future<String> site111477CacheDir() async {
  final base = await getApplicationSupportDirectory();
  final d = Directory(
    '${base.path}${Platform.pathSeparator}site111477_index',
  );
  if (!d.existsSync()) d.createSync(recursive: true);
  return d.path;
}

class Site111477Match {
  final String fileUrl;
  final String fileName;
  final int sizeBytes;
  Site111477Match(this.fileUrl, this.fileName, this.sizeBytes);
}
