/// Desktop: which control under the pointer should take keyboard / D-pad focus.
///
/// [FocusableControl], [ForjaInteractive], and shell nav claim here so the first
/// navigation key after a **new** hover lands on that target. Later keys do not
/// snap back while the pointer stays put.
abstract final class ShellHoverFocus {
  ShellHoverFocus._();

  static void Function()? _request;
  static bool _pending = false;

  static void claim(void Function() requestFocus) {
    _request = requestFocus;
    _pending = true;
  }

  static void release(void Function() requestFocus) {
    if (!identical(_request, requestFocus)) return;
    _request = null;
    _pending = false;
  }

  /// Focus the hovered control once per hover claim.
  ///
  /// Returns true when a request was issued.
  static bool focusOwner() {
    if (!_pending) return false;
    final request = _request;
    _pending = false;
    if (request == null) return false;
    request();
    return true;
  }
}
