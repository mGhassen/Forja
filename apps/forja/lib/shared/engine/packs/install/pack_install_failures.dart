import 'package:flutter/foundation.dart';

import 'package:forja/shared/engine/packs/registry/pack_http.dart';

/// One pack install failure for the session Settings banner (not persisted).
@immutable
class PackInstallFailure {
  const PackInstallFailure({
    required this.label,
    required this.manifestUrl,
    required this.message,
  });

  final String label;
  final String manifestUrl;
  final String message;

  factory PackInstallFailure.fromError({
    required String label,
    required String manifestUrl,
    required Object error,
  }) {
    final url = manifestUrl.trim();
    return PackInstallFailure(
      label: label.trim().isNotEmpty ? label.trim() : url,
      manifestUrl: url,
      message: PackHttp.humanizeError(error, url),
    );
  }
}

/// In-memory only — last batch/single install failures for Settings → Forja Packs.
abstract final class PackInstallFailures {
  static final ValueNotifier<List<PackInstallFailure>> latest =
      ValueNotifier<List<PackInstallFailure>>(const []);

  static void report(List<PackInstallFailure> failures) {
    latest.value = List<PackInstallFailure>.unmodifiable(failures);
  }

  static void reportOne({
    required String label,
    required String manifestUrl,
    required Object error,
  }) {
    report([
      PackInstallFailure.fromError(
        label: label,
        manifestUrl: manifestUrl,
        error: error,
      ),
    ]);
  }

  static void clear() {
    if (latest.value.isEmpty) return;
    latest.value = const [];
  }
}
