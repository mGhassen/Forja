import 'package:forja_foundation/tokens/forja_shell_tokens.dart';

/// Layout tokens for the in-app update dialog.
abstract final class UpdateDialogTokens {
  static const double buttonHeightDesktop = ShellTokens.shellButtonHeight;
  static const double buttonHeightTv = 54;
  static const double buttonRadius = ShellTokens.shellButtonRadius;
  static const Duration pageTransition = Duration(milliseconds: 480);
  static const Duration chromeAnimation = Duration(milliseconds: 120);
  static const double changelogRailWidthTv = 96;
  static const double changelogRailWidthDesktop = 118;
  static const double notesGapTv = 12;
  static const double notesGapDesktop = 18;
  static const double sectionMetaGapTv = 4;
  static const double sectionMetaGapDesktop = 12;
  static const double downloadGapTv = 20;
  static const double downloadGapDesktop = 32;
  static const double bulletGap = 6;
  static const double bulletFontSize = 11;
}
