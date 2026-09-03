import 'package:forja/shared/engine/models.dart';
import 'package:forja/shared/engine/plugin_install_coordinator.dart';
import 'package:forja/shared/engine/plugin_registry.dart';
import 'package:forja/shared/engine/remote_pack_intent_store.dart';

/// Per-device pack lifecycle — never written to cloud.
enum PackDeviceState {
  notOnDevice,
  onProfileLean,
  deferred,
  downloading,
  installed,
  pendingPurge,
  updateAvailable,
  failed,
}

class PackDeviceSnapshot {
  const PackDeviceSnapshot({
    required this.state,
    required this.manifestUrl,
    this.pack,
  });

  final PackDeviceState state;
  final String manifestUrl;
  final EnginePack? pack;

  String get settingsLabel => switch (state) {
        PackDeviceState.onProfileLean => 'Pending download',
        PackDeviceState.deferred => 'Install later',
        PackDeviceState.downloading => 'Downloading',
        PackDeviceState.pendingPurge => 'Removed from profile',
        PackDeviceState.updateAvailable => 'Update available',
        PackDeviceState.failed => 'Install failed',
        PackDeviceState.installed => 'Installed',
        PackDeviceState.notOnDevice => '',
      };
}

Future<PackDeviceSnapshot> resolvePackDeviceState({
  required String manifestUrl,
  EnginePack? localPack,
  EnginePackUpdateInfo? update,
}) async {
  final url = manifestUrl.trim();
  if (PluginInstallCoordinator.instance.isInstallingUrl(url)) {
    return PackDeviceSnapshot(
      state: PackDeviceState.downloading,
      manifestUrl: url,
      pack: localPack,
    );
  }
  if (await PendingRemotePurgeStore.contains(url)) {
    return PackDeviceSnapshot(
      state: PackDeviceState.pendingPurge,
      manifestUrl: url,
      pack: localPack,
    );
  }
  if (localPack == null) {
    return PackDeviceSnapshot(
      state: PackDeviceState.notOnDevice,
      manifestUrl: url,
    );
  }
  final needsDisk =
      await PluginRegistry.instance.packNeedsDiskInstall(localPack);
  if (needsDisk || localPack.plugins.isEmpty) {
    if (await DeferredRemoteInstallStore.contains(url)) {
      return PackDeviceSnapshot(
        state: PackDeviceState.deferred,
        manifestUrl: url,
        pack: localPack,
      );
    }
    final failed = PluginRegistry.officialInstallError.value != null;
    return PackDeviceSnapshot(
      state: failed ? PackDeviceState.failed : PackDeviceState.onProfileLean,
      manifestUrl: url,
      pack: localPack,
    );
  }
  if (update != null) {
    return PackDeviceSnapshot(
      state: PackDeviceState.updateAvailable,
      manifestUrl: url,
      pack: localPack,
    );
  }
  return PackDeviceSnapshot(
    state: PackDeviceState.installed,
    manifestUrl: url,
    pack: localPack,
  );
}
