import 'package:forja/shared/engine/portals/m3u/m3u_models.dart';
import 'package:forja/shared/engine/portals/models.dart';
import 'package:forja_foundation/widgets/guide/channel_guide.dart';

export 'package:forja_foundation/widgets/guide/channel_guide.dart';

/// Host accessors for portal payloads on foundation [GuideChannel].
extension GuideChannelHost on GuideChannel {
  IptvStream? get xtreamStream =>
      payload is IptvStream ? payload as IptvStream : null;
}

extension ChannelGuideHost on ChannelGuide {
  VerifiedPortal? get xtreamPortal =>
      portal is VerifiedPortal ? portal as VerifiedPortal : null;
}

/// Host factories for portal-backed [ChannelGuide] snapshots.
abstract final class ChannelGuides {
  ChannelGuides._();

  static ChannelGuide fromXtreamLive({
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

    final groups = <GuideGroup>[];
    for (final c in categories) {
      if (c.id.isEmpty) continue;
      if (groupIds.contains(c.id)) {
        groups.add(GuideGroup(
          id: c.id,
          name: c.name.isEmpty ? 'Uncategorized' : c.name,
        ));
      }
    }
    for (final id in groupIds) {
      if (categories.any((c) => c.id == id)) continue;
      groups.add(GuideGroup(
        id: id,
        name: catNameById[id]?.isNotEmpty == true
            ? catNameById[id]!
            : 'Uncategorized',
      ));
    }

    final guideChannels = liveStreams
        .map(
          (s) => GuideChannel(
            id: s.streamId,
            name: s.name,
            logoUrl: s.icon.isEmpty ? null : s.icon,
            groupId: s.categoryId,
            payload: s,
          ),
        )
        .toList(growable: false);

    return ChannelGuide(
      groups: groups,
      channels: guideChannels,
      initialChannelId: initialStream.streamId,
      initialGroupId: initialStream.categoryId,
      portal: portal,
      streamHealth: streamHealth,
    );
  }

  static ChannelGuide fromM3uPlaylist(
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
          (g) => GuideGroup(
            id: g,
            name: g.isEmpty ? 'Uncategorized' : g,
          ),
        )
        .toList(growable: false);

    final guideChannels = channels
        .map(
          (c) => GuideChannel(
            id: c.url,
            name: c.name,
            logoUrl: c.logo.isEmpty ? null : c.logo,
            groupId: c.group.isEmpty ? '' : c.group,
            playUrl: c.url,
          ),
        )
        .toList(growable: false);

    return ChannelGuide(
      groups: groups,
      channels: guideChannels,
      initialChannelId: initialChannel.url,
      initialGroupId:
          initialChannel.group.isEmpty ? '' : initialChannel.group,
      portal: null,
    );
  }
}
