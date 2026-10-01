import 'package:forja_foundation/protocol/protocol.dart';

/// Opaque list/details row — meta + pack row map. No host field rematerialization.
class KitListEntry {
  const KitListEntry({
    required this.meta,
    required this.legacyRow,
    required this.kind,
    this.pluginId,
    this.listStatus,
  });

  final MetaItem meta;
  final Map<String, dynamic> legacyRow;
  final String kind;
  final String? pluginId;
  final String? listStatus;
}
