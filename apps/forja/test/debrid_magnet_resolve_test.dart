import 'package:flutter_test/flutter_test.dart';
import 'package:forja/shared/engine/models/models.dart';
import 'package:forja/shared/engine/packs/registry/plugin_contract.dart';
import 'package:forja/shared/engine/packs/registry/plugin_registry.dart';
import 'package:rust/rust.dart';

void main() {
  group('kind: debrid (RFC-114)', () {
    test('EnginePlugin.isDebrid + needsScript', () {
      final p = EnginePlugin.fromJson({
        'id': 'test-debrid-a',
        'name': 'Test Debrid A',
        'entry': 'a.js',
        'kind': 'debrid',
        'capabilities': ['resolve', 'settings'],
      });
      expect(p.isDebrid, isTrue);
      expect(p.isTorrent, isFalse);
      expect(p.needsScript, isTrue);
      expect(p.isExtractable, isFalse);
    });

    test('PluginContract accepts debrid kind', () {
      expect(PluginContract.supportedKinds, contains('debrid'));
      PluginContract.validateManifest({
        'schema': 1,
        'id': 'test-debrid-pack',
        'name': 'Test Debrid Pack',
        'version': '1.0.0',
        'plugins': [
          {
            'id': 'test-debrid-b',
            'name': 'Test Debrid B',
            'entry': 'b.js',
            'kind': 'debrid',
          },
        ],
      });
    });

    test('packKindKey maps debrid URL tree and plugin kind', () {
      final fromUrl = EnginePack.fromJson({
        'id': 'test-debrid-pack',
        'name': 'Test',
        'version': '1.0.0',
        'plugins': [
          {
            'id': 'test-debrid-c',
            'name': 'C',
            'entry': 'c.js',
            'kind': 'debrid',
          },
        ],
      }, sourceUrl: 'https://example.com/debrid/manifest.json');
      expect(
        PluginRegistry.packKindKey(fromUrl),
        PluginRegistry.packKindDebrid,
      );
      expect(PluginRegistry.packKindLabel(PluginRegistry.packKindDebrid), 'Debrid');

      final fromKind = EnginePack.fromJson({
        'id': 'community-debrid',
        'name': 'Community',
        'version': '1.0.0',
        'plugins': [
          {
            'id': 'test-debrid-d',
            'name': 'D',
            'entry': 'd.js',
            'kind': 'debrid',
          },
        ],
      }, sourceUrl: 'https://cdn.example/packs/other/manifest.json');
      expect(
        PluginRegistry.packKindKey(fromKind),
        PluginRegistry.packKindDebrid,
      );
    });

    test('legacy service name maps to plugin id', () {
      expect(
        SettingsService.legacyDebridServiceToPluginIdForTest('Real-Debrid'),
        'realdebrid',
      );
      expect(
        SettingsService.legacyDebridServiceToPluginIdForTest('TorBox'),
        'torbox',
      );
      expect(
        SettingsService.legacyDebridServiceToPluginIdForTest('AllDebrid'),
        'alldebrid',
      );
      expect(
        SettingsService.legacyDebridServiceToPluginIdForTest('Premiumize'),
        'premiumize',
      );
      expect(
        SettingsService.legacyDebridServiceToPluginIdForTest('Debrid-Link'),
        'debrid_link',
      );
      expect(
        SettingsService.legacyDebridServiceToPluginIdForTest('None'),
        isNull,
      );
    });

    test('resolveMagnetForPlayback uses DebridPackBridge exclusively', () async {
      TorrentPlaybackUrl? got;
      DebridPackBridge.activePluginId = () => 'test-debrid-e';
      DebridPackBridge.activePluginLabel = () => 'Test Debrid E';
      DebridPackBridge.resolve = ({
        required String magnet,
        int? season,
        int? episode,
        int? fileIdx,
      }) async {
        got = TorrentPlaybackUrl(
          'https://cdn.example/video.mkv',
          source: TorrentPlaybackSource.debrid,
          sourceLabel: 'Test Debrid E',
        );
        return got;
      };

      final url = await resolveMagnetForPlayback(
        magnet: 'magnet:?xt=urn:btih:abc',
        localTorrentEngine: true,
      );
      expect(url?.url, 'https://cdn.example/video.mkv');
      expect(url?.source, TorrentPlaybackSource.debrid);
      expect(got, isNotNull);

      DebridPackBridge.activePluginId = null;
      DebridPackBridge.activePluginLabel = null;
      DebridPackBridge.resolve = null;
    });

    test('active debrid plugin does not fall back to local on failure', () async {
      DebridPackBridge.activePluginId = () => 'test-debrid-f';
      DebridPackBridge.activePluginLabel = () => 'Test Debrid F';
      DebridPackBridge.resolve = ({
        required String magnet,
        int? season,
        int? episode,
        int? fileIdx,
      }) async {
        throw Exception('API key not set');
      };

      expect(
        () => resolveMagnetForPlayback(
          magnet: 'magnet:?xt=urn:btih:abc',
          localTorrentEngine: true,
        ),
        throwsA(isA<DebridAuthException>()),
      );

      DebridPackBridge.activePluginId = null;
      DebridPackBridge.activePluginLabel = null;
      DebridPackBridge.resolve = null;
    });

    test('playback labels use opaque plugin name', () {
      expect(
        playbackResolveLabel(debridLabel: 'Test Debrid G'),
        'Resolving with Test Debrid G',
      );
      expect(
        playbackSourceHint(debridLabel: 'Test Debrid G'),
        'Source: Test Debrid G (cloud)',
      );
      expect(playbackResolveLabel(), 'Starting Local Torrent Engine');
    });
  });
}
