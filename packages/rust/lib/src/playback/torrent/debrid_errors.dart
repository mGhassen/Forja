class DebridAuthException implements Exception {
  final String service;
  final Object cause;

  DebridAuthException(this.service, this.cause);

  @override
  String toString() => debridUserMessage(cause, service);
}

bool isDebridAuthFailure(Object error) {
  final msg = error.toString().toLowerCase();
  return msg.contains('bad_token') ||
      msg.contains('"error_code": 8') ||
      msg.contains('real-debrid not logged in') ||
      msg.contains('api key not set') ||
      msg.contains('invalid api key') ||
      msg.contains('invalid_api_key') ||
      msg.contains('unauthorized') ||
      msg.contains('access denied') ||
      msg.contains('authentication failed') ||
      msg.contains('not logged in');
}

String debridUserMessage(Object error, String service) {
  if (isDebridAuthFailure(error)) {
    return '$service login failed. Check your API key in Settings → Debrid, '
        'or turn off magnet resolve to use the local torrent engine.';
  }
  final raw = error.toString();
  return raw.startsWith('Exception: ') ? raw.substring(11) : raw;
}
