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
    this.onEnterFullscreen,
    this.onExitFullscreen,
    this.shouldOverrideUrlLoading,
    this.onCreateWindow,
    this.onLoadResource,
    this.shouldInterceptRequest,
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
  final void Function(InAppWebViewController controller)? onEnterFullscreen;
  final void Function(InAppWebViewController controller)? onExitFullscreen;
  final Future<NavigationActionPolicy?> Function(
    InAppWebViewController controller,
    NavigationAction navigationAction,
  )? shouldOverrideUrlLoading;
  final Future<bool?> Function(
    InAppWebViewController controller,
    CreateWindowAction createWindowAction,
  )? onCreateWindow;
  final void Function(InAppWebViewController controller, LoadedResource resource)?
      onLoadResource;
  final Future<WebResourceResponse?> Function(
    InAppWebViewController controller,
    WebResourceRequest request,
  )? shouldInterceptRequest;
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
    // Do not forward [key] onto InAppWebView - that would register the same
    // GlobalKey on two widgets (this StatelessWidget + the child).
    return InAppWebView(
      initialData: initialData,
      initialUrlRequest: initialUrlRequest,
      initialUserScripts: initialUserScripts,
      initialSettings: forjaWebViewSettings(
        initialSettings ?? InAppWebViewSettings(),
      ),
      onWebViewCreated: onWebViewCreated,
      onLoadStart: onLoadStart,
      onLoadStop: onLoadStop,
      onEnterFullscreen: onEnterFullscreen,
      onExitFullscreen: onExitFullscreen,
      shouldOverrideUrlLoading: shouldOverrideUrlLoading,
      onCreateWindow: onCreateWindow,
      onLoadResource: onLoadResource,
      shouldInterceptRequest: shouldInterceptRequest,
      onReceivedError: onReceivedError,
      onReceivedHttpError: onReceivedHttpError,
      onConsoleMessage: onConsoleMessage,
    );
  }
}
