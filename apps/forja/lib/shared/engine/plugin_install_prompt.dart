/// How the install/uninstall overlay was requested.
enum PluginInstallSource { deepLink, remoteProfile, settings }

/// Install vs uninstall handshake.
enum PluginPackPromptKind { install, uninstall }

/// Pending plugin pack install/uninstall from web / `forja://install` / cloud sync.
class PluginInstallPrompt {
  const PluginInstallPrompt({
    required this.manifestUrl,
    this.displayName,
    this.source = PluginInstallSource.deepLink,
    this.kind = PluginPackPromptKind.install,
  });

  final String manifestUrl;
  final String? displayName;
  final PluginInstallSource source;
  final PluginPackPromptKind kind;
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
