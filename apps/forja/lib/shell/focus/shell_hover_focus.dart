/// Desktop: which control under the pointer should take keyboard / D-pad focus.
///
/// [FocusableControl], [ForjaInteractive], and shell nav claim here so the first
/// navigation key after pointer motion lands on the hovered target — not only
/// list tiles that happen to use [FocusableControl].
abstract final class ShellHoverFocus {
  ShellHoverFocus._();

  static void Function()? _request;

  static void claim(void Function() requestFocus) => _request = requestFocus;

  static void release(void Function() requestFocus) {
    if (identical(_request, requestFocus)) _request = null;
  }

  /// Focus the hovered control when it is not already focused.
  ///
  /// Returns true when a request was issued.
  static bool focusOwner() {
    final request = _request;
    if (request == null) return false;
    request();
    return true;
  }
}
