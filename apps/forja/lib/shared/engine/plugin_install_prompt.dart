/// Pending plugin pack install from web / `forja://install` deep link.
class PluginInstallPrompt {
  const PluginInstallPrompt({
    required this.manifestUrl,
    this.displayName,
  });

  final String manifestUrl;
  final String? displayName;
}

/// One row in the batch install picker (profile / pending disk install).
class PluginInstallCandidate {
  const PluginInstallCandidate({
    required this.manifestUrl,
    this.displayName,
    this.alreadyInstalled = false,
  });

  final String manifestUrl;
  final String? displayName;
  final bool alreadyInstalled;
}

/// Multiple plugin packs — user picks which to download/install on device.
class PluginBatchInstallPrompt {
  const PluginBatchInstallPrompt({required this.candidates});

  final List<PluginInstallCandidate> candidates;
}
