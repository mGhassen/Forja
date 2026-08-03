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

    test('desktop wrapper keeps PPV embedindia off the main frame', () {
      // Widget passes allowEmbedHostAsMainFrame=false outside Android handoff.
      expect(
        liveEmbedAllowsMainFrameNavigation(
          url: 'https://embedindia.st/embed/mlb/x',
          embedUrl: 'https://embedindia.st/embed/mlb/x',
          allowEmbedHostAsMainFrame: false,
          wrapperReferer: 'https://ppv.is/',
        ),
        isFalse,
      );
      expect(
        liveEmbedAllowsMainFrameNavigation(
          url: 'https://adscope.gotrackier.com/click?x=1',
          embedUrl: 'https://embedindia.st/embed/mlb/x',
          allowEmbedHostAsMainFrame: false,
          wrapperReferer: 'https://ppv.is/',
        ),
        isFalse,
      );
      expect(
        liveEmbedAllowsMainFrameNavigation(
          url: 'https://ppv.is/',
          embedUrl: 'https://embedindia.st/embed/mlb/x',
          allowEmbedHostAsMainFrame: false,
          wrapperReferer: 'https://ppv.is/',
        ),
        isTrue,
      );
    });
  });

  group('liveEmbedRequiresWebViewPlayback', () {
    test('embedindia and Streamed both use native handoff on Android', () {
      expect(
        liveEmbedRequiresWebViewPlayback(
          'https://embedindia.st/embed/mlb/x?gid=1',
        ),
        isTrue,
      );
      expect(
        liveEmbedAndroidNativeHandoff(
          'https://embedindia.st/embed/mlb/x?gid=1',
        ),
        isTrue,
      );
      expect(
        liveEmbedRequiresWebViewPlayback('https://embed.st/abc'),
        isFalse,
      );
      // Streamed: sniff → native (WebView-only hits CORS / red sandbox lock).
      expect(liveEmbedAndroidNativeHandoff('https://embed.st/abc'), isTrue);
      expect(
        liveEmbedAndroidNativeHandoff(
          'https://embedindia.st/embed/mlb/x?gid=1',
        ),
        isTrue,
      );
    });
  });

  group('LiveEmbedAndroidHandoffProfile', () {
    test('Streamed profile still describes catalog iframe load', () {
      final p = LiveEmbedAndroidHandoffProfile.forEmbed(
        'https://embed.st/embed/admin/foo/1',
      );
      expect(p.isStreamed, isTrue);
      expect(p.topLevelEmbedLoad, isFalse);
    });

    test('PPV stays top-level with no soft recover', () {
      final p = LiveEmbedAndroidHandoffProfile.forEmbed(
        'https://embedindia.st/embed/mlb/x?gid=1',
      );
      expect(p.isPpv, isTrue);
      expect(p.topLevelEmbedLoad, isTrue);
      expect(p.maxSoftRecover, 0);
      expect(p.maxProbeAttempts, 3);
    });
  });

  group('liveEmbed nested embedindia peel', () {
    test('mayNest only for Streamed wrapper hosts', () {
      expect(
        liveEmbedMayNestEmbedIndia(
          'https://embed.st/embed/admin/admin-rally-tv/1',
        ),
        isTrue,
      );
      expect(
        liveEmbedMayNestEmbedIndia(
          'https://embedindia.st/embed-noads/rally-tv',
        ),
        isFalse,
      );
      expect(
        liveEmbedMayNestEmbedIndia('https://strmd.st/playlist.m3u8'),
        isFalse,
      );
    });

    test('extracts iframe src from embed.st HTML', () {
      const html =
          '<iframe src="https://embedindia.st/embed-noads/rally-tv" '
          'allowfullscreen></iframe>';
      expect(
        liveEmbedExtractNestedEmbedIndiaUrl(html),
        'https://embedindia.st/embed-noads/rally-tv',
      );
      expect(liveEmbedExtractNestedEmbedIndiaUrl('<div></div>'), isNull);
    });

    test('peeled embedindia uses PPV native handoff', () {
      const peeled = 'https://embedindia.st/embed-noads/rally-tv';
      expect(liveEmbedAndroidNativeHandoff(peeled), isTrue);
      expect(liveEmbedProviderKind(peeled), LiveEmbedProviderKind.ppv);
    });
  });
}
