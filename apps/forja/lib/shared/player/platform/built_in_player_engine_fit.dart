import 'package:forja/l10n/app_localizations.dart';
import 'package:forja/l10n/app_localizations_en.dart';
import 'package:rust/rust.dart';

/// Where the in-player **Player** menu is shown — used when deciding whether
/// a hot-swap / boot preference should be blocked or fall back.
enum BuiltInPlayerMenuSurface {
  /// Home / Search / Anime / Drama / etc. ([PlayerScreen]).
  catalogVod,

  /// IPTV live channels ([PtPlayerScreen] with `vodPlayback: false`).
  iptvLive,

  /// IPTV Movies / Series ([PtPlayerScreen] with `vodPlayback: true`).
  iptvVod,
}

/// Why [engine] cannot play this stream (hard block).
///
/// `null` = OK to pick / boot. Non-null → toast and refuse hot-swap (or remount
/// MediaKit on boot). The in-player Player menu **always lists** every platform
/// engine — do not omit rows from this reason.
///
/// Soft cases (DASH on AVPlayer, MPEG-TS on AV/VLC) are **not** hard blocks:
/// user can pick the engine; open failure failovers to MediaKit.
///
/// [l10n] defaults to English for callers with no [BuildContext] to hand.
String? builtInPlayerEngineUnsuitableReason(
  BuiltInPlayerEngine engine, {
  required BuiltInPlayerMenuSurface surface,
  required String streamUrl,
  bool torrentLocalhost = false,
  bool needsWidevine = false,
  bool separateAudioUrl = false,
  AppLocalizations? l10n,
}) {
  final l = l10n ?? AppLocalizationsEn();
  switch (engine) {
    case BuiltInPlayerEngine.mediaKit:
      if (needsWidevine) return l.playerControlEngineDrmNeedsExo;
      return null;

    case BuiltInPlayerEngine.exoPlayer:
      if (torrentLocalhost) return l.playerControlEngineTorrentNeedsMediaKit;
      if (separateAudioUrl) {
        return l.playerControlEngineSeparateAudioNeedsMediaKit;
      }
      return null;

    case BuiltInPlayerEngine.avPlayer:
    case BuiltInPlayerEngine.vlc:
      if (torrentLocalhost) return l.playerControlEngineTorrentNeedsMediaKit;
      if (separateAudioUrl) {
        return l.playerControlEngineSeparateAudioNeedsMediaKit;
      }
      if (needsWidevine) return l.playerControlEngineDrmNeedsExo;
      return null;
  }
}

/// Which built-in row to mark selected in the Player menu.
BuiltInPlayerEngine? resolvePlayerMenuBuiltInSelection({
  required bool usingBuiltIn,
  required BuiltInPlayerEngine preferred,
  required Iterable<BuiltInPlayerEngine> visible,
}) {
  if (!usingBuiltIn) return null;
  final list = List<BuiltInPlayerEngine>.of(visible);
  if (list.contains(preferred)) return preferred;
  if (list.contains(BuiltInPlayerEngine.mediaKit)) {
    return BuiltInPlayerEngine.mediaKit;
  }
  return list.isEmpty ? null : list.first;
}
