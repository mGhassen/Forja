import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

/// DNS64 well-known prefix (RFC 6052). These AAAA records are a translated
/// IPv4 address, not a real IPv6 route.
const kNat64WellKnownPrefix = '64:ff9b:';

/// True when [addrs] include an IPv4 address and every IPv6 address is a
/// NAT64 translation. Connecting to that AAAA hangs; the A record answers.
bool hostAddrsNeedIpv4Dial(List<InternetAddress> addrs) {
  var v4 = false;
  var v6 = false;
  for (final a in addrs) {
    if (a.type == InternetAddressType.IPv4) {
      v4 = true;
    } else if (a.type == InternetAddressType.IPv6) {
      v6 = true;
      if (!_isNat64(a)) return false;
    }
  }
  return v4 && v6;
}

bool _isNat64(InternetAddress a) =>
    a.address.toLowerCase().startsWith(kNat64WellKnownPrefix);

/// Point mpv at a local CONNECT proxy that dials IPv4, or clear it.
///
/// libmpv/ffmpeg takes the first DNS answer. On this network that is a dead
/// NAT64 AAAA, so HTTPS opens sit in buffering until the open wait fails.
Future<void> applyIpv4HttpProxy(Player player, String playUrl) async {
  if (player.platform is! NativePlayer) return;
  final native = player.platform as NativePlayer;
  final proxy = await _proxyForHttps(playUrl);
  try {
    await native.setProperty('http-proxy', proxy ?? '');
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[Player] http-proxy set failed: $e');
    }
  }
}

Future<String?> _proxyForHttps(String playUrl) async {
  final uri = Uri.tryParse(playUrl);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
  if (uri.host == '127.0.0.1' || uri.host == 'localhost') return null;
  List<InternetAddress> addrs;
  try {
    addrs = await InternetAddress.lookup(uri.host);
  } catch (_) {
    return null;
  }
  if (!hostAddrsNeedIpv4Dial(addrs)) return null;
  final endpoint = await Ipv4ConnectProxy.instance.endpoint();
  if (kDebugMode) {
    debugPrint('[Player] IPv4 dial for ${uri.host}');
  }
  return endpoint;
}

/// Loopback HTTP proxy. HTTPS playback sends `CONNECT host:443`.
class Ipv4ConnectProxy {
  Ipv4ConnectProxy._();

  static final Ipv4ConnectProxy instance = Ipv4ConnectProxy._();

  ServerSocket? _server;
  int? _port;
  Future<String>? _starting;

  Future<String> endpoint() {
    final port = _port;
    if (port != null) return Future.value('http://127.0.0.1:$port');
    return _starting ??= _bind();
  }

  Future<String> _bind() async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    _port = server.port;
    server.listen(
      _onClient,
      onError: (Object e) {
        if (kDebugMode) debugPrint('[Player] IPv4 proxy listen: $e');
      },
    );
    return 'http://127.0.0.1:${server.port}';
  }

  void _onClient(Socket client) {
    final session = _ConnectSession(client);
    client.listen(
      session.onData,
      onError: (_) => session.close(),
      onDone: session.onClientDone,
      cancelOnError: true,
    );
  }
}

class _ConnectSession {
  _ConnectSession(this.client);

  final Socket client;
  final BytesBuilder _buf = BytesBuilder(copy: false);
  final BytesBuilder _pending = BytesBuilder(copy: false);
  Socket? _upstream;
  bool _connecting = false;
  bool _tunneled = false;
  bool _closed = false;

  void onData(List<int> chunk) {
    if (_closed) return;
    final upstream = _upstream;
    if (_tunneled && upstream != null) {
      upstream.add(chunk);
      return;
    }
    if (_connecting) {
      _pending.add(chunk);
      return;
    }
    _buf.add(chunk);
    final bytes = _buf.toBytes();
    final end = _headerEnd(bytes);
    if (end < 0) {
      if (bytes.length > 16384) close();
      return;
    }
    final head = String.fromCharCodes(bytes.sublist(0, end));
    final request = head.split('\r\n').first.split(' ');
    if (request.length < 2 || request[0] != 'CONNECT') {
      client.add('HTTP/1.1 405 Method Not Allowed\r\nConnection: close\r\n\r\n'.codeUnits);
      close();
      return;
    }
    final hp = request[1].split(':');
    final host = hp.first;
    final port = hp.length > 1 ? int.tryParse(hp[1]) ?? 443 : 443;
    final rest = bytes.sublist(end + 4);
    _buf.clear();
    if (rest.isNotEmpty) _pending.add(rest);
    _connecting = true;
    unawaited(_openUpstream(host, port));
  }

  Future<void> _openUpstream(String host, int port) async {
    try {
      final addrs = await InternetAddress.lookup(
        host,
        type: InternetAddressType.IPv4,
      );
      if (addrs.isEmpty) {
        throw const SocketException('no ipv4');
      }
      final upstream = await Socket.connect(
        addrs.first,
        port,
        timeout: const Duration(seconds: 8),
      );
      if (_closed) {
        upstream.destroy();
        return;
      }
      _upstream = upstream;
      client.add('HTTP/1.1 200 Connection Established\r\n\r\n'.codeUnits);
      final early = _pending.takeBytes();
      if (early.isNotEmpty) upstream.add(early);
      _tunneled = true;
      upstream.listen(
        client.add,
        onError: (_) => close(),
        onDone: close,
        cancelOnError: true,
      );
    } catch (_) {
      if (!_closed) {
        client.add('HTTP/1.1 502 Bad Gateway\r\nConnection: close\r\n\r\n'.codeUnits);
      }
      close();
    }
  }

  void onClientDone() => close();

  void close() {
    if (_closed) return;
    _closed = true;
    _upstream?.destroy();
    client.destroy();
  }
}

int _headerEnd(List<int> bytes) {
  for (var i = 0; i < bytes.length - 3; i++) {
    if (bytes[i] == 13 &&
        bytes[i + 1] == 10 &&
        bytes[i + 2] == 13 &&
        bytes[i + 3] == 10) {
      return i;
    }
  }
  return -1;
}
