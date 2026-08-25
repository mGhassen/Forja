import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Mid-watch socket / DNS death — remount same URL before hop / Retry (issue 205).
bool isLikelyNetworkPlaybackError(String err) {
  if (err.isEmpty) return false;
  final lower = err.toLowerCase();
  if (lower.contains('decoder') ||
      lower.contains('hwdec') ||
      lower.contains('codec') ||
      lower.contains('subtitle') ||
      lower.contains('sub-add')) {
    return false;
  }
  return lower.contains('network') ||
      lower.contains('timeout') ||
      lower.contains('timed out') ||
      lower.contains('connection') ||
      lower.contains('resolve host') ||
      lower.contains('host lookup') ||
      lower.contains('unknown host') ||
      lower.contains('econnreset') ||
      lower.contains('econnrefused') ||
      lower.contains('enotfound') ||
      lower.contains('socket') ||
      lower.contains('unreachable') ||
      lower.contains('no route') ||
      lower.contains('broken pipe') ||
      lower.contains('input/output') ||
      lower.contains('i/o error') ||
      lower.contains('failed to read') ||
      lower.contains('failed to open') ||
      lower.contains('failed to connect') ||
      lower.contains('unable to open') ||
      lower.contains('http error') ||
      lower.contains('ssl') ||
      lower.contains('tls') ||
      lower.contains('eof reached') ||
      // Generic mpv fatals mid-watch are usually demux/network death.
      (lower.contains('failed') && !lower.contains('hardware'));
}

/// True when mid-watch remount should run before Auto hop / Failed Retry.
bool shouldAttemptNetworkRemount(String err) =>
    isLikelyNetworkPlaybackError(err);

Future<bool> deviceLooksOnline({Connectivity? connectivity}) async {
  final c = connectivity ?? Connectivity();
  try {
    final results = await c.checkConnectivity();
    if (results.isEmpty) return true;
    return !results.every((r) => r == ConnectivityResult.none);
  } catch (_) {
    // If the plugin fails, do not block remount forever.
    return true;
  }
}

/// Returns when any interface is up, or [timeout] elapses (then false).
Future<bool> waitUntilOnline({
  Duration timeout = const Duration(seconds: 45),
  Duration pollEvery = const Duration(seconds: 1),
  Connectivity? connectivity,
  bool Function()? isCancelled,
}) async {
  final c = connectivity ?? Connectivity();
  final deadline = DateTime.now().add(timeout);
  while (true) {
    if (isCancelled?.call() == true) return false;
    if (await deviceLooksOnline(connectivity: c)) return true;
    if (DateTime.now().isAfter(deadline)) return false;
    await Future<void>.delayed(pollEvery);
  }
}

/// Wait for connectivity (if needed), remount up to [maxAttempts].
///
/// [remount] must reopen the **same** URL at the last watch position.
Future<bool> attemptNetworkPlaybackRemount({
  required Future<bool> Function() remount,
  bool Function()? isCancelled,
  Connectivity? connectivity,
  int maxAttempts = 3,
  Duration onlineTimeout = const Duration(seconds: 45),
  Duration betweenAttempts = const Duration(seconds: 1),
}) async {
  for (var i = 1; i <= maxAttempts; i++) {
    if (isCancelled?.call() == true) return false;
    final online = await waitUntilOnline(
      timeout: onlineTimeout,
      connectivity: connectivity,
      isCancelled: isCancelled,
    );
    if (!online || isCancelled?.call() == true) {
      debugPrint(
        '[NetworkRemount] offline after wait (attempt $i/$maxAttempts)',
      );
      return false;
    }
    debugPrint('[NetworkRemount] remount attempt $i/$maxAttempts');
    try {
      if (await remount()) return true;
    } catch (e) {
      debugPrint('[NetworkRemount] remount threw: $e');
    }
    if (i < maxAttempts) {
      await Future<void>.delayed(betweenAttempts * i);
    }
  }
  return false;
}
