import 'dart:collection';
import 'dart:ui';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:forja/shared/webview/forja_webview_settings.dart';

/// HeadlessInAppWebView with Android TV software-compositing patch applied.
class ForjaHeadlessInAppWebView {
  ForjaHeadlessInAppWebView({
    InAppWebViewInitialData? initialData,
    URLRequest? initialUrlRequest,
    Size initialSize = const Size(-1, -1),
    UnmodifiableListView<UserScript>? initialUserScripts,
    InAppWebViewSettings? initialSettings,
    void Function(InAppWebViewController controller)? onWebViewCreated,
    void Function(InAppWebViewController controller, WebUri? url)? onLoadStop,
    void Function(InAppWebViewController controller, LoadedResource resource)?
    onLoadResource,
    void Function(
      InAppWebViewController controller,
      ConsoleMessage consoleMessage,
    )?
    onConsoleMessage,
    Future<NavigationActionPolicy?> Function(
      InAppWebViewController controller,
      NavigationAction navigationAction,
    )?
    shouldOverrideUrlLoading,
    Future<bool?> Function(
      InAppWebViewController controller,
      CreateWindowAction createWindowAction,
    )?
    onCreateWindow,
    void Function(
      InAppWebViewController controller,
      WebResourceRequest request,
      WebResourceError error,
    )?
    onReceivedError,
    void Function(InAppWebViewController controller, int progress)?
    onProgressChanged,
  }) : _delegate = HeadlessInAppWebView(
         initialData: initialData,
         initialUrlRequest: initialUrlRequest,
         initialSize: initialSize,
         initialUserScripts: initialUserScripts,
         initialSettings: forjaWebViewSettings(
           initialSettings ?? InAppWebViewSettings(),
         ),
         onWebViewCreated: onWebViewCreated,
         onLoadStop: onLoadStop,
         onLoadResource: onLoadResource,
         onConsoleMessage: onConsoleMessage,
         shouldOverrideUrlLoading: shouldOverrideUrlLoading,
         onCreateWindow: onCreateWindow,
         onReceivedError: onReceivedError,
         onProgressChanged: onProgressChanged,
       );

  final HeadlessInAppWebView _delegate;

  InAppWebViewController? get webViewController => _delegate.webViewController;

  Future<void> run() => _delegate.run();

  Future<void> dispose() => _delegate.dispose();
}
