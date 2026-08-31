import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:forja/shared/utils/language_display.dart';
import 'package:media_kit/media_kit.dart';

/// Common ISO-639-1 / ISO-639-2 codes mapped to display names.
/// Order matters in the picker UI - most common first. Aliases include
/// codes, English names, native names, and a few common foreign-language
/// renderings so that fuzzy detection on a track's `language` or `title`
/// field works no matter how the source labels it.
const List<MapEntry<String, List<String>>> kTrackLanguageOptions = [
  MapEntry('English',     ['en', 'eng', 'english', 'ingles', 'inglés', 'anglais', 'inglese', 'angielski']),
  MapEntry('Arabic',      ['ar', 'ara', 'arabic', 'عربي', 'العربية', 'arabe', 'árabe']),
  MapEntry('Spanish',     ['es', 'spa', 'esp', 'spanish', 'castellano', 'español', 'espanol', 'castilian', 'latino', 'latin american', 'es-la', 'es-419']),
  MapEntry('French',      ['fr', 'fra', 'fre', 'french', 'francais', 'français', 'francés', 'francese']),
  MapEntry('German',      ['de', 'deu', 'ger', 'german', 'deutsch', 'aleman', 'alemán', 'tedesco']),
  MapEntry('Italian',     ['it', 'ita', 'italian', 'italiano']),
  MapEntry('Portuguese',  ['pt', 'por', 'portuguese', 'português', 'portugues', 'brasileiro', 'brazilian', 'pt-br', 'pt-pt']),
  MapEntry('Russian',     ['ru', 'rus', 'russian', 'русский', 'рус']),
  MapEntry('Japanese',    ['ja', 'jpn', 'jap', 'japanese', '日本語', 'nihongo']),
  MapEntry('Chinese',     ['zh', 'zho', 'chi', 'chs', 'cht', 'chinese', 'mandarin', 'cantonese', '中文', '普通话', '粉语', 'zh-cn', 'zh-tw', 'zh-hk']),
  MapEntry('Korean',      ['ko', 'kor', 'korean', '한국어']),
  MapEntry('Hindi',       ['hi', 'hin', 'hindi', 'हिन्दी']),
  MapEntry('Turkish',     ['tr', 'tur', 'turkish', 'türkçe', 'turkce']),
  MapEntry('Polish',      ['pl', 'pol', 'polish', 'polski']),
  MapEntry('Dutch',       ['nl', 'nld', 'dut', 'dutch', 'nederlands', 'flemish', 'vlaams']),
  MapEntry('Swedish',     ['sv', 'swe', 'swedish', 'svenska']),
  MapEntry('Norwegian',   ['no', 'nor', 'nob', 'nno', 'norwegian', 'norsk']),
  MapEntry('Danish',      ['da', 'dan', 'danish', 'dansk']),
  MapEntry('Finnish',     ['fi', 'fin', 'finnish', 'suomi']),
  MapEntry('Czech',       ['cs', 'ces', 'cze', 'czech', 'čeština', 'cestina']),
  MapEntry('Greek',       ['el', 'ell', 'gre', 'greek', 'Ελληνικά', 'ellinika']),
  MapEntry('Hebrew',      ['he', 'heb', 'iw', 'hebrew', 'עברית']),
  MapEntry('Indonesian',  ['id', 'ind', 'indonesian', 'bahasa indonesia']),
  MapEntry('Thai',        ['th', 'tha', 'thai', 'ไทย']),
  MapEntry('Vietnamese',  ['vi', 'vie', 'vietnamese', 'tiếng việt']),
  MapEntry('Ukrainian',   ['uk', 'ukr', 'ukrainian', 'українська']),
  MapEntry('Romanian',    ['ro', 'ron', 'rum', 'romanian', 'română']),
  MapEntry('Hungarian',   ['hu', 'hun', 'hungarian', 'magyar']),
  MapEntry('Bulgarian',   ['bg', 'bul', 'bulgarian', 'български']),
  MapEntry('Persian',     ['fa', 'fas', 'per', 'persian', 'farsi', 'فارسی']),
];

const List<String> kTrackLanguageDisplayNames = [
  'None',
  'English', 'Arabic', 'Spanish', 'French', 'German', 'Italian',
  'Portuguese', 'Russian', 'Japanese', 'Chinese', 'Korean', 'Hindi',
  'Turkish', 'Polish', 'Dutch', 'Swedish', 'Norwegian', 'Danish',
  'Finnish', 'Czech', 'Greek', 'Hebrew', 'Indonesian', 'Thai',
  'Vietnamese', 'Ukrainian', 'Romanian', 'Hungarian', 'Bulgarian',
  'Persian',
];

/// True if [track]'s language/title matches the human-readable [displayName]
/// (e.g. "English"). Falls back to substring matching on the title.
bool _matchesLanguage(String displayName, String? language, String? title) {
  return matchesPreferredLanguage(displayName,
      language: language, title: title);
}

/// Public version of [_matchesLanguage] — for scraped/online subtitle rows
/// (`language` / `display` keys), not embedded [SubtitleTrack] objects.
bool matchesPreferredLanguage(String displayName,
    {String? language, String? title}) {
  if (displayName == 'None' || displayName.isEmpty) return false;
  final aliases = <String>{
    displayName.toLowerCase(),
    ...kTrackLanguageOptions
        .firstWhere((e) => e.key == displayName,
            orElse: () => const MapEntry('', <String>[]))
        .value
        .map((s) => s.toLowerCase()),
  }..removeWhere((s) => s.isEmpty);
  if (aliases.isEmpty) return false;

  final lang = _normalize(language);
  final ttl = _normalize(title);

  // Quick reject for the common "unknown" sentinels.
  const unknown = {'und', 'undefined', 'unknown', 'mul', 'zxx', '', 'qaa'};

  for (final raw in aliases) {
    final a = _normalize(raw);
    if (a.isEmpty) continue;
    // Exact / locale-prefixed code match against language field.
    if (lang.isNotEmpty && !unknown.contains(lang)) {
      if (lang == a) return true;
      if (lang.startsWith('$a-') || lang.startsWith('${a}_')) return true;
      if (a.startsWith('$lang-') || a.startsWith('${lang}_')) return true;
    }
    // Substring match against the human title (e.g. "English 5.1").
    if (ttl.isNotEmpty && a.length >= 2) {
      // For 2-letter codes, require word-boundary so "de" doesn't match
      // "adventure". For ≥3-char tokens, plain substring is fine.
      if (a.length == 2) {
        if (RegExp('(?:^|[^a-z])$a(?:[^a-z]|\$)').hasMatch(ttl)) return true;
      } else {
        if (ttl.contains(a)) return true;
      }
    }
  }
  return false;
}

/// Lower-cases, trims, strips diacritics, collapses whitespace, and removes
/// surrounding punctuation/brackets so different sources' label conventions
/// compare cleanly ("English [Forced]" → "english forced").
String _normalize(String? s) {
  if (s == null) return '';
  var x = s.toLowerCase().trim();
  if (x.isEmpty) return '';
  // Strip combining diacritics (NFD-style mapping for the common Latin set).
  const accentMap = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
    'ý': 'y', 'ÿ': 'y',
    'ñ': 'n', 'ç': 'c',
  };
  final buf = StringBuffer();
  for (final r in x.runes) {
    final ch = String.fromCharCode(r);
    buf.write(accentMap[ch] ?? ch);
  }
  x = buf.toString();
  // Collapse separators, drop surrounding brackets / punctuation.
  x = x.replaceAll(RegExp(r'[\[\](){}【】]'), ' ');
  x = x.replaceAll(RegExp(r'\s+'), ' ').trim();
  return x;
}

/// Maps a track/subtitle label to a [kTrackLanguageDisplayNames] entry
/// (e.g. `"fr"` / `"Français"` → `"French"`). Returns null if unknown.
String? resolvePreferredLanguageDisplayName({
  String? language,
  String? title,
}) {
  for (final name in kTrackLanguageDisplayNames) {
    if (name == 'None') continue;
    if (matchesPreferredLanguage(name, language: language, title: title)) {
      return name;
    }
  }
  return null;
}

const _kRegionalSpanishLangTags = {
  'es-la',
  'es-419',
  'latino',
  'latin american',
  'latin america',
};

/// Bare two-letter tags that often appear on HLS muxes with no ISO meaning.
const _kUnreliableBareLangCodes = {'la', 'sv', 'no'};

bool _bareLangTagReliable(String? language, String? title) {
  final lang = _normalize(language);
  if (lang.isEmpty) return false;
  if (lang.length >= 3) return true;
  if (lang.length != 2) return false;
  if (!_kUnreliableBareLangCodes.contains(lang)) return true;
  final fromTitle = resolvePreferredLanguageDisplayName(
    language: null,
    title: title,
  );
  final fromLang = resolvePreferredLanguageDisplayName(
    language: language,
    title: null,
  );
  return fromTitle != null && fromTitle == fromLang;
}

String? _endonymFromPreferredDisplay(
  String display, {
  String? language,
}) {
  final langNorm = _normalize(language);
  if (display == 'Spanish' &&
      _kRegionalSpanishLangTags.contains(langNorm)) {
    return 'Español (Latinoamérica)';
  }
  if (display == 'Portuguese' &&
      (langNorm == 'pt-br' || langNorm.startsWith('pt-br'))) {
    return 'Português (Brasil)';
  }
  for (final entry in kTrackLanguageOptions) {
    if (entry.key != display) continue;
    for (final alias in entry.value) {
      if (RegExp(r'^[a-z]{2}(-[a-z0-9]+)?$').hasMatch(alias)) {
        final endo = languageEndonym(alias);
        if (endo != null && endo != 'Unknown') return endo;
      }
    }
    break;
  }
  final fromDisplay = languageEndonym(display);
  if (fromDisplay != null && fromDisplay != 'Unknown') return fromDisplay;
  return null;
}

/// Native endonym for an audio/subtitle track — mux [title] first, then lang
/// when the tag is trustworthy. Unreliable bare tags fall back to null.
String? trackLanguageEndonym({
  String? language,
  String? title,
}) {
  final titleDisplay = resolvePreferredLanguageDisplayName(
    language: null,
    title: title,
  );
  if (titleDisplay != null) {
    return _endonymFromPreferredDisplay(titleDisplay, language: language);
  }

  if (!_bareLangTagReliable(language, title)) return null;

  final display = resolvePreferredLanguageDisplayName(
    language: language,
    title: null,
  );
  if (display != null) {
    return _endonymFromPreferredDisplay(display, language: language);
  }

  final fromLang = languageEndonym(language);
  if (fromLang != null && fromLang != 'Unknown') return fromLang;

  final trimmedTitle = title?.trim();
  if (trimmedTitle != null && trimmedTitle.isNotEmpty) {
    final fromTitle = languageEndonym(trimmedTitle);
    if (fromTitle != null && fromTitle != 'Unknown') return fromTitle;
    final first = trimmedTitle.split(RegExp(r'[\s\[\(,/·]+')).first;
    final fromFirst = languageEndonym(first);
    if (fromFirst != null && fromFirst != 'Unknown') return fromFirst;
  }

  return null;
}

/// Preferred first, then English when the preferred category is missing.
/// Empty when [preferred] is `'None'` (subtitles stay off).
List<String> subtitleLanguageCandidates(String preferred) {
  if (preferred == 'None' || preferred.isEmpty) return const [];
  if (preferred == 'English') return const ['English'];
  return [preferred, 'English'];
}

/// Score for auto-pick ordering — higher is preferred.
int externalSubtitleEntryRank(Map<String, dynamic> s) {
  var score = 100;
  if (s['translated'] == true) score -= 50;
  if ((s['display'] ?? '').toString().toLowerCase().contains('hearing')) {
    score -= 5;
  }
  return score;
}

Map<String, dynamic>? pickExternalSubtitleForLanguage(
  String preferredLang,
  List<Map<String, dynamic>> subs,
) {
  final ranked = rankedExternalSubtitleCandidatesForLanguage(preferredLang, subs);
  return ranked.isEmpty ? null : ranked.first;
}

/// All external subs matching [preferredLang], best-first for auto-pick retries.
List<Map<String, dynamic>> rankedExternalSubtitleCandidatesForLanguage(
  String preferredLang,
  List<Map<String, dynamic>> subs,
) {
  if (preferredLang == 'None') return const [];
  final scored = <({Map<String, dynamic> sub, int score})>[];
  for (final s in subs) {
    final url = (s['url'] ?? '').toString();
    if (url.isEmpty) continue;
    final lang = s['language']?.toString();
    final disp = s['display']?.toString();
    if (!matchesPreferredLanguage(
      preferredLang,
      language: lang,
      title: disp,
    )) {
      continue;
    }
    scored.add((sub: s, score: externalSubtitleEntryRank(s)));
  }
  scored.sort((a, b) => b.score.compareTo(a.score));
  return [for (final e in scored) e.sub];
}

/// Preferred language (+ English fallback), deduped, optionally [preferUrlFirst].
List<Map<String, dynamic>> externalSubtitleAutoCandidates({
  required String preferredLang,
  required List<Map<String, dynamic>> subs,
  String? preferUrlFirst,
}) {
  final out = <Map<String, dynamic>>[];
  final seen = <String>{};

  void add(Map<String, dynamic> s) {
    final url = (s['url'] ?? '').toString();
    if (url.isEmpty || !seen.add(url)) return;
    out.add(s);
  }

  if (preferUrlFirst != null) {
    for (final s in subs) {
      if (s['url']?.toString() == preferUrlFirst) {
        add(s);
        break;
      }
    }
  }

  for (final lang in subtitleLanguageCandidates(preferredLang)) {
    for (final s in rankedExternalSubtitleCandidatesForLanguage(lang, subs)) {
      add(s);
    }
  }
  return out;
}

/// Preferred language, then English fallback when that category is absent.
Map<String, dynamic>? pickExternalSubtitleWithFallback(
  String preferredLang,
  List<Map<String, dynamic>> subs,
) {
  for (final lang in subtitleLanguageCandidates(preferredLang)) {
    final pick = pickExternalSubtitleForLanguage(lang, subs);
    if (pick != null) return pick;
  }
  return null;
}

/// Anime / Asian Drama hub — TMDB season/episode often disagree with hub
/// numbering; scraped subs (SubtitleCat, Wyzie, …) frequently mismatch.
bool restrictScrapedSubtitleAutoPick({
  String? mediaType,
  String? engineCategory,
}) =>
    mediaType == 'asian_drama' ||
    mediaType == 'anime' ||
    engineCategory == 'drama' ||
    engineCategory == 'anime';

Set<String> providerExternalSubtitleUrls(
  Iterable<Map<String, dynamic>> subs,
) {
  return {
    for (final s in subs)
      if ((s['url'] ?? '').toString().trim().isNotEmpty)
        (s['url'] ?? '').toString(),
  };
}

/// Auto-pick pool — hub playback trusts provider sideloads + TMDB-backed
/// Wyzie/Levrx; skips SubtitleCat/Mysubs (loose title search → wrong film).
List<Map<String, dynamic>> externalSubtitlesForAutoPick({
  required List<Map<String, dynamic>> all,
  required Set<String> providerUrls,
  required bool restrictScraped,
}) {
  if (!restrictScraped) return all;
  final out = <Map<String, dynamic>>[];
  for (final s in all) {
    final url = (s['url'] ?? '').toString();
    if (url.isEmpty) continue;
    if (providerUrls.contains(url)) {
      out.add(s);
      continue;
    }
    final source = (s['sourceName'] ?? '').toString().toLowerCase();
    if (source == 'wyzie' || source == 'levrx') {
      out.add(s);
    }
  }
  return out;
}

/// In-stream track matching [preferredLang], then English — no random mux fallback.
SubtitleTrack? pickEmbeddedSubtitleWithFallback({
  required String preferredLang,
  required List<SubtitleTrack> tracks,
}) {
  final real =
      tracks.where((t) => !isSideloadedExternalSubtitleTrack(t)).toList();
  for (final lang in subtitleLanguageCandidates(preferredLang)) {
    for (final t in real) {
      if (matchesPreferredLanguage(
        lang,
        language: t.language,
        title: t.title,
      )) {
        return t;
      }
    }
  }
  return null;
}

/// Codec/title hints we want to *avoid* because the bundled mpv build on
/// many platforms can't render them (Atmos / TrueHD / DTS:X).
const List<String> _kUnsupportedAudioHints = [
  'atmos', 'truehd', 'true-hd', 'true hd', 'mlp', 'dts:x', 'dts-x', 'dtsx',
  'dts-hd ma', 'dts hd ma', 'dts-hd', 'dtshd',
];

bool _isUnsupportedAudio(AudioTrack t) {
  final s =
      '${t.codec ?? ''} ${t.title ?? ''} ${t.channels ?? ''}'.toLowerCase();
  for (final h in _kUnsupportedAudioHints) {
    if (s.contains(h)) return true;
  }
  // 7.1 channel layouts are problematic with most audio sinks → prefer 5.1.
  if (s.contains('7.1')) return true;
  return false;
}

int _scoreAudioTrack(
  AudioTrack t, {
  required String preferredAudioLang,
  required bool avoidUnsupportedAudio,
}) {
  var score = 0;
  final isMatch = preferredAudioLang != 'None' &&
      _matchesLanguage(preferredAudioLang, t.language, t.title);
  if (isMatch) score += 1000;

  final unsupported = _isUnsupportedAudio(t);
  if (avoidUnsupportedAudio && unsupported) {
    score -= 500;
  }
  final s = '${t.codec ?? ''} ${t.title ?? ''}'.toLowerCase();
  if (s.contains('ac3') ||
      s.contains('eac3') ||
      s.contains('aac') ||
      s.contains('opus') ||
      s.contains('mp3')) {
    score += 10;
  }
  return score;
}

int audioTrackOrderKey(AudioTrack t) => int.tryParse(t.id) ?? 9999;

/// Concrete mux tracks in demux order — lowest [aid] first (mpv default).
List<AudioTrack> concreteAudioTracks(Iterable<AudioTrack> tracks) {
  final real =
      tracks.where((t) => t.id != 'no' && t.id != 'auto').toList(growable: false);
  if (real.length <= 1) return real;
  final sorted = List<AudioTrack>.from(real);
  sorted.sort((a, b) {
    if (a.isDefault == true && b.isDefault != true) return -1;
    if (b.isDefault == true && a.isDefault != true) return 1;
    return audioTrackOrderKey(a).compareTo(audioTrackOrderKey(b));
  });
  return sorted;
}

bool _prefersAudioTrack(AudioTrack candidate, AudioTrack incumbent) {
  if (candidate.isDefault == true && incumbent.isDefault != true) return true;
  if (incumbent.isDefault == true && candidate.isDefault != true) return false;
  return audioTrackOrderKey(candidate) < audioTrackOrderKey(incumbent);
}

/// Picks the best concrete audio track for auto mode - never returns `auto`/`no`.
AudioTrack? pickBestAudioTrack({
  required List<AudioTrack> audioTracks,
  required String preferredAudioLang,
  required bool avoidUnsupportedAudio,
}) {
  final realAudio = concreteAudioTracks(audioTracks);
  if (realAudio.isEmpty) return null;

  var bestScore = -1;
  AudioTrack? best;
  for (final t in realAudio) {
    final score = _scoreAudioTrack(
      t,
      preferredAudioLang: preferredAudioLang,
      avoidUnsupportedAudio: avoidUnsupportedAudio,
    );
    if (best == null || score > bestScore) {
      bestScore = score;
      best = t;
    } else if (score == bestScore && _prefersAudioTrack(t, best)) {
      best = t;
    }
  }
  return best;
}

class AutoSelectResult {
  final AudioTrack? audio;
  final SubtitleTrack? subtitle;
  final bool clearSubtitle; // true when user wants subtitles off

  const AutoSelectResult({this.audio, this.subtitle, this.clearSubtitle = false});

  bool get hasAny => audio != null || subtitle != null || clearSubtitle;
}

/// Given the player's current track lists and user prefs, returns the
/// recommended audio + subtitle track to switch to.
AutoSelectResult computeAutoSelect({
  required List<AudioTrack> audioTracks,
  required List<SubtitleTrack> subtitleTracks,
  required AudioTrack currentAudio,
  required SubtitleTrack currentSubtitle,
  required String preferredAudioLang,    // display name, "None" disables
  required String preferredSubtitleLang, // display name
  required bool avoidUnsupportedAudio,
}) {
  AudioTrack? audioPick;
  SubtitleTrack? subtitlePick;
  bool clearSub = false;

  // ── AUDIO ───────────────────────────────────────────────────────────────
  final best = pickBestAudioTrack(
    audioTracks: audioTracks,
    preferredAudioLang: preferredAudioLang,
    avoidUnsupportedAudio: avoidUnsupportedAudio,
  );

  if (best != null && best.id != currentAudio.id) {
    final bool currentMatches = preferredAudioLang != 'None' &&
        _matchesLanguage(
            preferredAudioLang, currentAudio.language, currentAudio.title);
    final bool currentIsBad =
        avoidUnsupportedAudio && _isUnsupportedAudio(currentAudio);
    final bool bestMatches = preferredAudioLang != 'None' &&
        _matchesLanguage(preferredAudioLang, best.language, best.title);
    final bool bestIsBad =
        avoidUnsupportedAudio && _isUnsupportedAudio(best);

    final shouldSwitch =
        (preferredAudioLang != 'None' && bestMatches && !currentMatches) ||
            (currentIsBad && !bestIsBad);
    if (shouldSwitch) {
      audioPick = best;
      debugPrint(
          '[TrackAutoSelect] audio → ${best.title ?? best.language ?? best.id} '
          '(codec=${best.codec}, channels=${best.channels})');
    }
  }

  // ── SUBTITLES ───────────────────────────────────────────────────────────
  if (preferredSubtitleLang == 'None') {
    // User explicitly wants subs off → only force off if one is currently on
    // and tracks list shows we even have subs.
    if (currentSubtitle.id != 'no' && currentSubtitle.id.isNotEmpty) {
      clearSub = true;
    }
  } else {
    final realSub =
        subtitleTracks.where((t) => t.id != 'no' && t.id != 'auto').toList();
    SubtitleTrack? subBest;
    for (final t in realSub) {
      if (_matchesLanguage(preferredSubtitleLang, t.language, t.title)) {
        subBest = t;
        break;
      }
    }
    if (subBest != null && subBest.id != currentSubtitle.id) {
      subtitlePick = subBest;
      debugPrint(
          '[TrackAutoSelect] subtitle → ${subBest.title ?? subBest.language ?? subBest.id}');
    }
  }

  return AutoSelectResult(
    audio: audioPick,
    subtitle: subtitlePick,
    clearSubtitle: clearSub,
  );
}

/// True for temp `file://` subs mpv keeps across remounts — not muxed in-stream.
bool isSideloadedExternalSubtitleTrack(SubtitleTrack track) {
  final id = track.id;
  if (id == 'no' || id == 'auto') return false;
  if (id.startsWith('http')) return true;
  final probe = '$id ${track.title ?? ''}'.toLowerCase();
  if (probe.contains('forja_sub_') || probe.contains('forja_iptv_sub_')) {
    return true;
  }
  return id.startsWith('file://') || id.startsWith('/');
}

/// True when [bytes] look like SRT/VTT/ASS — not HTML/CDN error pages saved as `.srt`.
bool isPlausibleSubtitleBytes(List<int> bytes) {
  if (bytes.isEmpty) return false;
  final sample = utf8.decode(bytes, allowMalformed: true).trimLeft();
  if (sample.isEmpty) return false;
  final lower = sample.toLowerCase();
  if (lower.startsWith('<!doctype') ||
      lower.startsWith('<html') ||
      lower.contains('<html')) {
    return false;
  }
  if (lower.contains('cannot connect to db') ||
      lower.contains('network connection to database') ||
      (lower.startsWith('sorry.') && lower.contains('problem with network'))) {
    return false;
  }
  if (sample.startsWith('WEBVTT')) return true;
  if (sample.contains('[Script Info]') || sample.contains('[V4+ Styles]')) {
    return true;
  }
  if (sample.contains('-->') &&
      RegExp(r'\d{1,2}:\d{2}([,\.]\d+)?').hasMatch(sample)) {
    return true;
  }
  return false;
}

String? externalSubtitleCacheFilePath(String fileUri) {
  final trimmed = fileUri.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.startsWith('file://')) {
    try {
      return Uri.parse(trimmed).toFilePath();
    } catch (_) {
      return null;
    }
  }
  if (trimmed.startsWith('/')) return trimmed;
  return null;
}

/// Validates a cached `file://` subtitle still exists and is readable sub content.
Future<bool> externalSubtitleCacheFileValid(String fileUri) async {
  final path = externalSubtitleCacheFilePath(fileUri);
  if (path == null) return false;
  final file = File(path);
  if (!await file.exists()) return false;
  try {
    final bytes = await file.readAsBytes();
    return isPlausibleSubtitleBytes(bytes);
  } catch (_) {
    return false;
  }
}

Future<void> deleteExternalSubtitleCacheFile(String fileUri) async {
  final path = externalSubtitleCacheFilePath(fileUri);
  if (path == null) return;
  try {
    await File(path).delete();
  } catch (_) {}
}
