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

/// One row in the batch install/uninstall picker.
class PluginInstallCandidate {
  const PluginInstallCandidate({
    required this.manifestUrl,
    this.displayName,
    this.alreadyInstalled = false,
    this.kind = PluginPackPromptKind.install,
    this.fromRemoteProfile = false,
  });

  final String manifestUrl;
  final String? displayName;
  /// Install: already on disk. Uninstall: already gone from device.
  final bool alreadyInstalled;
  final PluginPackPromptKind kind;
  /// Cloud lean diff — Not now / skipped rows defer install or purge.
  final bool fromRemoteProfile;
}

/// Multiple plugin packs — user picks which to install/uninstall on device.
class PluginBatchInstallPrompt {
  const PluginBatchInstallPrompt({required this.candidates});

  final List<PluginInstallCandidate> candidates;

  bool get hasRemoteProfile =>
      candidates.any((c) => c.fromRemoteProfile);
}
