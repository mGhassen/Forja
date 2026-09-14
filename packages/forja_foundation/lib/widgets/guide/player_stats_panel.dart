import 'package:flutter/material.dart';
import 'package:forja_foundation/tokens/forja_shell_colors.dart';
import 'package:google_fonts/google_fonts.dart';

/// Session snapshot for stream stats paint.
class PlayerStatsSnapshot {
  const PlayerStatsSnapshot({
    required this.playing,
    required this.buffering,
    required this.sourceLabel,
    required this.retryAttempt,
    required this.volume,
    this.buffered,
    this.position,
  });

  final bool playing;
  final bool buffering;
  final String sourceLabel;
  final int retryAttempt;
  final double volume;
  final Duration? buffered;
  final Duration? position;
}

class PlayerStatRow {
  const PlayerStatRow(this.label, this.value);
  final String label;
  final String value;
}

/// Paint-only stats list. Host probes engines and builds [rows].
class PlayerStatsList extends StatelessWidget {
  const PlayerStatsList({super.key, required this.rows});

  final List<PlayerStatRow> rows;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      itemCount: rows.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        color: Colors.white.withValues(alpha: 0.08),
      ),
      itemBuilder: (context, i) {
        final row = rows[i];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 110,
                child: Text(
                  row.label,
                  style: GoogleFonts.plusJakartaSans(
                    color: ForjaShellColors.cinematic.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  row.value,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Presentational entry for stream stats.
///
/// Host owns MediaKit / Exo probing and popup chrome — pass [rows] or wrap
/// [PlayerStatsList] in the host popup.
abstract final class PlayerStatsPanel {
  PlayerStatsPanel._();

  static Widget list(List<PlayerStatRow> rows) => PlayerStatsList(rows: rows);
}
