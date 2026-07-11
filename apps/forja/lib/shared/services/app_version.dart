import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Release codename for the current **minor** arc only (patches inherit; no per-patch names).
/// Runway: docs/backlog/README.md#codename-runway — update when shipping minor changes.
const kReleaseCodename = 'Dabaghin';

final class AppVersion {
  AppVersion._();

  static final AppVersion instance = AppVersion._();

  Future<PackageInfo>? _loadFuture;

  Future<PackageInfo> load() =>
      _loadFuture ??= PackageInfo.fromPlatform();

  Future<String> get version async => (await load()).version;

  Future<String> label({String prefix = '', bool includeCodename = true}) async {
    final ver = await version;
    final base = prefix.isEmpty ? ver : '$prefix$ver';
    if (!includeCodename || kReleaseCodename.isEmpty) return base;
    return '$base ($kReleaseCodename)';
  }
}

class AppVersionLabel extends StatelessWidget {
  const AppVersionLabel({
    super.key,
    this.style,
    this.prefix = '',
    this.includeCodename = true,
  });

  final TextStyle? style;
  final String prefix;
  final bool includeCodename;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: AppVersion.instance.label(
        prefix: prefix,
        includeCodename: includeCodename,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        return Text(snapshot.data!, style: style);
      },
    );
  }
}
