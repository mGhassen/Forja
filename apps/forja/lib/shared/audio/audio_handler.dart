import 'package:audio_service/audio_service.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:forja/shared/audio/music_player_service.dart';

enum AudioPlayerType { music, audiobook }

class AppAudioHandler extends BaseAudioHandler with SeekHandler {
  AudioPlayerType _currentType = AudioPlayerType.music;
  dynamic _activePlayer;

  AppAudioHandler() {
    MusicPlayerService().bindAudioHandlerState(_updateState);
  }

  mk.Player get _musicPlayer => MusicPlayerService().player;

  void setPlayerType(AudioPlayerType type, dynamic player) {
    _currentType = type;
    _activePlayer = player;
    _updateState();
  }

  void _updateState() {
    if (_currentType != AudioPlayerType.music) return;
    if (!MusicPlayerService().hasMpvPlayer) return;

    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        _musicPlayer.state.playing ? MediaControl.pause : MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.playPause,
        MediaAction.stop,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: _musicPlayer.state.buffering ? AudioProcessingState.buffering : AudioProcessingState.ready,
      playing: _musicPlayer.state.playing,
      updatePosition: _musicPlayer.state.position,
      bufferedPosition: _musicPlayer.state.buffer, // Media-kit uses .buffer not .position for buffering
      speed: _musicPlayer.state.rate,
    ));
  }

  @override
  Future<void> play() async {
    if (_currentType == AudioPlayerType.music) {
      MusicPlayerService().play();
    } else {
      await _activePlayer.play();
    }
  }

  @override
  Future<void> pause() async {
    if (_currentType == AudioPlayerType.music) {
      MusicPlayerService().pause();
    } else {
      await _activePlayer.pause();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    if (_currentType == AudioPlayerType.music) {
      await _musicPlayer.seek(position);
    } else {
      await _activePlayer.seek(position);
    }
  }

  @override
  Future<void> skipToNext() async {
    if (_currentType == AudioPlayerType.music) {
      MusicPlayerService().next();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_currentType == AudioPlayerType.music) {
      MusicPlayerService().previous();
    }
  }

  void updateState(PlaybackState state) {
    if (_currentType == AudioPlayerType.audiobook) {
      playbackState.add(state);
    }
  }

  @override
  Future<void> updateMediaItem(MediaItem mediaItem) async {
    this.mediaItem.add(mediaItem);
  }

  @override
  Future<void> stop() async {
    if (_currentType == AudioPlayerType.music) {
      if (MusicPlayerService().hasMpvPlayer) {
        await _musicPlayer.stop();
      }
    } else {
      await _activePlayer.stop();
    }
    return super.stop();
  }

  @override
  Future<void> onTaskRemoved() async {
    await stop();
    await super.onTaskRemoved();
  }
}
