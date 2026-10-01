import 'package:flutter/material.dart';

import 'package:forja/shared/engine/portals/guide/channel_guides.dart';
import 'package:forja/shared/engine/portals/models.dart';
import 'package:forja_foundation/widgets/guide/guide_epg_card.dart';

export 'package:forja_foundation/widgets/guide/guide_epg_card.dart';
export 'package:forja_foundation/widgets/guide/guide_epg_programme.dart';

/// Host floating EPG — maps portal [EpgEntry] futures to foundation paint.
///
/// Caches the mapped [Future] so player position ticks do not create a new
/// `.then()` chain (that would reset [FutureBuilder] → blink).
class PortalFloatingEpg extends StatefulWidget {
  const PortalFloatingEpg({
    super.key,
    required this.future,
    required this.maxWidth,
  });

  final Future<List<EpgEntry>> future;
  final double maxWidth;

  @override
  State<PortalFloatingEpg> createState() => _PortalFloatingEpgState();
}

class _PortalFloatingEpgState extends State<PortalFloatingEpg> {
  Future<List<EpgEntry>>? _src;
  late Future<List<GuideEpgProgramme>> _mapped;

  @override
  void initState() {
    super.initState();
    _bind(widget.future);
  }

  @override
  void didUpdateWidget(covariant PortalFloatingEpg oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.future, _src)) {
      _bind(widget.future);
    }
  }

  void _bind(Future<List<EpgEntry>> src) {
    _src = src;
    _mapped = src.then(
      (entries) => [
        for (final e in entries) guideEpgProgrammeFromEntry(e),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GuideFloatingEpg(
      future: _mapped,
      maxWidth: widget.maxWidth,
    );
  }
}
