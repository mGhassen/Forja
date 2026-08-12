import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rust/rust.dart';

/// Auto server/source/audio/subtitle pins for built-in players (TV + mobile).
@immutable
class PlayerAutoSettings {
  const PlayerAutoSettings({
    required this.autoServer,
    required this.autoSource,
    required this.autoAudio,
    required this.autoSubtitle,
  });

  final bool autoServer;
  final bool autoSource;
  final bool autoAudio;
  final bool autoSubtitle;

  bool get providerPinned => !autoServer;
  bool get sourcePinned => !autoSource;
  bool get audioPinned => !autoAudio;
  bool get subtitlePinned => !autoSubtitle;
}

final playerAutoSettingsProvider =
    FutureProvider.autoDispose<PlayerAutoSettings>((ref) async {
  final s = SettingsService();
  final autoServer = await s.getPlayerAutoServer();
  final autoSource = await s.getPlayerAutoSource();
  final autoAudio = await s.getPlayerAutoAudio();
  final autoSubtitle = await s.getPlayerAutoSubtitle();
  // Hydrate live notifiers used by skip/next episode and the Episodes panel.
  await s.getAutoNextEpisode();
  await s.getAutoSkipIntro();
  await s.getContentWarnings();
  await s.getAutoPipOnDesktopSwitch();
  await s.getPlayInBackground();
  return PlayerAutoSettings(
    autoServer: autoServer,
    autoSource: autoSource,
    autoAudio: autoAudio,
    autoSubtitle: autoSubtitle,
  );
});

@immutable
class PlayerSubtitlePrefs {
  const PlayerSubtitlePrefs({
    required this.size,
    required this.colorArgb,
    required this.bgOpacity,
    required this.bold,
    required this.bottomPadding,
    required this.font,
  });

  final double size;
  final int colorArgb;
  final double bgOpacity;
  final bool bold;
  final double bottomPadding;
  final String font;
}

/// Keyed by `isDesktop` - desktop and mobile default subtitle size differ
/// ([SettingsService.getSubSize]) when the user has never set one.
final playerSubtitlePrefsProvider = FutureProvider.autoDispose
    .family<PlayerSubtitlePrefs, bool>((ref, isDesktop) async {
  final s = SettingsService();
  return PlayerSubtitlePrefs(
    size: await s.getSubSize(isDesktop: isDesktop),
    colorArgb: await s.getSubColor(),
    bgOpacity: await s.getSubBgOpacity(),
    bold: await s.getSubBold(),
    bottomPadding: await s.getSubBottomPadding(),
    font: await s.getSubFont(),
  );
});
