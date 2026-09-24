import 'package:flutter/widgets.dart';
import 'package:forja/features/settings/shell/catalog.dart';
import 'package:forja/shell/bus/shell_bus.dart';

/// Opens Settings → Downloads (Active / Completed offline library).
void openSettingsDownloads([BuildContext? context]) {
  ShellBus.openSettings(
    categoryId: SettingsCategoryId.downloads,
    enterDetail: true,
  );
}
