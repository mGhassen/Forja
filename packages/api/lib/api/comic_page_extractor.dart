import 'dart:async';
import 'dart:collection';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class ComicPageExtractor {
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36';

  HeadlessInAppWebView? _webView;
  bool _isDisposed = false;

  Future<List<String>?> extractPages(String url, {Duration timeout = const Duration(seconds: 30)}) async {
    if (_isDisposed) return null;
    
    final completer = Completer<List<String>?>();
    final capturedUrls = <String>[];
    
    final timeoutTimer = Timer(timeout, () { 
      if (!completer.isCompleted) {
        completer.complete(capturedUrls.isNotEmpty ? List.from(capturedUrls) : null);
      }
    });

    _webView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialSize: const Size(1280, 720),
      initialUserScripts: UnmodifiableListView([
        UserScript(
          source: _getComicExtractorJs(),
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        ),
      ]),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        userAgent: _userAgent,
        useOnLoadResource: true,
      ),
      onLoadResource: (controller, resource) {
        final rUrl = resource.url.toString();
        if (rUrl.contains('ano1.rconet.biz') && 
            (rUrl.contains('.jpg') || rUrl.contains('.png') || rUrl.contains('.webp') || rUrl.contains('=s1600'))) {
          if (!capturedUrls.contains(rUrl)) {
            capturedUrls.add(rUrl);
          }
        }
      },
      onLoadStop: (controller, url) async {
        await controller.evaluateJavascript(source: _getComicExtractorJs());
        await Future.delayed(const Duration(seconds: 3));
        
        if (capturedUrls.isNotEmpty && !completer.isCompleted) {
          completer.complete(List.from(capturedUrls));
          timeoutTimer.cancel();
        }
      },
      onConsoleMessage: (controller, consoleMessage) {
        final msg = consoleMessage.message;
        
        if (msg.contains('COMIC_PAGE:')) {
          final imageUrl = msg.substring(msg.indexOf('COMIC_PAGE:') + 'COMIC_PAGE:'.length).trim();
          if (imageUrl.contains('ano1.rconet.biz') && !capturedUrls.contains(imageUrl)) {
            capturedUrls.add(imageUrl);
          }
        }
      },
    );

    try {
      await _webView!.run();
    } catch (e) {
      debugPrint('[ComicPageExtractor] Error: $e');
      if (!completer.isCompleted) {
        completer.complete(null);
        timeoutTimer.cancel();
      }
    }
    
    return completer.future;
  }

  String _getComicExtractorJs() {
    return """
    (function() {
      if (window.comic_extractor_injected) return;
      window.comic_extractor_injected = true;
      
      console.log('[ComicExtractor] Script injected on ' + window.location.href);
      
      // Function to extract and decode comic pages
      function extractComicPages() {
        console.log('[ComicExtractor] Searching for image arrays...');
        
        // Look for common comic reader array variables
        const possibleArrays = [];
        
        // Check window object for arrays
        for (let key in window) {
          try {
            const val = window[key];
            if (Array.isArray(val) && val.length > 5) {
              // Check if array contains URLs
              const hasUrls = val.some(item => 
                typeof item === 'string' && 
                (item.includes('http') || item.includes('blogspot') || item.includes('rconet'))
              );
              if (hasUrls) {
                console.log('[ComicExtractor] Found array: ' + key + ' with ' + val.length + ' items');
                possibleArrays.push({ name: key, array: val });
              }
            }
          } catch (e) {}
        }
        
        // Select the largest array (likely the image list)
        if (possibleArrays.length > 0) {
          possibleArrays.sort((a, b) => b.array.length - a.array.length);
          const mainArray = possibleArrays[0];
          console.log('[ComicExtractor] Using array: ' + mainArray.name);
          
          mainArray.array.forEach((url, index) => {
            if (typeof url === 'string' && url.includes('http')) {
              console.log('COMIC_PAGE:' + url);
            }
          });
        }
        
        // Also check for images in the DOM
        document.querySelectorAll('img').forEach(img => {
          if (img.src && img.src.includes('ano1.rconet.biz')) {
            console.log('COMIC_PAGE:' + img.src);
          }
        });
      }
      
      // Run extraction after page loads
      if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', extractComicPages);
      } else {
        extractComicPages();
      }
      
      // Also run after a delay to catch dynamically loaded content
      setTimeout(extractComicPages, 2000);
      setTimeout(extractComicPages, 5000);
    })();
    """;
  }

  // Get page count from the select dropdown
  Future<int?> getPageCount(String url) async {
    if (_isDisposed) return null;
    
    final completer = Completer<int?>();
    
    final timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });

    _webView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialSize: const Size(1280, 720),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        userAgent: _userAgent,
      ),
      onLoadStop: (controller, url) async {
        final result = await controller.evaluateJavascript(source: """
          (function() {
            const selectPage = document.getElementById('selectPage');
            if (selectPage) {
              return selectPage.options.length;
            }
            return 0;
          })();
        """);
        
        final pageCount = result is int ? result : (result is String ? int.tryParse(result) : null);
        
        if (!completer.isCompleted) {
          completer.complete(pageCount);
        }
        
        timeoutTimer.cancel();
      },
    );

    try {
      await _webView!.run();
    } catch (e) {
      debugPrint('[ComicPageExtractor] Error: $e');
      if (!completer.isCompleted) {
        completer.complete(null);
      }
      timeoutTimer.cancel();
    }
    
    return completer.future;
  }

  // Extract a single page image URL - reuses webview by navigating
  Future<String?> extractSinglePage(String pageUrl) async {
    if (_isDisposed) return null;
    
    final completer = Completer<String?>();
    final capturedUrls = <String>[];
    
    final timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (!completer.isCompleted) {
        completer.complete(capturedUrls.isNotEmpty ? capturedUrls.first : null);
      }
    });

    // Dispose old webview if exists
    if (_webView != null) {
      await _webView!.dispose();
      _webView = null;
    }

    // Create new webview for this page
    _webView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(pageUrl)),
      initialSize: const Size(1280, 720),
      initialUserScripts: UnmodifiableListView([
        UserScript(
          source: _getSinglePageExtractorJs(),
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        ),
      ]),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        userAgent: _userAgent,
        useOnLoadResource: true,
      ),
      onLoadResource: (controller, resource) {
        final rUrl = resource.url.toString();
        if (rUrl.contains('ano1.rconet.biz') && 
            (rUrl.contains('.jpg') || rUrl.contains('.png') || rUrl.contains('.webp') || rUrl.contains('=s1600'))) {
          if (!capturedUrls.contains(rUrl)) {
            capturedUrls.add(rUrl);
            
            if (!completer.isCompleted) {
              completer.complete(rUrl);
              timeoutTimer.cancel();
            }
          }
        }
      },
      onLoadStop: (controller, url) async {
        await controller.evaluateJavascript(source: _getSinglePageExtractorJs());
        await Future.delayed(const Duration(milliseconds: 1500));
        
        if (capturedUrls.isNotEmpty && !completer.isCompleted) {
          completer.complete(capturedUrls.first);
          timeoutTimer.cancel();
        }
      },
      onConsoleMessage: (controller, consoleMessage) {
        final msg = consoleMessage.message;
        
        if (msg.contains('COMIC_IMAGE:')) {
          final imageUrl = msg.substring(msg.indexOf('COMIC_IMAGE:') + 'COMIC_IMAGE:'.length).trim();
          if (imageUrl.contains('ano1.rconet.biz') && !capturedUrls.contains(imageUrl)) {
            capturedUrls.add(imageUrl);
            
            if (!completer.isCompleted) {
              completer.complete(imageUrl);
              timeoutTimer.cancel();
            }
          }
        }
      },
    );

    try {
      await _webView!.run();
    } catch (e) {
      debugPrint('[ComicPageExtractor] Error: $e');
      if (!completer.isCompleted) {
        completer.complete(null);
        timeoutTimer.cancel();
      }
    }
    
    return completer.future;
  }

  String _getSinglePageExtractorJs() {
    return """
    (function() {
      if (window.single_page_extractor_injected) return;
      window.single_page_extractor_injected = true;
      
      console.log('[SinglePageExtractor] Script injected on ' + window.location.href);
      
      // Function to extract the single page image
      function extractPageImage() {
        console.log('[SinglePageExtractor] Searching for page image...');
        
        // Check for images in the DOM
        const images = document.querySelectorAll('img');
        for (let img of images) {
          if (img.src && img.src.includes('ano1.rconet.biz')) {
            console.log('COMIC_IMAGE:' + img.src);
            return;
          }
        }
        
        // Also check window object for image variables
        for (let key in window) {
          try {
            const val = window[key];
            if (typeof val === 'string' && val.includes('ano1.rconet.biz')) {
              console.log('COMIC_IMAGE:' + val);
              return;
            }
          } catch (e) {}
        }
      }
      
      // Run extraction after page loads
      if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', extractPageImage);
      } else {
        extractPageImage();
      }
      
      // Also run after delays to catch dynamically loaded content
      setTimeout(extractPageImage, 1000);
      setTimeout(extractPageImage, 3000);
    })();
    """;
  }

  // Dispose the webview
  Future<void> dispose() async {
    _isDisposed = true;
    if (_webView != null) {
      debugPrint('[ComicPageExtractor] Disposing webview...');
      await _webView!.dispose();
      _webView = null;
    }
  }
}
