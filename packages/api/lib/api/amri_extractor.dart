import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class AmriExtractor {
  final void Function(String) onLog;
  HeadlessInAppWebView? _headlessWebView;
  Completer<Map<String, dynamic>>? _sourcesCompleter;

  AmriExtractor({required this.onLog});

  void _handleSourcesData(dynamic sourcesData) {
    if (_sourcesCompleter != null && !_sourcesCompleter!.isCompleted) {
      try {
        final data = sourcesData is String ? jsonDecode(sourcesData) : sourcesData;
        onLog('✓ Sources data captured, completing future...');
        _sourcesCompleter!.complete(data);
        onLog('✓ Future completed successfully');
        
        // IMMEDIATELY dispose the webview to stop script execution
        _cleanup().then((_) {
          onLog('✓ WebView disposed');
        });
      } catch (e) {
        onLog('✗ Error completing future: $e');
        _sourcesCompleter!.completeError(e);
      }
    } else {
      onLog('⚠️ Completer is null or already completed');
    }
  }

  Future<Map<String, dynamic>> extractSources(
    String tmdbId,
    String title,
    String year, {
    int? season,
    int? episode,
  }) async {
    _sourcesCompleter = Completer<Map<String, dynamic>>();
    
    try {
      onLog('Starting extraction for TMDB ID: $tmdbId');
      
      // Build direct URL
      final String url;
      if (season != null && episode != null) {
        url = 'https://amri.gg/#/tv/$tmdbId/$season/$episode';
        onLog('Loading TV show URL: $url');
      } else {
        url = 'https://amri.gg/#/movie/$tmdbId';
        onLog('Loading movie URL: $url');
      }
      
      final script = _buildInterceptScript(tmdbId);
      
      _headlessWebView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(url)),
        initialUserScripts: UnmodifiableListView([
          UserScript(
            source: script,
            injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          ),
        ]),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          domStorageEnabled: true,
          userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        ),
        onLoadStop: (controller, loadedUrl) async {
          onLog('Page fully loaded.');
        },
        onConsoleMessage: (controller, consoleMessage) {
          String msg = consoleMessage.message.trim();
          
          // Debug log everything from our script
          if (msg.startsWith('AMRI_')) {
             // onLog('[DEBUG] $msg'); // Too noisy, keep it quiet
          }

          // Remove leading/trailing quotes if they exist (common in some webview implementations)
          if (msg.startsWith('"') && msg.endsWith('"')) {
            msg = msg.substring(1, msg.length - 1).replaceAll('\\"', '"');
          }
          
          if (msg.startsWith('AMRI_LOG:')) {
            onLog(msg.substring(9));
            return;
          } 
          
          if (msg.startsWith('AMRI_ERROR:')) {
            onLog('[ERROR] ${msg.substring(11)}');
            if (_sourcesCompleter != null && !_sourcesCompleter!.isCompleted) {
              _sourcesCompleter!.completeError(Exception(msg.substring(11)));
            }
            return;
          } 
          
          if (msg.startsWith('AMRI_SOURCES:')) {
            try {
              final jsonStr = msg.substring(13);
              final data = jsonDecode(jsonStr);
              
              final sources = data['sources'] as List?;
              if (sources != null && sources.isNotEmpty) {
                // Check if any source has a URL
                final hasUrl = sources.any((s) => s['url'] != null || s['file'] != null || s['src'] != null);
                if (hasUrl) {
                  onLog('📦 Received valid AMRI_SOURCES with ${sources.length} items (URLs found)');
                  _handleSourcesData(data);
                } else {
                  onLog('⚠️ Received ${sources.length} sources but NO URLs yet. Waiting...');
                }
              }
            } catch (e) {
              onLog('❌ Error parsing sources JSON: $e');
            }
            return;
          }

          // Only log relevant console messages to avoid noise
          if (msg.contains('[PlayerModal]') || msg.contains('sources')) {
             onLog('[Console] $msg');
          }
        },
      );
      
      await _headlessWebView!.run();
      
      onLog('Waiting for sources data...');
      
      final sourcesData = await _sourcesCompleter!.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Automation timed out after 30 seconds');
        },
      );
      
      onLog('✓ Extraction completed successfully!');
      onLog('✓ Got ${sourcesData['sources']?.length ?? 0} sources');
      
      return sourcesData;
      
    } catch (e) {
      onLog('✗ Extraction failed: $e');
      rethrow;
    } finally {
      await _cleanup();
      _sourcesCompleter = null;
    }
  }

  String _buildInterceptScript(String tmdbId) {
    return '''
      (function() {
        function log(msg) {
          console.log('AMRI_LOG:' + msg);
        }
        
        function sendError(msg) {
          console.log('AMRI_ERROR:' + msg);
        }
        
        function sendSources(data) {
          console.log('AMRI_SOURCES:' + JSON.stringify(data));
        }
        
        log('Intercepting fetch requests and console logs...');
        
        // Intercept fetch to capture sources response
        const originalFetch = window.fetch;
        window.fetch = function(...args) {
          return originalFetch.apply(this, args).then(async response => {
            const url = args[0] ? args[0].toString() : '';
            // Relaxed check: just look for /api/sources
            if (url.includes('/api/sources')) {
              log('✓ Intercepted sources API call: ' + url);
              try {
                const clone = response.clone();
                const data = await clone.json();
                // Only send if we have sources and at least one has a URL
                if (data && data.sources && Array.isArray(data.sources)) {
                   const hasUrl = data.sources.some(s => s.url || s.file || s.src);
                   if (hasUrl) {
                      log('✓ API sources have URLs, sending...');
                      sendSources(data);
                   } else {
                      log('⚠️ API sources found but NO URLs detected. Waiting for processing...');
                   }
                }
              } catch (e) {
                log('Error parsing API response: ' + e.toString());
              }
            }
            return response;
          });
        };

        // Intercept console.log to catch sources if fetch misses
        const originalLog = console.log;
        console.log = function(...args) {
            // Forward to original log first so we still see it in Flutter console
            originalLog.apply(this, args);

            try {
                // Find any argument that is an array
                const sourcesArray = args.find(arg => Array.isArray(arg));
                if (!sourcesArray) return;

                // Check for identifying strings in any argument
                const isRawSources = args.some(arg => typeof arg === 'string' && arg.includes('[PlayerModal] Raw sources'));
                const isProcessedSources = args.some(arg => typeof arg === 'string' && arg.includes('[PlayerModal] Processed sources'));

                if (isRawSources || isProcessedSources) {
                    const type = isRawSources ? 'raw' : 'processed';
                    log('✓ Found ' + type + ' sources in console (' + sourcesArray.length + ' items)');
                    
                    // Check if any source in the array has a URL
                    const validSources = sourcesArray.filter(s => s && (s.url || s.file || s.src));
                    if (validSources.length > 0) {
                        log('✓ Found ' + validSources.length + ' valid sources with URLs in console!');
                        sendSources({ sources: validSources });
                    } else {
                        log('⚠️ Found ' + type + ' sources array but no URLs yet. Waiting...');
                    }
                }
            } catch (e) {
                // Ignore errors in log interception to not break the page
            }
        };
        
        log('Intercept script ready (fetch + console), waiting...');
      })();
    ''';
  }

  Future<void> _cleanup() async {
    if (_headlessWebView != null) {
      try {
        await _headlessWebView?.dispose();
      } catch (e) {
        debugPrint('[AmriExtractor] Error during disposal: $e');
      }
      _headlessWebView = null;
    }
  }

  Future<void> dispose() async {
    await _cleanup();
    if (_sourcesCompleter != null && !_sourcesCompleter!.isCompleted) {
      _sourcesCompleter!.complete({'sources': []});
    }
  }
}
