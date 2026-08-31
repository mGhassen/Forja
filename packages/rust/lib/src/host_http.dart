import 'dart:convert';
import 'dart:typed_data';

import 'isolate_runner.dart';

/// Rich HTTP (retries, redirects, binary) — `host-http` Rust crate.
typedef HostHttpResult = ({
  int status,
  String body,
  Map<String, String> headers,
  String finalUrl,
});

Future<HostHttpResult> hostHttp(
  String method,
  String url, {
  Map<String, String> headers = const {},
  String? body,
  Uint8List? bodyBytes,
  int timeoutSecs = 15,
  int maxRetries = 2,
}) async {
  final payload = <String, dynamic>{
    'url': url,
    'method': method,
    'headers_json': jsonEncode(headers),
    'timeout_secs': timeoutSecs,
    'max_retries': maxRetries,
    'body': ?body,
    if (bodyBytes != null) 'body_base64': base64Encode(bodyBytes),
  };
  final raw = await runHostHttpRequestJson(jsonEncode(payload));
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
    finalUrl: decoded['final_url'] as String? ?? url,
  );
}

Future<Uint8List> hostHttpBytes(
  String url, {
  Map<String, String> headers = const {},
  int timeoutSecs = 60,
  int maxRetries = 0,
}) async {
  final payload = <String, dynamic>{
    'url': url,
    'method': 'GET',
    'headers_json': jsonEncode(headers),
    'timeout_secs': timeoutSecs,
    'max_retries': maxRetries,
    'response_binary': true,
  };
  final raw = await runHostHttpRequestJson(jsonEncode(payload));
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  if (decoded['error'] != null) {
    throw Exception(decoded['error']);
  }
  final b64 = decoded['body_base64'] as String? ?? '';
  if (b64.isEmpty) return Uint8List(0);
  return base64Decode(b64);
}
