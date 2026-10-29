/// Phone (mobile profile) chrome sizes — bottom sheets, compact search field,
/// scrollable status tabs, inline top-bar progress. TV and desktop never read
/// these; the host gates on the mobile shell profile before using them.
abstract final class MobileChromeTokens {
  // ── Bottom sheet frame ([ForjaBottomSheetPanel]) ──────────────────────────

  /// Expanded sheet height as a fraction of the space above the keyboard.
  static const double sheetExpandedFraction = 0.92;

  /// Half-open snap height (drag the handle down once).
  static const double sheetHalfFraction = 0.55;

  /// Release below this fraction of the half height closes the sheet.
  static const double sheetDismissFraction = 0.6;

  /// Downward fling velocity (px/s) that steps the sheet down / closes it.
  static const double sheetFlingVelocity = 700;

  static const double sheetTopRadius = 18;
  static const double sheetHandleWidth = 40;
  static const double sheetHandleHeight = 4;
  static const double sheetHandleTopGap = 8;
  static const double sheetHandleBottomGap = 4;
  static const double sheetHeaderPadH = 16;
  static const double sheetHeaderPadBottom = 4;
  static const double sheetTitleFontSize = 16;
  static const double sheetScrimAlpha = 0.54;
  static const Duration sheetSnapDuration = Duration(milliseconds: 240);

  /// Horizontal inset of Sources content inside the sheet.
  static const double sourcesSheetContentPadH = 14;

  // ── Categories sheet ──────────────────────────────────────────────────────

  static const double categoriesSheetChipGap = 8;
  static const double categoriesSheetPadH = 16;
  static const double categoriesSheetPadBottom = 16;

  /// Categories sheet never grows past this fraction of the screen height.
  static const double categoriesSheetMaxFraction = 0.7;

  // ── Top-bar progress (catalog scrape) ─────────────────────────────────────

  static const double topBarProgressBarHeight = 2;
  static const double topBarProgressGap = 4;
  static const double topBarProgressLabelGap = 8;
  static const double topBarProgressFontSize = 11;
  static const double topBarProgressLabelMaxWidth = 180;

  // ── Status tabs (My List Plan / Watching / …) ─────────────────────────────

  /// Per-tab horizontal padding when the strip scrolls with natural widths.
  static const double statusTabScrollPadH = 14;

  // ── Search ────────────────────────────────────────────────────────────────

  static const double searchQueryFontSize = 20;
  static const double searchQueryCursorHeight = 24;

  // ── Settings ──────────────────────────────────────────────────────────────

  /// Phones stay single-pane in landscape; a tablet (shortest side at least
  /// this) keeps the split sidebar.
  static const double settingsSplitMinShortestSide = 600;
}
