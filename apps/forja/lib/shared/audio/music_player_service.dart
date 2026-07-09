import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:rust/rust.dart';
import 'package:forja/shared/audio/music_storage_service.dart';
import 'package:forja/shared/audio/audio_handler.dart';
import 'package:forja/shared/audio/lyrics_service.dart';
import 'package:forja/shared/audio/audiobook_player_service.dart';
import 'package:forja/shared/services/mpv_exclusive_session.dart';

class MusicPlayerService {
  static final MusicPlayerService _instance = MusicPlayerService._internal();
  factory MusicPlayerService() => _instance;
  MusicPlayerService._internal();

  Player? _player;
  bool _playerListenersAttached = false;
  void Function()? _audioHandlerStateSink;
  final MusicService _musicService = MusicService();
  final MusicStorageService _storageService = MusicStorageService();
  AppAudioHandler? _handler;
  final LyricsService _lyricsService = LyricsService();

  Player get player {
    _ensurePlayer();
    return _player!;
  }

  bool get hasMpvPlayer => _player != null;

  void bindAudioHandlerState(void Function() onState) {
    _audioHandlerStateSink = onState;
    if (_playerListenersAttached) onState();
  }

  void _ensurePlayer() {
    if (_disposed) return;
    if (_player != null) return;
    _player = MpvExclusiveSession.instance.trackPlayer(Player());
    if (_initialized) {
      _attachPlayerListeners();
    }
  }

  Future<void> releaseMpvForVideo() async {
    if (_player == null) return;
    final player = _player!;
    MpvExclusiveSession.instance.untrackPlayer(player);
    try {
      await player.stop();
    } catch (_) {}
    try {
      await player.dispose();
    } catch (_) {}
    _player = null;
    _playerListenersAttached = false;
    isPlaying.value = false;
    isBuffering.value = false;
  }

  void setHandler(BaseAudioHandler handler) {
    _handler = handler as AppAudioHandler;
  }

  final ValueNotifier<MusicTrack?> currentTrack = ValueNotifier<MusicTrack?>(null);
  final ValueNotifier<List<MusicTrack>> playlist = ValueNotifier<List<MusicTrack>>([]);
  final ValueNotifier<bool> isPlaying = ValueNotifier<bool>(false);
  final ValueNotifier<Duration> position = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<Duration> duration = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<bool> isBuffering = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isShuffleEnabled = ValueNotifier<bool>(false);
  final ValueNotifier<PlaylistMode> loopMode = ValueNotifier<PlaylistMode>(PlaylistMode.none);
  final ValueNotifier<bool> isFullScreenVisible = ValueNotifier<bool>(false);
  final ValueNotifier<List<LyricLine>?> lyrics = ValueNotifier<List<LyricLine>?>(null);
  final ValueNotifier<Widget?> bottomWidget = ValueNotifier<Widget?>(null);

  int _currentIndex = -1;
  bool _initialized = false;
  // ignore: unused_field
  bool _isManuallyPaused = false;
  bool _isLoadingTrack = false;
  int _playGeneration = 0; // Cancellation token for YT extraction
  final Set<String> _shufflePlayedIds = {};
  final Random _random = Random();

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    
    // Configure audio session
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    // Listen for interruptions (Phone calls, other apps starting media)
    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        switch (event.type) {
          case AudioInterruptionType.duck:
            // Optional: Lower volume
            break;
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            pause();
            break;
        }
      }
    });

    // Listen for "becoming noisy" (Headphones unplugged)
    session.becomingNoisyEventStream.listen((_) => pause());

    // Initialize storage notifiers
    await _storageService.init();

    if (_player != null) {
      _attachPlayerListeners();
    }
  }

  void _attachPlayerListeners() {
    if (_player == null || _playerListenersAttached) return;
    _playerListenersAttached = true;

    // Listen to player state streams
    _player!.stream.playing.listen((p) {
      debugPrint('MusicPlayerService: playing state changed -> $p');
      isPlaying.value = p;
      _audioHandlerStateSink?.call();
      // Request audio focus when starting to play
      if (p) {
        AudioSession.instance.then((s) => s.setActive(true));
      }
    });
    _player!.stream.buffering.listen((b) {
      debugPrint('MusicPlayerService: buffering -> $b');
      isBuffering.value = b;
      _audioHandlerStateSink?.call();
    });
    _player!.stream.position.listen((p) {
      position.value = p;
      _audioHandlerStateSink?.call();
    });
    _player!.stream.duration.listen((d) {
      if (d != Duration.zero) {
        debugPrint('MusicPlayerService: duration loaded -> $d');
      }
      duration.value = d;
      _audioHandlerStateSink?.call();
    });
    _player!.stream.playlistMode.listen((m) => loopMode.value = m);

    _player!.stream.error.listen((e) {
      debugPrint('MusicPlayerService: PLAYER ERROR -> $e');
    });
    _player!.stream.log.listen((l) {
      // mpv-level logs (warn/error only to keep noise down).
      // NOTE: media_kit's libmpv log callback is shared globally across all
      // Player instances in the process — meaning logs from the IPTV player
      // (or any other Player) also reach this listener. Only print when this
      // service has an active track loaded so we don't take blame for
      // unrelated mpv chatter.
      if (currentTrack.value == null) return;
      if (l.level == 'error' || l.level == 'warn' || l.level == 'fatal') {
        debugPrint('MusicPlayerService: mpv [${l.level}] ${l.prefix}: ${l.text}');
      }
    });

    _player!.stream.completed.listen((completed) {
      debugPrint('MusicPlayerService: completed -> $completed');
      if (completed && !_isLoadingTrack) {
        next();
      }
      _audioHandlerStateSink?.call();
    });
  }

  Future<void> playTrack(MusicTrack track, {List<MusicTrack>? newPlaylist}) async {
    debugPrint('MusicPlayerService: Preparing to play: ${track.title} by ${track.artist}');
    if (MpvExclusiveSession.required) {
      await AudiobookPlayerService().releaseMpvForVideo();
    }
    
    _isLoadingTrack = true;
    final generation = ++_playGeneration; // Cancel any in-flight extraction
    try {
      // 0. Set session active immediately
      final session = await AudioSession.instance;
      final sessionOk = await session.setActive(true);
      debugPrint('MusicPlayerService: audio session active=$sessionOk');

      debugPrint('MusicPlayerService: stopping previous playback');
      await player.stop();

      if (newPlaylist != null) {
        playlist.value = newPlaylist;
        _currentIndex = newPlaylist.indexWhere((t) => t.id == track.id);
        // Reset shuffle tracking for new playlist
        _shufflePlayedIds.clear();
      }

      // Mark this track as played for shuffle
      if (isShuffleEnabled.value) {
        _shufflePlayedIds.add(track.id);
      }

      currentTrack.value = track;
      position.value = Duration.zero;
      duration.value = Duration.zero;
      _isManuallyPaused = false;
      lyrics.value = null;

      // Update notification metadata
      _handler?.updateMediaItem(MediaItem(
        id: track.id,
        album: track.album,
        title: track.title,
        artist: track.artist,
        displayTitle: track.title,
        displaySubtitle: track.artist,
        duration: Duration(seconds: track.duration),
        artUri: track.cover.startsWith('http') 
            ? Uri.tryParse(track.cover) 
            : Uri.file(track.cover),
      ));

      _fetchLyricsForTrack(track);

      // 1. Local Offline Playback
      if (track.localPath != null) {
        final file = File(track.localPath!);
        if (await file.exists()) {
          debugPrint('MusicPlayerService: Playing from local storage: ${track.localPath}');
          try {
            await player.open(Media(track.localPath!));
            debugPrint('MusicPlayerService: open() returned for local file');
          } catch (e, st) {
            debugPrint('MusicPlayerService: open() THREW for local file: $e\n$st');
            rethrow;
          }
          _prefetchNext();
          return;
        } else {
          debugPrint('MusicPlayerService: localPath set but file missing: ${track.localPath}');
        }
      }

      // 2. YouTube Match (cached + runs in background isolate)
      debugPrint('MusicPlayerService: resolving videoId for "${track.title}" / "${track.artist}"');
      final videoId = await _musicService.getYoutubeVideoId(track.title, track.artist);
      if (_playGeneration != generation) {
        debugPrint('MusicPlayerService: Cancelled (after videoId) — newer track requested');
        return;
      }
      if (videoId == null) {
        debugPrint('MusicPlayerService: No YouTube match');
        return;
      }
      debugPrint('MusicPlayerService: videoId=$videoId');

      // 3. Stream URL (cached + runs in background isolate)
      final streamUrl = await _musicService.getYoutubeStreamUrl(videoId);
      if (_playGeneration != generation) {
        debugPrint('MusicPlayerService: Cancelled (after streamUrl) — newer track requested');
        return;
      }
      if (streamUrl == null || streamUrl.isEmpty) {
        debugPrint('MusicPlayerService: Failed to get stream URL (null/empty)');
        return;
      }
      final preview = streamUrl.length > 120 ? '${streamUrl.substring(0, 120)}…' : streamUrl;
      debugPrint('MusicPlayerService: streamUrl=$preview');

      try {
        debugPrint('MusicPlayerService: calling player.open()');
        await player.open(Media(streamUrl));
        debugPrint('MusicPlayerService: open() returned, playing=${player.state.playing}');
      } catch (e, st) {
        debugPrint('MusicPlayerService: open() THREW: $e\n$st');
        rethrow;
      }
      _prefetchNext();
      
    } catch (e, st) {
      debugPrint('MusicPlayerService: Error playing track: $e\n$st');
    } finally {
      Future.delayed(const Duration(milliseconds: 1500), () {
        _isLoadingTrack = false;
      });
    }
  }

  void _fetchLyricsForTrack(MusicTrack track) async {
    try {
      final localLyrics = await _lyricsService.getLocalLyrics(track);
      if (localLyrics != null) {
        lyrics.value = localLyrics;
        return;
      }

      final onlineLyrics = await _lyricsService.getSyncedLyrics(
        trackName: track.title,
        artistName: track.artist,
        albumName: track.album,
        durationSeconds: track.duration,
      );
      
      if (onlineLyrics != null) {
        lyrics.value = onlineLyrics;
      } else {
        lyrics.value = []; // Explicitly mark as not found
      }
    } catch (e) {
      debugPrint('MusicPlayerService: Error fetching lyrics: $e');
      lyrics.value = []; // Mark as not found on error too
    }
  }

  void _prefetchNext() async {
    if (playlist.value.isEmpty || _currentIndex == -1) return;
    final nextIndex = (_currentIndex + 1) % playlist.value.length;
    final nextTrack = playlist.value[nextIndex];
    // Prefetch both video ID and stream URL so next track plays instantly
    final videoId = await _musicService.getYoutubeVideoId(nextTrack.title, nextTrack.artist);
    if (videoId != null) {
      await _musicService.getYoutubeStreamUrl(videoId);
    }
  }

  void play() => player.play();
  void pause() => player.pause();
  void togglePlay() => player.playOrPause();

  Future<void> stop() async {
    if (_player == null) return;
    await player.stop();
    currentTrack.value = null;
    playlist.value = [];
    _currentIndex = -1;
    isPlaying.value = false;
    _handler?.stop();
  }

  void toggleShuffle() async {
    isShuffleEnabled.value = !isShuffleEnabled.value;
    _shufflePlayedIds.clear();
    // Mark current song as played so it won't be picked next
    if (isShuffleEnabled.value && currentTrack.value != null) {
      _shufflePlayedIds.add(currentTrack.value!.id);
    }
  }

  void toggleLoop() async {
    final modes = [PlaylistMode.none, PlaylistMode.loop, PlaylistMode.single];
    final nextIndex = (modes.indexOf(player.state.playlistMode) + 1) % modes.length;
    await player.setPlaylistMode(modes[nextIndex]);
  }

  void seek(Duration pos) => player.seek(pos);

  void next() {
    if (playlist.value.isEmpty) return;

    if (isShuffleEnabled.value) {
      // Build list of unplayed indices, excluding the current track
      final unplayed = <int>[];
      for (int i = 0; i < playlist.value.length; i++) {
        if (!_shufflePlayedIds.contains(playlist.value[i].id)) {
          unplayed.add(i);
        }
      }

      if (unplayed.isEmpty) {
        // All songs have been played — stop playback
        pause();
        return;
      }

      final nextIndex = unplayed[_random.nextInt(unplayed.length)];
      _currentIndex = nextIndex;
      _shufflePlayedIds.add(playlist.value[nextIndex].id);
      playTrack(playlist.value[nextIndex]);
    } else {
      _currentIndex = (_currentIndex + 1) % playlist.value.length;
      playTrack(playlist.value[_currentIndex]);
    }
  }

  void previous() {
    if (playlist.value.isEmpty) return;
    _currentIndex = (_currentIndex - 1) % playlist.value.length;
    if (_currentIndex < 0) _currentIndex = playlist.value.length - 1;
    playTrack(playlist.value[_currentIndex]);
  }

  bool _disposed = false;

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await releaseMpvForVideo();
    _musicService.dispose();
  }
}
