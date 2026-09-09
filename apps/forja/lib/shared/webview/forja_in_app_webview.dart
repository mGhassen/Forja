import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:forja/shared/webview/forja_webview_settings.dart';
import 'package:forja/shared/webview/tv_webview_warm.dart';

/// InAppWebView with Android TV software-compositing patch applied automatically.
class ForjaInAppWebView extends StatefulWidget {
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
    this.shouldInterceptAjaxRequest,
    this.shouldInterceptFetchRequest,
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
  final Future<AjaxRequest?> Function(
    InAppWebViewController controller,
    AjaxRequest ajaxRequest,
  )? shouldInterceptAjaxRequest;
  final Future<FetchRequest?> Function(
    InAppWebViewController controller,
    FetchRequest fetchRequest,
  )? shouldInterceptFetchRequest;
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
  State<ForjaInAppWebView> createState() => _ForjaInAppWebViewState();
}

class _ForjaInAppWebViewState extends State<ForjaInAppWebView> {
  late final Future<void> _warm = TvWebViewWarm.ensure();

  @override
  Widget build(BuildContext context) {
    // Do not forward [key] onto InAppWebView - that would register the same
    // GlobalKey on two widgets (this StatefulWidget + the child).
    return FutureBuilder<void>(
      future: _warm,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox.expand();
        }
        return InAppWebView(
          initialData: widget.initialData,
          initialUrlRequest: widget.initialUrlRequest,
          initialUserScripts: widget.initialUserScripts,
          initialSettings: forjaWebViewSettings(
            widget.initialSettings ?? InAppWebViewSettings(),
          ),
          onWebViewCreated: widget.onWebViewCreated,
          onLoadStart: widget.onLoadStart,
          onLoadStop: widget.onLoadStop,
          onEnterFullscreen: widget.onEnterFullscreen,
          onExitFullscreen: widget.onExitFullscreen,
          shouldOverrideUrlLoading: widget.shouldOverrideUrlLoading,
          onCreateWindow: widget.onCreateWindow,
          onLoadResource: widget.onLoadResource,
          shouldInterceptRequest: widget.shouldInterceptRequest,
          shouldInterceptAjaxRequest: widget.shouldInterceptAjaxRequest,
          shouldInterceptFetchRequest: widget.shouldInterceptFetchRequest,
          onReceivedError: widget.onReceivedError,
          onReceivedHttpError: widget.onReceivedHttpError,
          onConsoleMessage: widget.onConsoleMessage,
        );
      },
    );
  }
}
