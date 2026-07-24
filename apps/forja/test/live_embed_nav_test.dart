import 'package:flutter_test/flutter_test.dart';
import 'package:forja/features/live_matches/live_embed_nav.dart';

void main() {
  group('liveEmbedIsWrapperCatalogUrl', () {
    test('matches catalog host and www sibling', () {
      expect(
        liveEmbedIsWrapperCatalogUrl(
          url: 'https://streamed.pk/',
          wrapperReferer: 'https://streamed.pk/',
        ),
        isTrue,
      );
      expect(
        liveEmbedIsWrapperCatalogUrl(
          url: 'https://www.streamed.pk/watch',
          wrapperReferer: 'https://streamed.pk/',
        ),
        isTrue,
      );
      expect(
        liveEmbedIsWrapperCatalogUrl(
          url: 'https://embed.st/abc',
          wrapperReferer: 'https://streamed.pk/',
        ),
        isFalse,
      );
    });
  });

  group('liveEmbedIsCatalogOriginRoot', () {
    test('only empty or slash path', () {
      expect(
        liveEmbedIsCatalogOriginRoot(
          url: 'https://streamed.pk/',
          wrapperReferer: 'https://streamed.pk/',
        ),
        isTrue,
      );
      expect(
        liveEmbedIsCatalogOriginRoot(
          url: 'https://streamed.pk',
          wrapperReferer: 'https://streamed.pk/',
        ),
        isTrue,
      );
      expect(
        liveEmbedIsCatalogOriginRoot(
          url: 'https://streamed.pk/watch/foo',
          wrapperReferer: 'https://streamed.pk/',
        ),
        isFalse,
      );
    });
  });

  group('liveEmbedAllowsMainFrameNavigation', () {
    test('always allows about/data/blob', () {
      expect(
        liveEmbedAllowsMainFrameNavigation(
          url: 'about:blank',
          embedUrl: 'https://embed.st/x',
          allowEmbedHostAsMainFrame: false,
        ),
        isTrue,
      );
      expect(
        liveEmbedAllowsMainFrameNavigation(
          url: 'data:text/html,hi',
          embedUrl: 'https://embed.st/x',
          allowEmbedHostAsMainFrame: false,
        ),
        isTrue,
      );
    });

    test('always allows loadData catalog origin root', () {
      expect(
        liveEmbedAllowsMainFrameNavigation(
          url: 'https://streamed.pk/',
          embedUrl: 'https://embed.st/x',
          allowEmbedHostAsMainFrame: false,
          wrapperReferer: 'https://streamed.pk/',
        ),
        isTrue,
      );
      expect(
        liveEmbedAllowsMainFrameNavigation(
          url: 'https://ppv.is/',
          embedUrl: 'https://embedindia.st/x',
          allowEmbedHostAsMainFrame: false,
          wrapperReferer: 'https://ppv.is/',
        ),
        isTrue,
      );
    });

    test('still blocks deeper catalog SPA paths', () {
      expect(
        liveEmbedAllowsMainFrameNavigation(
          url: 'https://streamed.pk/watch/foo',
          embedUrl: 'https://embed.st/x',
          allowEmbedHostAsMainFrame: false,
          wrapperReferer: 'https://streamed.pk/',
        ),
        isFalse,
      );
    });

    test('Android direct embed allows embed host main-frame', () {
      expect(
        liveEmbedAllowsMainFrameNavigation(
          url: 'https://embed.st/abc',
          embedUrl: 'https://embed.st/abc',
          allowEmbedHostAsMainFrame: true,
        ),
        isTrue,
      );
      expect(
        liveEmbedAllowsMainFrameNavigation(
          url: 'https://cdn.player.example/seg',
          embedUrl: 'https://embed.st/abc',
          allowEmbedHostAsMainFrame: true,
        ),
        isFalse,
      );
    });
  });
}
