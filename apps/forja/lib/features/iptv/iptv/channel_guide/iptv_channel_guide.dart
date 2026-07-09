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

  const IptvChannelGuide({
    required this.groups,
    required this.channels,
    required this.initialChannelId,
    required this.initialGroupId,
    this.xtreamPortal,
  });

  List<IptvGuideChannel> channelsForGroup(String groupId) =>
      channels.where((c) => c.groupId == groupId).toList();

  IptvGuideGroup? groupById(String groupId) {
    for (final g in groups) {
      if (g.id == groupId) return g;
    }
    return null;
  }

  factory IptvChannelGuide.fromXtreamLive({
    required VerifiedPortal portal,
    required List<IptvCategory> categories,
    required List<IptvStream> streams,
    required IptvStream initialStream,
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
    groups.sort((a, b) => a.name.compareTo(b.name));

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
    );
  }

  factory IptvChannelGuide.fromM3uPlaylist(
    List<M3uChannel> channels, {
    required M3uChannel initialChannel,
  }) {
    final groupIds = <String>{};
    for (final c in channels) {
      groupIds.add(c.group.isEmpty ? '' : c.group);
    }

    final groups = groupIds
        .map(
          (g) => IptvGuideGroup(
            id: g,
            name: g.isEmpty ? 'Uncategorized' : g,
          ),
        )
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

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
