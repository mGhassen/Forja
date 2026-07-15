import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:audio_service/audio_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:forja/features/audiobooks/catalog/audiobook_service.dart';
import 'package:forja/shared/audio/audio_handler.dart';
import 'package:forja/shared/audio/music_player_service.dart';
import 'package:forja/shared/player/player/utils.dart';
import 'package:forja/shared/services/mpv_exclusive_session.dart';

class AudiobookPlayerService {
  static final AudiobookPlayerService _instance = AudiobookPlayerService._internal();
  factory AudiobookPlayerService() => _instance;
  AudiobookPlayerService._internal();

  Player? _player;
  bool _playerListenersAttached = false;
  AppAudioHandler? _handler;
  
  // State
  final ValueNotifier<Audiobook?> currentBook = ValueNotifier<Audiobook?>(null);
  final ValueNotifier<int> currentChapterIndex = ValueNotifier<int>(0);
  final ValueNotifier<Duration> position = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<Duration> duration = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<bool> isPlaying = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isBuffering = ValueNotifier<bool>(false);
  final ValueNotifier<bool> autoplay = ValueNotifier<bool>(true);
  
  List<AudiobookChapter> _currentChapters = [];
  final List<StreamSubscription> _subscriptions = [];
  bool _isResuming = false;

  Player get player {
    _ensurePlayer();
    return _player!;
  }

  bool get hasMpvPlayer => _player != null;

  void _ensurePlayer() {
    if (_disposed) return;
    if (_player != null) return;
    _player = MpvExclusiveSession.instance.trackPlayer(Player());
    if (_handler != null) {
      _attachPlayerListeners();
    }
  }

  Future<void> releaseMpvForVideo() async {
    if (_player == null) return;
    final player = _player!;
    _player = null;
    _playerListenersAttached = false;
    isPlaying.value = false;
    isBuffering.value = false;
    MpvExclusiveSession.instance.untrackPlayer(player);
    for (final s in _subscriptions) {
      try {
        await s.cancel().timeout(const Duration(milliseconds: 200));
      } catch (_) {}
    }
    _subscriptions.clear();
    try {
      await teardownMediaKitPlayer(player);
    } catch (_) {}
  }

  void init(BaseAudioHandler handler) {
    _handler = handler as AppAudioHandler;
    if (_player != null) {
      _attachPlayerListeners();
    }
  }

  void _attachPlayerListeners() {
    if (_player == null || _playerListenersAttached) return;
    _playerListenersAttached = true;

    _subscriptions.add(_player!.stream.position.listen((p) {
      position.value = p;
      _updateSystemState();
      if (!_isResuming && p > Duration.zero) {
        _saveProgress();
      }
    }));
    
    _subscriptions.add(_player!.stream.duration.listen((d) {
      duration.value = d;
      _updateSystemState();
    }));
    
    _subscriptions.add(_player!.stream.playing.listen((pl) {
      isPlaying.value = pl;
      _updateSystemState();
    }));
    
    _subscriptions.add(_player!.stream.buffering.listen((b) {
      isBuffering.value = b;
      _updateSystemState();
    }));

    _subscriptions.add(_player!.stream.completed.listen((completed) {
      if (completed && autoplay.value) {
        final nextIdx = currentChapterIndex.value + 1;
        if (nextIdx < _currentChapters.length) {
          changeChapter(nextIdx);
        }
      }
    }));
  }

  void _updateSystemState() {
    if (_handler == null || currentBook.value == null) return;
    
    _handler!.updateState(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        isPlaying.value ? MediaControl.pause : MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: isBuffering.value ? AudioProcessingState.buffering : AudioProcessingState.ready,
      playing: isPlaying.value,
      updatePosition: position.value,
      bufferedPosition: position.value,
      speed: player.state.rate,
    ));
  }

  Future<void> loadBook(Audiobook book, List<AudiobookChapter> chapters, {int initialChapter = 0, Duration? resumePosition}) async {
    if (MpvExclusiveSession.required) {
      await MusicPlayerService().releaseMpvForVideo();
    }
    _isResuming = resumePosition != null && resumePosition > Duration.zero;
    currentBook.value = book;
    _currentChapters = chapters;
    currentChapterIndex.value = initialChapter;
    
    _handler?.setPlayerType(AudioPlayerType.audiobook, player);
    
    String artist = 'Tokybook';
    if (book.source == 'audiozaic') artist = 'Audiozaic';
    if (book.source == 'goldenaudiobook') artist = 'GoldenAudiobook';
    if (book.source == 'appaudiobooks') artist = 'AppAudiobooks';
    if (book.source == 'ezaudiobookforsoul') artist = 'EzAudiobookForSoul';

    _handler?.updateMediaItem(MediaItem(
      id: book.audioBookId,
      album: 'Audiobook',
      title: book.title,
      artist: artist,
      duration: null,
      artUri: Uri.tryParse(book.thumbUrl),
    ));

    if (player.platform is NativePlayer) {
      final p = player.platform as NativePlayer;
      await p.setProperty('hr-seek', 'yes');
      await p.setProperty('cache', 'yes');
      await p.setProperty('demuxer-max-bytes', '50000000');
      await p.setProperty('demuxer-max-back-bytes', '50000000');
      await p.setProperty('demuxer-readahead-secs', '30');
    }

    await player.open(Media(chapters[initialChapter].url, httpHeaders: chapters[initialChapter].headers), play: false);
    
    if (_isResuming) {
      debugPrint('AudiobookPlayerService: Resuming at $resumePosition');
      
      Completer<void> ready = Completer();
      late StreamSubscription durSub;
      durSub = player.stream.duration.listen((d) {
        if (d > Duration.zero && !ready.isCompleted) {
          ready.complete();
        }
      });

      await ready.future.timeout(const Duration(seconds: 8), onTimeout: () {});
      await durSub.cancel();

      await player.seek(resumePosition!);
      
      await Future.delayed(const Duration(milliseconds: 800));
      _isResuming = false;
    }
    
    player.play();
  }

  void playOrPause() => player.playOrPause();
  void seek(Duration p) => player.seek(p);
  void setRate(double r) => player.setRate(r);

  Future<void> stop() async {
    if (_player == null) return;
    await player.stop();
    _updateSystemState();
  }

  Future<void> changeChapter(int index) async {
    if (index < 0 || index >= _currentChapters.length) return;
    currentChapterIndex.value = index;
    await player.open(Media(_currentChapters[index].url, httpHeaders: _currentChapters[index].headers));
    player.play();
  }

  // --- Persistence (History) ---

  Future<void> _saveProgress() async {
    if (currentBook.value == null || _isResuming) return;
    final prefs = await SharedPreferences.getInstance();
    
    List<String> historyStrings = prefs.getStringList('audiobook_history') ?? [];
    List<Map<String, dynamic>> history = historyStrings.map((s) => json.decode(s) as Map<String, dynamic>).toList();

    final bookData = {
      'book': currentBook.value!.toJson(),
      'chapterIndex': currentChapterIndex.value,
      'positionMs': position.value.inMilliseconds,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    history.removeWhere((item) => item['book']['audioBookId'] == currentBook.value!.audioBookId);
    history.insert(0, bookData);
    
    if (history.length > 10) history = history.sublist(0, 10);

    await prefs.setStringList('audiobook_history', history.map((e) => json.encode(e)).toList());
  }

  Future<void> saveManualProgress() async {
    await _saveProgress();
  }

  Future<List<Map<String, dynamic>>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> history = prefs.getStringList('audiobook_history') ?? [];
    return history.map((s) => json.decode(s) as Map<String, dynamic>).toList();
  }

  Future<void> removeFromHistory(String audioBookId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> historyStrings = prefs.getStringList('audiobook_history') ?? [];
    historyStrings.removeWhere((s) {
      final data = json.decode(s);
      return data['book']['audioBookId'] == audioBookId;
    });
    await prefs.setStringList('audiobook_history', historyStrings);
  }

  // --- Liked Books ---

  Future<List<Audiobook>> getLikedBooks() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> liked = prefs.getStringList('audiobook_liked') ?? [];
    return liked.map((s) => Audiobook.fromJson(json.decode(s))).toList();
  }

  Future<bool> isBookLiked(String audioBookId) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> liked = prefs.getStringList('audiobook_liked') ?? [];
    return liked.any((s) => json.decode(s)['audioBookId'] == audioBookId);
  }

  Future<void> toggleLikeBook(Audiobook book) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> likedStrings = prefs.getStringList('audiobook_liked') ?? [];
    
    final index = likedStrings.indexWhere((s) => json.decode(s)['audioBookId'] == book.audioBookId);
    
    if (index >= 0) {
      likedStrings.removeAt(index);
    } else {
      likedStrings.add(json.encode(book.toJson()));
    }
    
    await prefs.setStringList('audiobook_liked', likedStrings);
  }

  bool _disposed = false;

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await releaseMpvForVideo();
  }
}
