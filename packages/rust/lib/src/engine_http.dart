import 'dart:convert';

import 'isolate_runner.dart';

typedef EngineHttpResult = ({
  int status,
  String body,
  Map<String, String> headers,
  String finalUrl,
});

Future<EngineHttpResult> engineHttp(
  String method,
  String url, {
  Map<String, String> headers = const {},
  String? body,
  int timeoutSecs = 15,
  int maxRetries = 0,
}) async {
  assert(maxRetries == 0, 'engineHttp uses stremio fetch (no retries)');
  final hdrJson = jsonEncode(headers);
  final raw = switch (method.toUpperCase()) {
    'POST' => await runHttpPostJson(
      url,
      timeoutSecs: timeoutSecs,
      headersJson: hdrJson,
      body: body ?? '',
    ),
    _ => await runHttpGetJson(
      url,
      timeoutSecs: timeoutSecs,
      headersJson: hdrJson,
    ),
  };
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  if (decoded['error'] != null) {
    throw Exception(decoded['error']);
  }
  return (
    status: decoded['status'] as int,
    body: decoded['body'] as String? ?? '',
    headers: const <String, String>{},
    finalUrl: url,
  );
}
