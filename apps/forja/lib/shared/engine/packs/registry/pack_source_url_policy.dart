/// Where a pack may be fetched from.
///
/// Remote manifests, scripts, preludes, and pack-relative files must use
/// `https://`. Local checkout paths (`file://`, absolute paths) stay allowed
/// for development; the deep link only accepts them in debug builds.
abstract final class PackSourceUrlPolicy {
  static const refusedMessage =
      'This pack address must start with https://. '
      'Forja does not download packs over plain http.';

  static const localRefusedMessage =
      'This pack address points to a local file. '
      'Install packs from an https:// address.';

  /// `file://`, POSIX absolute, or Windows drive path.
  static bool isLocalPath(String url) {
    final t = url.trim();
    if (t.isEmpty) return false;
    if (t.startsWith('file://')) return true;
    if (t.startsWith('/')) return true;
    if (RegExp(r'^[A-Za-z]:\\').hasMatch(t)) return true;
    return false;
  }

  static bool isHttps(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
    return uri.scheme.toLowerCase() == 'https' && uri.host.isNotEmpty;
  }

  /// `null` when [url] may be fetched; otherwise a user-facing reason.
  static String? refuseReason(String url, {required bool allowLocal}) {
    final t = url.trim();
    if (t.isEmpty) return refusedMessage;
    if (isLocalPath(t)) return allowLocal ? null : localRefusedMessage;
    if (isHttps(t)) return null;
    return refusedMessage;
  }

  static void assertAllowed(String url, {required bool allowLocal}) {
    final reason = refuseReason(url, allowLocal: allowLocal);
    if (reason != null) throw PackSourceRefusedException(url, reason);
  }
}

/// A pack source was refused by [PackSourceUrlPolicy]. Message is user-facing.
class PackSourceRefusedException implements Exception {
  const PackSourceRefusedException(this.url, this.message);

  final String url;
  final String message;

  @override
  String toString() => message;
}
