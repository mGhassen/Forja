import 'package:audioplayers/audioplayers.dart';

class SplashSound {
  AudioPlayer? _player;

  Future<void> play() async {
    try {
      _player ??= AudioPlayer();
      await _player!.setVolume(0.4);
      await _player!.play(AssetSource('sounds/splash_sting.wav'));
    } catch (_) {}
  }

  Future<void> dispose() async {
    await _player?.dispose();
    _player = null;
  }
}
