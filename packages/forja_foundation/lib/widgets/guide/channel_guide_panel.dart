import 'package:flutter/material.dart';
import 'package:forja_foundation/components/network_image.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/widgets/guide/channel_guide.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paint-only channel guide side panel.
///
/// Host owns health checks, EPG fetch, TV focus graph — inject via [epgBuilder]
/// and optional [channelTrailing].
class ChannelGuidePanel extends StatelessWidget {
  const ChannelGuidePanel({
    super.key,
    required this.guide,
    required this.selectedGroupId,
    required this.currentChannelId,
    required this.onGroupSelected,
    required this.onChannelSelected,
    required this.onClose,
    this.epgBuilder,
    this.channelTrailing,
    this.wideBreakpoint = 700,
    this.panelWidthWide = 480,
    this.panelWidthNarrow = 300,
  });

  final ChannelGuide guide;
  final String selectedGroupId;
  final String currentChannelId;
  final ValueChanged<String> onGroupSelected;
  final ValueChanged<GuideChannel> onChannelSelected;
  final VoidCallback onClose;
  final Widget Function(GuideChannel channel)? epgBuilder;
  final Widget Function(GuideChannel channel)? channelTrailing;
  final double wideBreakpoint;
  final double panelWidthWide;
  final double panelWidthNarrow;

  static const double channelRowExtent = 52;
  static const double groupRowExtent = 40;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= wideBreakpoint;
    final width = wide ? panelWidthWide : panelWidthNarrow;
    final channels = guide.channelsForGroup(selectedGroupId);
    final accent = ForjaShellColors.brandGreen;

    return Material(
      color: ForjaShellColors.cinematic.menuSurface.withValues(alpha: 0.94),
      borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Channels',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: wide ? 140 : 110,
                    child: ListView.builder(
                      itemExtent: groupRowExtent,
                      itemCount: guide.groups.length,
                      itemBuilder: (context, i) {
                        final g = guide.groups[i];
                        final selected = g.id == selectedGroupId;
                        return InkWell(
                          onTap: () => onGroupSelected(g.id),
                          child: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            color: selected
                                ? accent.withValues(alpha: 0.18)
                                : null,
                            child: Text(
                              g.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                color: selected ? Colors.white : Colors.white70,
                                fontSize: 12,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const VerticalDivider(width: 1, color: Color(0x22FFFFFF)),
                  Expanded(
                    child: ListView.builder(
                      itemExtent: channelRowExtent,
                      itemCount: channels.length,
                      itemBuilder: (context, i) {
                        final ch = channels[i];
                        final playing = ch.id == currentChannelId;
                        return InkWell(
                          onTap: () => onChannelSelected(ch),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: SizedBox(
                                    width: 36,
                                    height: 36,
                                    child: ch.logoUrl == null ||
                                            ch.logoUrl!.isEmpty
                                        ? ColoredBox(
                                            color: Colors.white
                                                .withValues(alpha: 0.06),
                                            child: const Icon(
                                              Icons.tv,
                                              size: 18,
                                              color: Colors.white38,
                                            ),
                                          )
                                        : ForjaNetworkImage(
                                            url: ch.logoUrl!,
                                            fit: BoxFit.cover,
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    ch.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: playing
                                          ? accent
                                          : Colors.white,
                                      fontSize: 13,
                                      fontWeight: playing
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (channelTrailing != null)
                                  channelTrailing!(ch),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (epgBuilder != null && channels.isNotEmpty)
              epgBuilder!(
                channels.cast<GuideChannel?>().firstWhere(
                      (c) => c!.id == currentChannelId,
                      orElse: () => channels.first,
                    )!,
              ),
          ],
        ),
      ),
    );
  }
}
