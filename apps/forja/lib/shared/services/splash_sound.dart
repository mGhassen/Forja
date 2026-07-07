import 'package:audioplayers/audioplayers.dart';

/// Peak logo scale during green snap (see animated_logo bounce curve).
const splashTakAt = Duration(milliseconds: 4250);

class SplashSound {
  SplashSound._();

  static final SplashSound instance = SplashSound._();

  static final _source = AssetSource('sounds/splash_sting.wav');

  AudioPlayer? _player;
  Future<void>? _preloadFuture;

  Future<void> preload() {
    _preloadFuture ??= _preload();
    return _preloadFuture!;
  }

  Future<void> _preload() async {
    try {
      _player ??= AudioPlayer();
      await _player!.setReleaseMode(ReleaseMode.stop);
      await _player!.setVolume(0.4);
      await _player!.setSource(_source);
    } catch (_) {}
  }

  Future<void> play() async {
    try {
      await preload();
      await _player!.seek(Duration.zero);
      await _player!.resume();
    } catch (_) {}
  }
}
