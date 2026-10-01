/// TV focus≠activate contract (RFC-106 / forja-tv-scope).
///
/// Text fields browse-only until explicit OK/Select. Components that wrap
/// text inputs must honor this — no IME on focus land.
library;

abstract final class TvFocusPolicy {
  TvFocusPolicy._();

  /// Focus highlight only — never open keyboard / edit / submit on land.
  static const bool focusIsNotActivate = true;

  /// Activate keys: OK / Select / Enter / click — not arrow focus.
  static const String activateRule = 'explicit_select_only';
}
