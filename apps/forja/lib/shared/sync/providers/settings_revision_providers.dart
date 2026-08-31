import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rust/rust.dart';

/// Navbar visible tabs / default tab changed (Settings + MainScreen).
final navbarRevisionProvider = NotifierProvider<NavbarRevisionNotifier, int>(
  NavbarRevisionNotifier.new,
);

class NavbarRevisionNotifier extends Notifier<int> {
  @override
  int build() {
    final n = SettingsService.navbarChangeNotifier;
    void listener() => state = n.value;
    n.addListener(listener);
    ref.onDispose(() => n.removeListener(listener));
    return n.value;
  }
}

/// Play-source toggles (torrent / Stremio / Nuvio / engine).
final playSourceRevisionProvider =
    NotifierProvider<PlaySourceRevisionNotifier, int>(
  PlaySourceRevisionNotifier.new,
);

class PlaySourceRevisionNotifier extends Notifier<int> {
  @override
  int build() {
    final n = SettingsService.playSourceChangeNotifier;
    void listener() => state = n.value;
    n.addListener(listener);
    ref.onDispose(() => n.removeListener(listener));
    return n.value;
  }
}

/// Stremio addon list changed (Home catalogs).
final addonRevisionProvider = NotifierProvider<AddonRevisionNotifier, int>(
  AddonRevisionNotifier.new,
);

class AddonRevisionNotifier extends Notifier<int> {
  @override
  int build() {
    final n = SettingsService.addonChangeNotifier;
    void listener() => state = n.value;
    n.addListener(listener);
    ref.onDispose(() => n.removeListener(listener));
    return n.value;
  }
}

/// Combined settings signal after profile pull / local prefs import.
final settingsRevisionsProvider = Provider<({int navbar, int playSource, int addon})>((
  ref,
) {
  return (
    navbar: ref.watch(navbarRevisionProvider),
    playSource: ref.watch(playSourceRevisionProvider),
    addon: ref.watch(addonRevisionProvider),
  );
});
