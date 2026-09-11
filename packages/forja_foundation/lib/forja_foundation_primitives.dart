/// Leaf entry — tokens, theme, primitives, components.
library;

export 'package:forja_foundation/tokens/tokens.dart';
export 'package:forja_foundation/theme/forja_theme_extension.dart';
export 'package:forja_foundation/primitives/button.dart';
export 'package:forja_foundation/components/components.dart';
// Compat Forja* aliases: import `compat/legacy_buttons.dart` explicitly.
// Do not barrel-export them. App code uses `components/button.dart`.
