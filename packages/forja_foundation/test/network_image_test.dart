import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forja_foundation/components/network_image.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_theme_extension.dart';

/// 1×1 transparent PNG — same bytes Flutter uses in painting tests.
const List<int> _kTransparentPng = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: forjaThemeData(),
    home: Scaffold(body: Center(child: child)),
  );
}

void _installFakeHttp(_FakeHttpClient client) {
  debugNetworkImageHttpClientProvider = () => client;
}

void _clearFakeHttp() {
  debugNetworkImageHttpClientProvider = null;
  PaintingBinding.instance.imageCache.clear();
  PaintingBinding.instance.imageCache.clearLiveImages();
}

void main() {
  testWidgets(
    'hides icon placeholder once the logo frame loads',
    (tester) async {
      final httpClient = _FakeHttpClient()..responseBytes = _kTransparentPng;
      _installFakeHttp(httpClient);
      try {
        await tester.pumpWidget(
          _wrap(
            ForjaNetworkImage(
              url: 'https://example.test/logo.png',
              width: 80,
              height: 80,
              fadeDuration: Duration.zero,
              placeholder: const Icon(Icons.tv_rounded, key: Key('ph')),
              error: const Icon(Icons.error, key: Key('err')),
            ),
          ),
        );

        // Network decode runs outside the fake-async zone.
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        await tester.pump();

        expect(find.byKey(const Key('ph')), findsNothing);
        expect(find.byKey(const Key('err')), findsNothing);
        expect(find.byType(Image), findsOneWidget);
      } finally {
        _clearFakeHttp();
      }
    },
    skip: kIsWeb,
  );

  testWidgets(
    'logo paint box fills the parent slot (not intrinsic PNG size)',
    (tester) async {
      final httpClient = _FakeHttpClient()..responseBytes = _kTransparentPng;
      _installFakeHttp(httpClient);
      try {
        await tester.pumpWidget(
          _wrap(
            const SizedBox(
              width: 120,
              height: 120,
              child: ForjaNetworkImage(
                url: 'https://example.test/logo.png',
                fit: BoxFit.contain,
                fadeDuration: Duration.zero,
              ),
            ),
          ),
        );
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        await tester.pump();

        final imageSize = tester.getSize(find.byType(Image));
        expect(imageSize.width, 120);
        expect(imageSize.height, 120);
      } finally {
        _clearFakeHttp();
      }
    },
    skip: kIsWeb,
  );

  testWidgets(
    'paintUnderlay false skips elevated surface under the logo',
    (tester) async {
      final httpClient = _FakeHttpClient()..responseBytes = _kTransparentPng;
      _installFakeHttp(httpClient);
      try {
        await tester.pumpWidget(
          _wrap(
            ForjaNetworkImage(
              url: 'https://example.test/logo.png',
              width: 80,
              height: 80,
              fadeDuration: Duration.zero,
              paintUnderlay: false,
            ),
          ),
        );
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        await tester.pump();

        final elevated = ForjaShellColors.surfaceElevated;
        final boxes = tester.widgetList<ColoredBox>(find.byType(ColoredBox));
        expect(
          boxes.where((b) => b.color == elevated),
          isEmpty,
          reason: 'channel logos must not paint surfaceElevated underlay',
        );
        expect(find.byType(Image), findsOneWidget);
      } finally {
        _clearFakeHttp();
      }
    },
    skip: kIsWeb,
  );

  testWidgets('shows error widget when the logo URL fails', (tester) async {
    final httpClient = _FakeHttpClient()
      ..statusCode = HttpStatus.notFound
      ..responseBytes = <int>[];
    _installFakeHttp(httpClient);
    try {
      await tester.pumpWidget(
        _wrap(
          ForjaNetworkImage(
            url: 'https://example.test/missing.png',
            width: 80,
            height: 80,
            fadeDuration: Duration.zero,
            placeholder: const Icon(Icons.tv_rounded, key: Key('ph')),
            error: const Icon(Icons.error, key: Key('err')),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();

      expect(find.byKey(const Key('err')), findsOneWidget);
      expect(find.byKey(const Key('ph')), findsNothing);
    } finally {
      _clearFakeHttp();
    }
  }, skip: kIsWeb);

  testWidgets('non-http URL uses the error widget', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const ForjaNetworkImage(
          url: 'not-absolute',
          width: 40,
          height: 40,
          error: Icon(Icons.tv_rounded, key: Key('err')),
        ),
      ),
    );
    expect(find.byKey(const Key('err')), findsOneWidget);
  });
}

class _FakeHttpClient extends Fake implements HttpClient {
  int statusCode = HttpStatus.ok;
  List<int> responseBytes = _kTransparentPng;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _FakeHttpClientRequest(statusCode, responseBytes);
}

class _FakeHttpClientRequest extends Fake implements HttpClientRequest {
  _FakeHttpClientRequest(this._statusCode, this._bytes);

  final int _statusCode;
  final List<int> _bytes;

  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  Future<HttpClientResponse> close() async =>
      _FakeHttpClientResponse(_statusCode, _bytes);
}

class _FakeHttpClientResponse extends Fake implements HttpClientResponse {
  _FakeHttpClientResponse(this.statusCode, this._bytes);

  final List<int> _bytes;

  @override
  final int statusCode;

  @override
  int get contentLength => _bytes.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable(<List<int>>[_bytes]).listen(
      onData,
      onDone: onDone,
      onError: onError,
      cancelOnError: cancelOnError,
    );
  }

  @override
  Future<E> drain<E>([E? futureValue]) async => futureValue as E;
}

class _FakeHttpHeaders extends Fake implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
}
