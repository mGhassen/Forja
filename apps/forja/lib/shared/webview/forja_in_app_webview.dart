import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:forja/shared/webview/forja_webview_settings.dart';

/// InAppWebView with Android TV software-compositing patch applied automatically.
class ForjaInAppWebView extends StatelessWidget {
  const ForjaInAppWebView({
    super.key,
    this.initialData,
    this.initialUrlRequest,
    this.initialUserScripts,
    this.initialSettings,
    this.onWebViewCreated,
    this.onLoadStart,
    this.onLoadStop,
    this.onProgressChanged,
    this.onEnterFullscreen,
    this.onExitFullscreen,
    this.shouldOverrideUrlLoading,
    this.onLoadResource,
    this.onReceivedError,
    this.onReceivedHttpError,
    this.onConsoleMessage,
  });

  final InAppWebViewInitialData? initialData;
  final URLRequest? initialUrlRequest;
  final UnmodifiableListView<UserScript>? initialUserScripts;
  final InAppWebViewSettings? initialSettings;
  final void Function(InAppWebViewController controller)? onWebViewCreated;
  final void Function(InAppWebViewController controller, WebUri? url)?
      onLoadStart;
  final void Function(InAppWebViewController controller, WebUri? url)?
      onLoadStop;
  final void Function(InAppWebViewController controller, int progress)?
      onProgressChanged;
  final void Function(InAppWebViewController controller)? onEnterFullscreen;
  final void Function(InAppWebViewController controller)? onExitFullscreen;
  final Future<NavigationActionPolicy?> Function(
    InAppWebViewController controller,
    NavigationAction navigationAction,
  )? shouldOverrideUrlLoading;
  final void Function(InAppWebViewController controller, LoadedResource resource)?
      onLoadResource;
  final void Function(
    InAppWebViewController controller,
    WebResourceRequest request,
    WebResourceError error,
  )? onReceivedError;
  final void Function(
    InAppWebViewController controller,
    WebResourceRequest request,
    WebResourceResponse errorResponse,
  )? onReceivedHttpError;
  final void Function(
    InAppWebViewController controller,
    ConsoleMessage consoleMessage,
  )? onConsoleMessage;

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      key: key,
      initialData: initialData,
      initialUrlRequest: initialUrlRequest,
      initialUserScripts: initialUserScripts,
      initialSettings: forjaWebViewSettings(
        initialSettings ?? InAppWebViewSettings(),
      ),
      onWebViewCreated: onWebViewCreated,
      onLoadStart: onLoadStart,
      onLoadStop: onLoadStop,
      onProgressChanged: onProgressChanged,
      onEnterFullscreen: onEnterFullscreen,
      onExitFullscreen: onExitFullscreen,
      shouldOverrideUrlLoading: shouldOverrideUrlLoading,
      onLoadResource: onLoadResource,
      onReceivedError: onReceivedError,
      onReceivedHttpError: onReceivedHttpError,
      onConsoleMessage: onConsoleMessage,
    );
  }
}
