/// Group row for in-player channel guide.
class GuideGroup {
  final String id;
  final String name;

  const GuideGroup({required this.id, required this.name});
}

/// Channel row for in-player channel guide.
///
/// Opaque [payload] holds host stream / portal handles — foundation never
/// imports portal models.
class GuideChannel {
  final String id;
  final String name;
  final String? logoUrl;
  final String groupId;
  final String? playUrl;
  final Object? payload;

  const GuideChannel({
    required this.id,
    required this.name,
    required this.groupId,
    this.logoUrl,
    this.playUrl,
    this.payload,
  });
}

/// Immutable snapshot of groups + channels for in-player zapping.
class ChannelGuide {
  final List<GuideGroup> groups;
  final List<GuideChannel> channels;
  final String initialChannelId;
  final String initialGroupId;

  /// Opaque host portal / session handle (optional).
  final Object? portal;

  /// Known stream health from the browser (`channelId` → alive).
  final Map<String, bool> streamHealth;

  final Map<String, List<GuideChannel>> _channelsByGroup;
  final Map<String, String> _groupIdByChannelId;

  ChannelGuide({
    required this.groups,
    required this.channels,
    required this.initialChannelId,
    required this.initialGroupId,
    this.portal,
    this.streamHealth = const {},
  })  : _channelsByGroup = _indexChannelsByGroup(channels),
        _groupIdByChannelId = {
          for (final c in channels) c.id: c.groupId,
        };

  static Map<String, List<GuideChannel>> _indexChannelsByGroup(
    List<GuideChannel> channels,
  ) {
    final map = <String, List<GuideChannel>>{};
    for (final c in channels) {
      (map[c.groupId] ??= <GuideChannel>[]).add(c);
    }
    return {
      for (final e in map.entries)
        e.key: List<GuideChannel>.unmodifiable(e.value),
    };
  }

  List<GuideChannel> channelsForGroup(String groupId) =>
      _channelsByGroup[groupId] ?? const [];

  String? groupIdForChannel(String channelId) =>
      _groupIdByChannelId[channelId];

  GuideGroup? groupById(String groupId) {
    for (final g in groups) {
      if (g.id == groupId) return g;
    }
    return null;
  }

  List<GuideChannel> searchChannels(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return channels.where((ch) {
      if (ch.name.toLowerCase().contains(q)) return true;
      final groupName = groupById(ch.groupId)?.name.toLowerCase() ?? '';
      return groupName.contains(q);
    }).toList(growable: false);
  }
}
