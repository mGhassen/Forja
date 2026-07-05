import 'dart:convert';

import 'package:rust/rust.dart';

class PortalGroup {
  const PortalGroup({
    required this.id,
    required this.name,
    this.colorArgb = 0xFF7C4DFF,
    this.portalKeys = const [],
  });

  final String id;
  final String name;
  final int colorArgb;
  final List<String> portalKeys;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': colorArgb,
        'portalKeys': portalKeys,
      };

  factory PortalGroup.fromJson(Map<String, dynamic> j) => PortalGroup(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        colorArgb: j['color'] as int? ?? 0xFF7C4DFF,
        portalKeys: (j['portalKeys'] as List?)?.cast<String>() ?? [],
      );

  PortalGroup copyWith({
    String? name,
    int? colorArgb,
    List<String>? portalKeys,
  }) =>
      PortalGroup(
        id: id,
        name: name ?? this.name,
        colorArgb: colorArgb ?? this.colorArgb,
        portalKeys: portalKeys ?? this.portalKeys,
      );
}

class PortalMeta {
  const PortalMeta({
    required this.portalKey,
    this.groupId,
    this.lastVerifiedAt,
    this.expiry,
    this.maxConnections,
    this.activeConnections,
  });

  final String portalKey;
  final String? groupId;
  final DateTime? lastVerifiedAt;
  final String? expiry;
  final String? maxConnections;
  final String? activeConnections;

  Map<String, dynamic> toJson() => {
        'portalKey': portalKey,
        'groupId': groupId,
        'lastVerifiedAt': lastVerifiedAt?.toIso8601String(),
        'expiry': expiry,
        'maxConnections': maxConnections,
        'activeConnections': activeConnections,
      };

  factory PortalMeta.fromJson(Map<String, dynamic> j) => PortalMeta(
        portalKey: j['portalKey'] as String? ?? '',
        groupId: j['groupId'] as String?,
        lastVerifiedAt: j['lastVerifiedAt'] != null
            ? DateTime.tryParse(j['lastVerifiedAt'] as String)
            : null,
        expiry: j['expiry'] as String?,
        maxConnections: j['maxConnections'] as String?,
        activeConnections: j['activeConnections'] as String?,
      );
}

class IptvSettingsRepo {
  static const _groupsKey = 'forja_iptv_groups';
  static const _metaKey = 'forja_iptv_portal_meta';

  Future<List<PortalGroup>> getGroups() async {
    if (!ForjaEngine.isReady) {
      return [const PortalGroup(id: 'default', name: 'All Portals')];
    }
    final raw = ForjaEngine.storageRead(_groupsKey);
    if (raw == null) {
      return [const PortalGroup(id: 'default', name: 'All Portals')];
    }
    if (raw is String) {
      final arr = jsonDecode(raw) as List;
      return arr
          .map((e) => PortalGroup.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => PortalGroup.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [const PortalGroup(id: 'default', name: 'All Portals')];
  }

  Future<void> saveGroups(List<PortalGroup> groups) async {
    if (!ForjaEngine.isReady) return;
    ForjaEngine.storageWriteString(
      _groupsKey,
      jsonEncode(groups.map((g) => g.toJson()).toList()),
    );
  }

  Future<Map<String, PortalMeta>> getPortalMeta() async {
    if (!ForjaEngine.isReady) return {};
    final raw = ForjaEngine.storageRead(_metaKey);
    if (raw == null) return {};
    final decoded = raw is String ? jsonDecode(raw) : raw;
    if (decoded is! Map) return {};
    return decoded.map(
      (k, v) => MapEntry(
        '$k',
        PortalMeta.fromJson(Map<String, dynamic>.from(v as Map)),
      ),
    );
  }

  Future<void> upsertPortalMeta(PortalMeta meta) async {
    if (!ForjaEngine.isReady) return;
    final all = await getPortalMeta();
    all[meta.portalKey] = meta;
    ForjaEngine.storageWriteString(
      _metaKey,
      jsonEncode(all.map((k, v) => MapEntry(k, v.toJson()))),
    );
  }
}
