import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

/// Phone (touch) player chrome — landscape VOD player on the mobile profile.
///
/// Leanback and desktop keep [ShellTokens] `playerChrome*` sizes; these are
/// the touch-only values (hit targets, double-tap seek, panel clearance).
abstract final class PlayerPhoneTokens {
  /// Minimum touch target for every phone player control (Material 48 dp).
  static const double touchTarget = 48;

  /// Glyph size inside a [touchTarget] action.
  static const double actionIconSize = 22;

  /// Bottom bar shows text labels next to action icons at or above this
  /// width; narrower phones keep icon-only 48 dp actions with tooltips.
  static const double labeledActionsMinWidth = 760;

  /// Label budget per labeled action ("Audio & subtitles" fits untruncated).
  static const double actionLabelMaxWidth = 140;

  /// Soft cap for the source chip in the phone transport [Flexible] slot.
  static const double sourceButtonMaxWidth = 120;

  /// Provider / catalog label inside the source chip when there is room.
  static const double sourceLabelMaxWidth = 72;

  /// Stream-picker label (shares the chip with a chevron).
  static const double sourcePickerLabelMaxWidth = 56;

  /// Horizontal pad / icon–label gap inside the phone source chip.
  static const double sourcePadH = 6;
  static const double sourceIconGap = 4;

  /// Below this allocated width the source chip is icon-only (tooltip).
  static const double sourceLabeledMinWidth = 88;

  /// Gap between bottom-bar action groups.
  static const double actionGap = 4;

  /// Seconds per double-tap step — same step as the center ±10 buttons.
  static const int seekStepSeconds = 10;

  /// A tap on the same side within this window extends the seek burst; the
  /// seek feedback stays up for the same window after the last tap.
  static const Duration seekBurstWindow = Duration(milliseconds: 1000);

  /// Ripple growth per tap.
  static const Duration seekRippleDuration = Duration(milliseconds: 450);

  /// Ripple diameter at full growth.
  static const double seekRippleDiameter = 160;

  /// Share of the screen width tinted on the tapped side.
  static const double seekSideWidthFactor = 0.4;

  /// Seek bubble glyph and label.
  static const double seekBubbleIconSize = 30;
  static const double seekBubbleFontSize = 14;

  /// Floating player panels on phone stay below the top bar (back, title,
  /// cast, PiP) so their header never sits on top of those icons. Matches
  /// `PlayerTopBar` height without the status inset.
  static const double panelTopClearance =
      ShellTokens.playerChromeTopBtnSize + 12;

  /// Settle time after forcing portrait before restoring system bars.
  static const Duration exitRotationSettle = Duration(milliseconds: 300);

  /// After the player route is gone, release the portrait lock so the app
  /// follows the system rotation setting again.
  static const Duration exitOrientationRelease = Duration(milliseconds: 900);
}
