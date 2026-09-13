import 'package:forja_foundation/protocol/protocol.dart';

/// One row in a host-backed [`LayoutTypes.list`] grid.
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
