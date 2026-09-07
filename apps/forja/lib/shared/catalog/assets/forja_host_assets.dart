/// Material fallback when a hub `nav.icon` is missing or fails to load.
///
/// Packs ship their own glyphs (`icons/nav.png`). Host core tabs use
/// [IconData] on [NavDestination] — never Flutter `assets/images/nav`.
library;

import 'package:flutter/material.dart';

abstract final class ForjaHostAssets {
  /// Material glyph when pack icon is missing or fails to load.
  static const IconData defaultNavIcon = Icons.grid_view_rounded;
}
