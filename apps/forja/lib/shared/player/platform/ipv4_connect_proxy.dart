import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/engine/packs/registry/pack_http.dart';
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

/// Why MediaKit should open through the loopback proxy.
enum PlaybackProxyReason {
  none,
  nat64,
  dns,
}

/// [lookupFailed] when system DNS throws or returns nothing.
/// [dns] covers http and https — libmpv has no resolver hook.
/// [nat64] covers both schemes so ffmpeg does not dial the translated AAAA.
@visibleForTesting
PlaybackProxyReason playbackProxyReason({
  required String scheme,
  required bool lookupFailed,
  required List<InternetAddress> addrs,
}) {
  if (scheme != 'http' && scheme != 'https') return PlaybackProxyReason.none;
  if (lookupFailed || addrs.isEmpty) return PlaybackProxyReason.dns;
  if (hostAddrsNeedIpv4Dial(addrs)) return PlaybackProxyReason.nat64;
  return PlaybackProxyReason.none;
}

/// Test hook for the system-DNS probe inside [playbackHttpProxyFor].
@visibleForTesting
Future<List<InternetAddress>> Function(String host)? debugPlaybackSystemLookup;

@visibleForTesting
void debugResetPlaybackProxy() {
  debugPlaybackSystemLookup = null;
}

/// Point mpv at a local proxy that dials a working address, or clear it.
///
/// libmpv/ffmpeg calls system `getaddrinfo` and keeps one answer. That is
/// either a dead NAT64 AAAA, or no address at all when system DNS is down.
/// The proxy resolves with [PackHttp.resolveHost] (system and DoH) and tunnels
/// HTTPS (`CONNECT`) or forwards plain HTTP.
Future<void> applyIpv4HttpProxy(Player player, String playUrl) async {
  if (player.platform is! NativePlayer) return;
  final native = player.platform as NativePlayer;
  final proxy = await playbackHttpProxyFor(playUrl);
  try {
    await native.setProperty('http-proxy', proxy ?? '');
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[Player] http-proxy set failed: $e');
    }
  }
}

@visibleForTesting
Future<String?> playbackHttpProxyFor(String playUrl) async {
  final uri = Uri.tryParse(playUrl);
  if (uri == null) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  if (uri.host.isEmpty) return null;
  if (uri.host == '127.0.0.1' ||
      uri.host == 'localhost' ||
      uri.host == '::1') {
    return null;
  }

  if (PackHttp.systemDnsUnhealthy) {
    if (kDebugMode) {
      debugPrint('[Player] system DNS unhealthy — DoH proxy for ${uri.host}');
    }
    return Ipv4ConnectProxy.instance.endpoint();
  }

  List<InternetAddress> addrs = const [];
  var failed = false;
  final lookup = debugPlaybackSystemLookup ?? InternetAddress.lookup;
  try {
    addrs = await lookup(uri.host).timeout(PackHttp.systemDnsTimeout);
  } on TimeoutException catch (e) {
    failed = true;
    PackHttp.markSystemDnsUnhealthy(uri.host, e);
  } catch (e) {
    failed = true;
    PackHttp.markSystemDnsUnhealthy(uri.host, e);
  }

  final reason = playbackProxyReason(
    scheme: uri.scheme,
    lookupFailed: failed,
    addrs: addrs,
  );
  if (reason == PlaybackProxyReason.none) return null;
  if (kDebugMode && reason == PlaybackProxyReason.dns) {
    debugPrint('[Player] system DNS failed for ${uri.host} — DoH proxy');
  } else if (kDebugMode && reason == PlaybackProxyReason.nat64) {
    debugPrint('[Player] dual-stack dial for ${uri.host}');
  }
  return Ipv4ConnectProxy.instance.endpoint();
}

/// Loopback HTTP proxy. HTTPS playback sends `CONNECT host:443`.
/// Plain HTTP sends an absolute-form request, which is rewritten and forwarded.
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

@visibleForTesting
class PlaybackProxyRequest {
  PlaybackProxyRequest._({
    required this.host,
    required this.port,
    required this.tunnel,
    required this.upstreamHead,
  });

  final String host;
  final int port;
  final bool tunnel;
  final List<int> upstreamHead;

  factory PlaybackProxyRequest.tunnel(String host, int port) {
    return PlaybackProxyRequest._(
      host: host,
      port: port,
      tunnel: true,
      upstreamHead: const [],
    );
  }

  factory PlaybackProxyRequest.forward(
    String host,
    int port,
    List<int> upstreamHead,
  ) {
    return PlaybackProxyRequest._(
      host: host,
      port: port,
      tunnel: false,
      upstreamHead: upstreamHead,
    );
  }
}

/// First line plus headers, without the trailing blank line.
@visibleForTesting
PlaybackProxyRequest? parsePlaybackProxyHead(String head) {
  final lines = head.split('\r\n');
  if (lines.isEmpty) return null;
  final parts = lines.first.split(' ');
  if (parts.length < 2) return null;
  final method = parts[0].toUpperCase();
  final target = parts[1];
  if (method == 'CONNECT') {
    final hostPort = _splitHostPort(target, 443);
    if (hostPort == null || hostPort.$1.isEmpty) return null;
    return PlaybackProxyRequest.tunnel(hostPort.$1, hostPort.$2);
  }
  final uri = Uri.tryParse(target);
  if (uri == null || uri.scheme != 'http' || uri.host.isEmpty) return null;
  final port = uri.hasPort ? uri.port : 80;
  final path = uri.path.isEmpty ? '/' : uri.path;
  final query = uri.hasQuery ? '?${uri.query}' : '';
  final version = parts.length > 2 ? parts[2] : 'HTTP/1.1';
  final buf = StringBuffer('$method $path$query $version\r\n');
  var sawHost = false;
  for (final line in lines.skip(1)) {
    if (line.isEmpty) continue;
    final lower = line.toLowerCase();
    if (lower.startsWith('proxy-connection:') ||
        lower.startsWith('proxy-authorization:') ||
        lower.startsWith('connection:')) {
      continue;
    }
    if (lower.startsWith('host:')) sawHost = true;
    buf.write('$line\r\n');
  }
  if (!sawHost) {
    final hostHeader = uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
    buf.write('Host: $hostHeader\r\n');
  }
  buf.write('Connection: close\r\n\r\n');
  return PlaybackProxyRequest.forward(
    uri.host,
    port,
    utf8.encode(buf.toString()),
  );
}

(String, int)? _splitHostPort(String target, int defaultPort) {
  if (target.startsWith('[')) {
    final end = target.indexOf(']');
    if (end < 0) return null;
    final host = target.substring(1, end);
    final rest = target.substring(end + 1);
    final port = rest.startsWith(':')
        ? int.tryParse(rest.substring(1)) ?? defaultPort
        : defaultPort;
    return (host, port);
  }
  final i = target.lastIndexOf(':');
  if (i < 0) return (target, defaultPort);
  final port = int.tryParse(target.substring(i + 1));
  if (port == null) return (target, defaultPort);
  return (target.substring(0, i), port);
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
    final head = utf8.decode(bytes.sublist(0, end), allowMalformed: true);
    final parsed = parsePlaybackProxyHead(head);
    final rest = bytes.sublist(end + 4);
    _buf.clear();
    if (rest.isNotEmpty) _pending.add(rest);
    if (parsed == null) {
      client.add(
        'HTTP/1.1 400 Bad Request\r\nConnection: close\r\n\r\n'.codeUnits,
      );
      close();
      return;
    }
    _connecting = true;
    unawaited(_openUpstream(parsed));
  }

  Future<void> _openUpstream(PlaybackProxyRequest request) async {
    try {
      final addrs = await PackHttp.resolveHost(request.host);
      final upstream = await connectFirstAddress(addrs, request.port);
      if (_closed) {
        upstream.destroy();
        return;
      }
      _upstream = upstream;
      if (request.tunnel) {
        client.add('HTTP/1.1 200 Connection Established\r\n\r\n'.codeUnits);
      } else if (request.upstreamHead.isNotEmpty) {
        upstream.add(request.upstreamHead);
      }
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
        client.add(
          'HTTP/1.1 502 Bad Gateway\r\nConnection: close\r\n\r\n'.codeUnits,
        );
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

/// First [addrs] entry that accepts TCP. A refused or timed-out address does
/// not block one that connects.
@visibleForTesting
Future<Socket> connectFirstAddress(
  List<InternetAddress> addrs,
  int port, {
  Duration timeout = const Duration(seconds: 8),
}) {
  if (addrs.isEmpty) {
    return Future.error(const SocketException('no address'));
  }
  final winner = Completer<Socket>();
  var pending = addrs.length;
  Object? lastError;
  for (final addr in addrs) {
    Socket.connect(addr, port, timeout: timeout).then(
      (socket) {
        if (winner.isCompleted) {
          socket.destroy();
          return;
        }
        winner.complete(socket);
      },
      onError: (Object error) {
        lastError = error;
        pending--;
        if (pending == 0 && !winner.isCompleted) {
          winner.completeError(
            lastError ?? const SocketException('connect failed'),
          );
        }
      },
    );
  }
  return winner.future;
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
