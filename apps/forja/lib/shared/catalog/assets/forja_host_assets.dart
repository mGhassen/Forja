/// Host-owned nav assets + Material fallback.
///
/// Packs ship their own glyphs (`icons/nav.png`). Host core tabs that keep a
/// bitmap (IPTV) use [flutterNavIptv] on [NavDestination.iconAsset].
library;

import 'package:flutter/material.dart';

abstract final class ForjaHostAssets {
  /// Host IPTV rail icon (Flutter asset — not a pack file).
  static const flutterNavIptv = 'assets/images/nav/iptv.png';

  /// Material glyph when pack icon is missing or fails to load.
  static const IconData defaultNavIcon = Icons.grid_view_rounded;
}
