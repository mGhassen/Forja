import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:forja/features/iptv/iptv/controller/iptv_controller.dart';
import 'package:forja/features/iptv/iptv/data/iptv_portal_share.dart';
import 'package:forja/features/iptv/iptv/data/models.dart';
import 'package:forja/features/iptv/iptv/iptv_shell_style.dart';
import 'package:forja/features/iptv/iptv/iptv_tv_focus.dart';
import 'package:forja/shell/shell_bus.dart';
import 'package:forja/shared/design/design.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';
import 'package:forja/shared/tv/shell_tv_coordinator.dart';
import 'package:forja/shared/tv/shell_tv_focus.dart';
import 'package:forja/shared/widgets/tv_browse_text_field.dart';

part 'iptv_catalog_top_bar.dart';
part 'iptv_catalog_portal_panel.dart';
part 'iptv_catalog_portal_form.dart';
part 'iptv_catalog_portal_widgets.dart';

/// Colored Live / Movies / Series shelf — same hues as the old section tiles.
class _IptvSectionShelfSpec {
  const _IptvSectionShelfSpec({
    required this.section,
    required this.label,
    required this.icon,
    required this.colors,
  });

  final IptvSection section;
  final String label;
  final IconData icon;
  final List<Color> colors;

  /// Shelf pill gradients — Live only: drop the near-black tile stop.
  List<Color> get shelfGradientColors => section == IptvSection.live
      ? const [Color(0xFFEF4444), Color(0xFF7C2D12)]
      : colors;
}

const _kSectionShelf = <_IptvSectionShelfSpec>[
  _IptvSectionShelfSpec(
    section: IptvSection.live,
    label: 'Live',
    icon: Icons.live_tv_rounded,
    colors: [Color(0xFFEF4444), Color(0xFF7C2D12)],
  ),
  _IptvSectionShelfSpec(
    section: IptvSection.vod,
    label: 'Movies',
    icon: Icons.movie_rounded,
    colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
  ),
  _IptvSectionShelfSpec(
    section: IptvSection.series,
    label: 'Series',
    icon: Icons.video_library_rounded,
    colors: [Color(0xFF1CE783), Color(0xFF13AA2E)],
  ),
];

const _kShelfTabHeight = 36.0;
const _kShelfTabRadius = 8.0;
const _kSearchCollapsed = 40.0;
const _kSearchExpanded = 260.0;
