/// Kit layout slot → DS artifact (RFC-106 G4).
///
/// Packs emit opaque [type] strings. Host walks layout → mounts matching
/// widget/block. No product names.
library;

import 'package:forja_foundation/kit/kit_types.dart';

/// Const string aliases (pack type after normalize).
abstract final class KitLayoutArtifactId {
  KitLayoutArtifactId._();

  static const stack = 'kit.stack';
  static const menu = 'kit.menu';
  static const tabs = 'kit.tabs';
  static const list = 'kit.list';
  static const row = 'kit.row';
  static const topBar = 'kit.topBar';
  static const categoryBar = 'kit.categoryBar';
  static const hero = 'hero';
  static const mood = 'mood';
  static const continueWatching = 'continue';
  static const because = 'because';
  static const verticalFilters = 'vertical_filters';
}

/// Artifact the shell/kit builder should mount for a normalized type.
enum KitLayoutArtifact {
  stack(KitLayoutArtifactId.stack),
  menu(KitLayoutArtifactId.menu),
  tabs(KitLayoutArtifactId.tabs),
  list(KitLayoutArtifactId.list),
  row(KitLayoutArtifactId.row),
  topBar(KitLayoutArtifactId.topBar),
  categoryBar(KitLayoutArtifactId.categoryBar),
  hero(KitLayoutArtifactId.hero),
  mood(KitLayoutArtifactId.mood),
  continueWatching(KitLayoutArtifactId.continueWatching),
  because(KitLayoutArtifactId.because),
  verticalFilters(KitLayoutArtifactId.verticalFilters),
  ;

  const KitLayoutArtifact(this.id);

  /// Stable artifact id (== pack layout type after normalize).
  final String id;
}

/// Maps pack [rawType] → [KitLayoutArtifact], or null if unknown.
KitLayoutArtifact? kitLayoutArtifactFor(
  String rawType, [
  Map<String, dynamic>? spec,
]) {
  final type = KitTypes.normalize(rawType, spec);
  return switch (type) {
    KitTypes.stack => KitLayoutArtifact.stack,
    KitTypes.menu => KitLayoutArtifact.menu,
    KitTypes.tabs => KitLayoutArtifact.tabs,
    KitTypes.list => KitLayoutArtifact.list,
    KitTypes.row => KitLayoutArtifact.row,
    KitTypes.topBar => KitLayoutArtifact.topBar,
    KitTypes.categoryBar => KitLayoutArtifact.categoryBar,
    KitTypes.hero => KitLayoutArtifact.hero,
    KitTypes.mood => KitLayoutArtifact.mood,
    KitTypes.continueWatching => KitLayoutArtifact.continueWatching,
    KitTypes.because => KitLayoutArtifact.because,
    KitTypes.verticalFilters => KitLayoutArtifact.verticalFilters,
    _ => null,
  };
}

/// Maps normalized [KitTypes] → [KitLayoutArtifact] (+ docs table).
abstract final class KitLayoutMap {
  KitLayoutMap._();

  static KitLayoutArtifact? artifactFor(
    String rawType, [
    Map<String, dynamic>? spec,
  ]) =>
      kitLayoutArtifactFor(rawType, spec);

  /// Human map for docs / gallery (stable keys).
  static const Map<String, String> slotToArtifactName = {
    KitTypes.stack: 'KitStack',
    KitTypes.menu: 'KitMenu',
    KitTypes.tabs: 'KitTabs',
    KitTypes.list: 'KitList',
    KitTypes.row: 'KitRow',
    KitTypes.topBar: 'TopBarSlots',
    KitTypes.categoryBar: 'KitCategoryBar',
    KitTypes.hero: 'CatalogHeroSection / CinematicHero',
    KitTypes.mood: 'MoodSection + MoodCircle',
    KitTypes.continueWatching: 'ContinueSection',
    KitTypes.because: 'BecauseSection',
    KitTypes.verticalFilters: 'VerticalMenu + LogoMenuRail',
  };
}
