import 'package:forja/features/iptv/iptv/data/models.dart';
import 'package:forja/features/iptv/iptv/m3u/m3u_models.dart';

class IptvGuideGroup {
  final String id;
  final String name;

  const IptvGuideGroup({required this.id, required this.name});
}

class IptvGuideChannel {
  final String id;
  final String name;
  final String? logoUrl;
  final String groupId;
  final String? playUrl;
  final IptvStream? xtreamStream;

  const IptvGuideChannel({
    required this.id,
    required this.name,
    required this.groupId,
    this.logoUrl,
    this.playUrl,
    this.xtreamStream,
  });
}

/// Immutable snapshot of groups + channels for in-player zapping.
class IptvChannelGuide {
  final List<IptvGuideGroup> groups;
  final List<IptvGuideChannel> channels;
  final String initialChannelId;
  final String initialGroupId;
  final VerifiedPortal? xtreamPortal;
  /// Known stream health from the browser (`streamId` → alive).
  final Map<String, bool> streamHealth;

  const IptvChannelGuide({
    required this.groups,
    required this.channels,
    required this.initialChannelId,
    required this.initialGroupId,
    this.xtreamPortal,
    this.streamHealth = const {},
  });

  List<IptvGuideChannel> channelsForGroup(String groupId) =>
      channels.where((c) => c.groupId == groupId).toList();

  IptvGuideGroup? groupById(String groupId) {
    for (final g in groups) {
      if (g.id == groupId) return g;
    }
    return null;
  }

  List<IptvGuideChannel> searchChannels(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return channels.where((ch) {
      if (ch.name.toLowerCase().contains(q)) return true;
      final groupName = groupById(ch.groupId)?.name.toLowerCase() ?? '';
      return groupName.contains(q);
    }).toList(growable: false);
  }

  factory IptvChannelGuide.fromXtreamLive({
    required VerifiedPortal portal,
    required List<IptvCategory> categories,
    required List<IptvStream> streams,
    required IptvStream initialStream,
    Map<String, bool> streamHealth = const {},
  }) {
    final liveStreams =
        streams.where((s) => s.kind == 'live').toList(growable: false);
    final catNameById = {
      for (final c in categories) c.id: c.name,
    };

    final groupIds = <String>{};
    for (final s in liveStreams) {
      groupIds.add(s.categoryId);
    }

    final groups = <IptvGuideGroup>[];
    for (final c in categories) {
      if (c.id.isEmpty) continue;
      if (groupIds.contains(c.id)) {
        groups.add(IptvGuideGroup(
          id: c.id,
          name: c.name.isEmpty ? 'Uncategorized' : c.name,
        ));
      }
    }
    for (final id in groupIds) {
      if (categories.any((c) => c.id == id)) continue;
      groups.add(IptvGuideGroup(
        id: id,
        name: catNameById[id]?.isNotEmpty == true
            ? catNameById[id]!
            : 'Uncategorized',
      ));
    }

    final guideChannels = liveStreams
        .map(
          (s) => IptvGuideChannel(
            id: s.streamId,
            name: s.name,
            logoUrl: s.icon.isEmpty ? null : s.icon,
            groupId: s.categoryId,
            xtreamStream: s,
          ),
        )
        .toList(growable: false);

    return IptvChannelGuide(
      groups: groups,
      channels: guideChannels,
      initialChannelId: initialStream.streamId,
      initialGroupId: initialStream.categoryId,
      xtreamPortal: portal,
      streamHealth: streamHealth,
    );
  }

  factory IptvChannelGuide.fromM3uPlaylist(
    List<M3uChannel> channels, {
    required M3uChannel initialChannel,
  }) {
    final groupOrder = <String>[];
    final seenGroups = <String>{};
    for (final c in channels) {
      final g = c.group.isEmpty ? '' : c.group;
      if (seenGroups.add(g)) groupOrder.add(g);
    }

    final groups = groupOrder
        .map(
          (g) => IptvGuideGroup(
            id: g,
            name: g.isEmpty ? 'Uncategorized' : g,
          ),
        )
        .toList(growable: false);

    final guideChannels = channels
        .map(
          (c) => IptvGuideChannel(
            id: c.url,
            name: c.name,
            logoUrl: c.logo.isEmpty ? null : c.logo,
            groupId: c.group.isEmpty ? '' : c.group,
            playUrl: c.url,
          ),
        )
        .toList(growable: false);

    return IptvChannelGuide(
      groups: groups,
      channels: guideChannels,
      initialChannelId: initialChannel.url,
      initialGroupId:
          initialChannel.group.isEmpty ? '' : initialChannel.group,
      xtreamPortal: null,
    );
  }
}
