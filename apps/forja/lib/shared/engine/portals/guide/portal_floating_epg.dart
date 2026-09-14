import 'package:flutter/material.dart';

import 'package:forja/shared/engine/portals/guide/channel_guides.dart';
import 'package:forja/shared/engine/portals/models.dart';
import 'package:forja_foundation/widgets/guide/guide_epg_card.dart';

export 'package:forja_foundation/widgets/guide/guide_epg_card.dart';
export 'package:forja_foundation/widgets/guide/guide_epg_programme.dart';

/// Host floating EPG — maps portal [EpgEntry] futures to foundation paint.
class PortalFloatingEpg extends StatelessWidget {
  const PortalFloatingEpg({
    super.key,
    required this.future,
    required this.maxWidth,
  });

  final Future<List<EpgEntry>> future;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return GuideFloatingEpg(
      future: future.then(
        (entries) => [
          for (final e in entries) guideEpgProgrammeFromEntry(e),
        ],
      ),
      maxWidth: maxWidth,
    );
  }
}
