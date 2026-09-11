import 'dart:async';
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:forja/shared/shell/desktop_window_focus.dart';

/// Handoff for pack browser auth: Shahid (or any site) runs a bookmarklet that
/// navigates to `forja://connected-auth/session?state=&token=&label=`.
abstract final class PackAuthSessionHandoff {
  PackAuthSessionHandoff._();

  static final AppLinks _links = AppLinks();
  static StreamSubscription<Uri>? _sub;
  static Completer<Map<String, String>>? _pending;
  static String? _expectedState;

  static String newState() {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Bookmarklet body (without `javascript:` prefix) for [state].
  static String bookmarkletSource(String state) {
    // Reads Shahid cookie `token` / persist:modules, then deep-links into Forja.
    return '''
(()=>{try{
  var c=document.cookie.split(';').map(function(s){return s.trim();});
  var t='';
  for(var i=0;i<c.length;i++){if(c[i].indexOf('token=')===0){t=c[i].slice(6);break;}}
  var label='';
  try{
    var p=JSON.parse(localStorage.getItem('persist:modules')||'{}');
    var u=typeof p.user==='string'?JSON.parse(p.user):p.user;
    if(u&&u.sessionId)t=t||String(u.sessionId);
    if(u&&(u.email||u.communicationEmail||u.userName))label=String(u.email||u.communicationEmail||u.userName);
  }catch(e){}
  if(!t||t.length<8){alert('No Shahid session on this tab. Sign in on Shahid first, then run again.');return;}
  location.href='forja://connected-auth/session?state='+encodeURIComponent('$state')+'&token='+encodeURIComponent(t)+(label?'&label='+encodeURIComponent(label):'');
}catch(e){alert('Forja handoff failed: '+e);}})();
'''
        .replaceAll('\n', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Raw IIFE for DevTools console paste (Chrome blocks `javascript:` in the omnibox).
  static String consoleScript(String state) => bookmarkletSource(state);

  static String bookmarkletUri(String state) =>
      'javascript:${bookmarkletSource(state)}';

  /// Wait until a matching `forja://connected-auth/session` arrives.
  static Future<Map<String, String>> waitForSession({
    required String state,
    Duration timeout = const Duration(minutes: 10),
    Future<void>? cancel,
  }) async {
    await _ensureListening();
    _pending?.completeError(StateError('superseded'));
    final completer = Completer<Map<String, String>>();
    _pending = completer;
    _expectedState = state;

    Timer? timer;
    timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.completeError(
          TimeoutException('Shahid session handoff timed out'),
        );
      }
    });

    if (cancel != null) {
      unawaited(
        cancel.then((_) {
          if (!completer.isCompleted) {
            completer.completeError(StateError('cancelled'));
          }
        }),
      );
    }

    try {
      return await completer.future;
    } finally {
      timer.cancel();
      if (identical(_pending, completer)) {
        _pending = null;
        _expectedState = null;
      }
    }
  }

  static Future<void> _ensureListening() async {
    if (kIsWeb) return;
    if (_sub != null) return;
    _sub = _links.uriLinkStream.listen(
      tryHandle,
      onError: (Object e) {
        debugPrint('[PackAuthHandoff] stream error: $e');
      },
    );
  }

  /// Returns true when consumed as an auth handoff.
  static bool tryHandle(Uri uri) {
    if (uri.scheme != 'forja') return false;
    final host = uri.host.trim().toLowerCase();
    final path = uri.path.trim().toLowerCase();
    final joined = '$host$path';
    if (!joined.contains('connected-auth')) return false;

    final state = uri.queryParameters['state']?.trim() ?? '';
    final token =
        (uri.queryParameters['token'] ?? uri.queryParameters['sessionId'] ?? '')
            .trim();
    final label = (uri.queryParameters['label'] ?? '').trim();
    final expected = _expectedState;
    final pending = _pending;
    if (pending == null || expected == null || pending.isCompleted) {
      debugPrint('[PackAuthHandoff] no waiter for $uri');
      return true;
    }
    if (state != expected) {
      debugPrint('[PackAuthHandoff] state mismatch');
      return true;
    }
    if (token.length < 8) {
      debugPrint('[PackAuthHandoff] empty token');
      return true;
    }

    unawaited(DesktopWindowFocus.bringToFront());
    pending.complete({
      'sessionId': token,
      if (label.isNotEmpty) 'label': label,
    });
    return true;
  }
}
