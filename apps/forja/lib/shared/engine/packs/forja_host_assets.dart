/// Host Material fallback when a pack nav icon is missing or fails to load.
///
/// Hub glyphs live in packs (`icons/nav.png`). Host does not ship nav bitmaps.
library;

import 'package:flutter/material.dart';

abstract final class ForjaHostAssets {
  /// Material glyph when pack icon is missing or fails to load.
  static const IconData defaultNavIcon = Icons.grid_view_rounded;
}
