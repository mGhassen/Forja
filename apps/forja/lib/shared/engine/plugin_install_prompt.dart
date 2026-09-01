/// Pending plugin pack install from web / `forja://install` deep link.
class PluginInstallPrompt {
  const PluginInstallPrompt({
    required this.manifestUrl,
    this.displayName,
  });

  final String manifestUrl;
  final String? displayName;
}
