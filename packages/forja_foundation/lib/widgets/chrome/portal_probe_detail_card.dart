import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:forja_foundation/widgets/chrome/portal_list_panel.dart';
import 'package:google_fonts/google_fonts.dart';

/// Desktop hover peek — status, seats, ports, timezone (RFC-075).
class PortalProbeDetailCard extends StatelessWidget {
  const PortalProbeDetailCard({
    super.key,
    required this.item,
  });

  final PortalListItem item;

  static const _cardW = 280.0;

  @override
  Widget build(BuildContext context) {
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
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: ForjaShellColors.cinematic.menuSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: ForjaShellColors.cinematic.borderSubtle,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
              if (lines.isNotEmpty) ...[
                const SizedBox(height: 10),
                for (var i = 0; i < lines.length; i++) ...[
                  if (i > 0) const SizedBox(height: 4),
                  _detailRow(lines[i].$1, lines[i].$2),
                ],
              ],
            ],
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

  Widget _detailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 68,
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
