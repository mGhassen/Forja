/// Layout slot → DS artifact (RFC-106 G4).
///
/// Packs emit opaque [type] strings. Host walks layout → mounts matching
/// widget/block. No product names.
library;

import 'package:forja_foundation/protocol/layout_types.dart';

/// Const string aliases (pack type after normalize).
abstract final class LayoutArtifactId {
  LayoutArtifactId._();

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
enum LayoutArtifact {
  stack(LayoutArtifactId.stack),
  menu(LayoutArtifactId.menu),
  tabs(LayoutArtifactId.tabs),
  list(LayoutArtifactId.list),
  row(LayoutArtifactId.row),
  topBar(LayoutArtifactId.topBar),
  categoryBar(LayoutArtifactId.categoryBar),
  hero(LayoutArtifactId.hero),
  mood(LayoutArtifactId.mood),
  continueWatching(LayoutArtifactId.continueWatching),
  because(LayoutArtifactId.because),
  verticalFilters(LayoutArtifactId.verticalFilters),
  ;

  const LayoutArtifact(this.id);

  /// Stable artifact id (== pack layout type after normalize).
  final String id;
}

/// Maps pack [rawType] → [LayoutArtifact], or null if unknown.
LayoutArtifact? layoutArtifactFor(
  String rawType, [
  Map<String, dynamic>? spec,
]) {
  final type = LayoutTypes.normalize(rawType, spec);
  return switch (type) {
    LayoutTypes.stack => LayoutArtifact.stack,
    LayoutTypes.menu => LayoutArtifact.menu,
    LayoutTypes.tabs => LayoutArtifact.tabs,
    LayoutTypes.list => LayoutArtifact.list,
    LayoutTypes.row => LayoutArtifact.row,
    LayoutTypes.topBar => LayoutArtifact.topBar,
    LayoutTypes.categoryBar => LayoutArtifact.categoryBar,
    LayoutTypes.hero => LayoutArtifact.hero,
    LayoutTypes.mood => LayoutArtifact.mood,
    LayoutTypes.continueWatching => LayoutArtifact.continueWatching,
    LayoutTypes.because => LayoutArtifact.because,
    LayoutTypes.verticalFilters => LayoutArtifact.verticalFilters,
    _ => null,
  };
}

/// Maps normalized [LayoutTypes] → [LayoutArtifact] (+ docs table).
abstract final class LayoutMap {
  LayoutMap._();

  static LayoutArtifact? artifactFor(
    String rawType, [
    Map<String, dynamic>? spec,
  ]) =>
      layoutArtifactFor(rawType, spec);

  /// Human map for docs / gallery (stable keys).
  static const Map<String, String> slotToArtifactName = {
    LayoutTypes.stack: 'LayoutStack',
    LayoutTypes.menu: 'CatalogMenu',
    LayoutTypes.tabs: 'CatalogTabs',
    LayoutTypes.list: 'CatalogList',
    LayoutTypes.row: 'CatalogSection',
    LayoutTypes.topBar: 'TopBar / TopBarActions',
    LayoutTypes.categoryBar: 'CategoryBar',
    LayoutTypes.hero: 'CatalogHeroSection / CinematicHero',
    LayoutTypes.mood: 'MoodSection + MoodCircle',
    LayoutTypes.continueWatching: 'ContinueSection',
    LayoutTypes.because: 'BecauseSection',
    LayoutTypes.verticalFilters: 'VerticalMenu + LogoMenuRail',
  };
}
