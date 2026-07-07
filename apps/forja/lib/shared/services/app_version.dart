import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

final class AppVersion {
  AppVersion._();

  static final AppVersion instance = AppVersion._();

  Future<PackageInfo>? _loadFuture;

  Future<PackageInfo> load() =>
      _loadFuture ??= PackageInfo.fromPlatform();

  Future<String> get version async => (await load()).version;

  Future<String> label({String prefix = 'v'}) async =>
      '$prefix${await version}';
}

class AppVersionLabel extends StatelessWidget {
  const AppVersionLabel({
    super.key,
    this.style,
    this.prefix = 'v',
  });

  final TextStyle? style;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: AppVersion.instance.label(prefix: prefix),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        return Text(snapshot.data!, style: style);
      },
    );
  }
}
