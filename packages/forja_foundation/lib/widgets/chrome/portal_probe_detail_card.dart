import 'package:flutter/material.dart';
import 'package:forja_foundation/components/crossfade_swap.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/tokens/forja_shell_tokens.dart';
import 'package:forja_foundation/tokens/portal_list_tokens.dart';
import 'package:forja_foundation/widgets/chrome/shell_paint_scope.dart';
import 'package:forja_foundation/widgets/chrome/portal_list_panel.dart';
import 'package:forja_foundation/widgets/feedback/frosted_panel.dart';
import 'package:forja_foundation/widgets/guide/guide_chrome_style.dart';
import 'package:google_fonts/google_fonts.dart';

/// Desktop hover peek — status, seats, ports, timezone (RFC-075).
///
/// Liquid glass via [ForjaFrostedPanel] (blur + light tint), same family as
/// Sources — not solid black and not bare translucent text.
class PortalProbeDetailCard extends StatelessWidget {
  const PortalProbeDetailCard({
    super.key,
    required this.item,
  });

  final PortalListItem item;

  static const _cardW = PortalListTokens.probeCardWidth;
  static const _radius =
      BorderRadius.all(Radius.circular(PortalListTokens.probeCardRadius));

  @override
  Widget build(BuildContext context) {
    final tv = ShellPaintScope.usesTvDensityOf(context);
    final statusFontSize =
        tv ? ShellTokens.tvBodyFontSize : 12.0;
    final titleFontSize =
        tv ? ShellTokens.tvTitleFontSize : 14.0;
    final metaFontSize = tv
        ? PortalListTokens.metaFontSizeTv
        : PortalListTokens.metaFontSize;
    final detail = item.probeDetail;
    final checking = item.checking;
    final status = checking && detail == null
        ? 'Checking…'
        : (detail?.statusLabel?.trim().isNotEmpty == true
            ? detail!.statusLabel!.trim()
            : 'Not checked');
    final statusColor = detail == null
        ? Colors.white54
        : detail.alive == true
            ? ForjaShellColors.brandGreen
            : const Color(0xFFEF4444);

    final expiry = (item.expiry ?? '').trim();
    final seatsActive = (item.activeConnections ?? '').trim();
    final seatsMax = (item.maxConnections ?? '').trim();
    final platform = (item.platformLabel ?? '').trim();
    final url = (item.subtitle ?? '').trim();

    final lines = <(String, String)>[
      if (platform.isNotEmpty) ('Platform', platform),
      if (url.isNotEmpty) ('URL', _shortUrl(url)),
      if (expiry.isNotEmpty) ('Expires', expiry),
      if (seatsMax.isNotEmpty) ('Seats', '$seatsActive / $seatsMax'),
    ];
    final message = (detail?.message ?? '').trim();
    if (message.isNotEmpty) lines.add(('Message', message));
    final protocol = (detail?.protocol ?? '').trim();
    if (protocol.isNotEmpty) lines.add(('Protocol', protocol));
    final ports = (detail?.ports ?? '').trim();
    if (ports.isNotEmpty) lines.add(('Ports', ports));
    final timezone = (detail?.timezone ?? '').trim();
    if (timezone.isNotEmpty) lines.add(('Timezone', timezone));

    return IgnorePointer(
      child: SizedBox(
        width: _cardW,
        child: ForjaFrostedPanel(
          borderRadius: _radius,
          blurSigma: 28,
          border: Border.all(color: GuideChromeStyle.border),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: PortalListTokens.probeDotSize,
                      height: PortalListTokens.probeDotSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: PortalListTokens.probeGap),
                    Expanded(
                      child: CrossfadeSwap(
                        child: Text(
                          status,
                          key: ValueKey(status),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: statusColor,
                            fontSize: statusFontSize,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: PortalListTokens.probeMetaGap),
                CrossfadeSwap(
                  child: Text(
                    item.label,
                    key: ValueKey(item.label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ),
                if (lines.isNotEmpty) ...[
                  const SizedBox(height: PortalListTokens.probeSectionGap),
                  for (var i = 0; i < lines.length; i++) ...[
                    if (i > 0)
                      const SizedBox(height: PortalListTokens.probeLineGap),
                    _detailRow(lines[i].$1, lines[i].$2, metaFontSize),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _shortUrl(String raw) {
    final t = raw.trim();
    if (t.length <= 42) return t;
    return '${t.substring(0, 40)}…';
  }

  Widget _detailRow(String label, String value, double metaFontSize) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: PortalListTokens.probeLabelWidth,
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white54,
              fontSize: metaFontSize,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: CrossfadeSwap(
            child: Text(
              value,
              key: ValueKey('$label:$value'),
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: metaFontSize,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
