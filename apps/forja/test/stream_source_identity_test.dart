import 'package:flutter_test/flutter_test.dart';
import 'package:rust/rust.dart';

void main() {
  test('StreamSource JSON keeps providerId and catalogUrl', () {
    final s = StreamSource(
      url: 'https://cdn.example/master.m3u8',
      title: 'Stream',
      type: 'hls',
      headers: const {'Referer': 'https://megaplay.buzz/'},
      providerId: 'megaplay',
      catalogUrl: 'https://cdn.example/master.m3u8',
    );
    final round = StreamSource.fromJson(s.toJson());
    expect(round.providerId, 'megaplay');
    expect(round.catalogUrl, 'https://cdn.example/master.m3u8');
    expect(round.headers?['Referer'], contains('megaplay'));
  });
}
