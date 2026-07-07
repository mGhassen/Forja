import 'dart:convert';

import 'package:rust/rust.dart';

typedef AnimeHttpResult = ({
  int status,
  String body,
  Map<String, String> headers,
});

Future<AnimeHttpResult> animeHttp(
  String method,
  String url, {
  Map<String, String> headers = const {},
  String? body,
  int timeoutSecs = 15,
  int maxRetries = 2,
}) async {
  final payload = <String, dynamic>{
    'url': url,
    'method': method,
    'headers_json': jsonEncode(headers),
    'timeout_secs': timeoutSecs,
    'max_retries': maxRetries,
    if (body != null) 'body': body,
  };
  final raw = RustLib.instance.animeRequestJson(jsonEncode(payload));
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  if (decoded['error'] != null) {
    throw Exception(decoded['error']);
  }
  final hdrs = (decoded['headers'] as Map?)?.map(
        (k, v) => MapEntry(k.toString(), v.toString()),
      ) ??
      const <String, String>{};
  return (
    status: decoded['status'] as int,
    body: decoded['body'] as String? ?? '',
    headers: hdrs,
  );
}
