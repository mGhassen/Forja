/// Opaque shell density / profile metrics (RFC-106 platform layer).
///
/// Product chrome stays in the host. This is device density only.
library;

/// Compact vs expanded shell density — not a product tab list.
enum ShellDensity {
  compact,
  medium,
  expanded,
  tv,
}

/// Breakpoint-ish widths for density (logical px).
abstract final class ShellBreakpoints {
  ShellBreakpoints._();

  static const double compactMax = 600;
  static const double mediumMax = 1024;

  static ShellDensity densityForWidth(double width, {bool forceTv = false}) {
    if (forceTv) return ShellDensity.tv;
    if (width < compactMax) return ShellDensity.compact;
    if (width < mediumMax) return ShellDensity.medium;
    return ShellDensity.expanded;
  }
}
