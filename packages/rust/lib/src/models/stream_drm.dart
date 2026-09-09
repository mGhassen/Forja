/// Optional Widevine (or ClearKey) license config for a playable stream.
///
/// Providers emit this on extract rows; Android Exo applies it via
/// Media3 MediaItem.DrmConfiguration. Non-Android engines ignore DRM rows.
class StreamDrmConfig {
  const StreamDrmConfig({
    required this.scheme,
    required this.licenseUrl,
    this.licenseHeaders = const {},
  });

  /// `widevine` (default) or `clearkey`.
  final String scheme;
  final String licenseUrl;
  final Map<String, String> licenseHeaders;

  bool get isWidevine => scheme.toLowerCase() == 'widevine';

  static StreamDrmConfig? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final licenseUrl = (raw['licenseUrl'] ?? raw['license_url'] ?? '')
        .toString()
        .trim();
    if (licenseUrl.isEmpty) return null;
    final scheme = (raw['scheme'] ?? raw['type'] ?? 'widevine')
        .toString()
        .trim()
        .toLowerCase();
    if (scheme.isEmpty) return null;
    Map<String, String> headers = {};
    final rawHeaders = raw['licenseHeaders'] ?? raw['license_headers'];
    if (rawHeaders is Map) {
      headers = rawHeaders.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return StreamDrmConfig(
      scheme: scheme,
      licenseUrl: licenseUrl,
      licenseHeaders: headers,
    );
  }

  Map<String, dynamic> toJson() => {
        'scheme': scheme,
        'licenseUrl': licenseUrl,
        if (licenseHeaders.isNotEmpty) 'licenseHeaders': licenseHeaders,
      };
}
