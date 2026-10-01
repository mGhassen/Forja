import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forja_foundation/widgets/chrome/forja_scrollbar.dart';
import 'package:google_fonts/google_fonts.dart';

/// Session snapshot for the in-player stream stats panel.
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

  /// Absolute buffer-end (not "seconds ahead").
  final Duration? buffered;
  final Duration? position;
}

/// One label/value row in [PlayerStatsList].
class PlayerStatsRow {
  const PlayerStatsRow(this.label, this.value);
  final String label;
  final String value;
}

/// Scrollable key/value stats body — props only; host probes engines.
class PlayerStatsList extends StatefulWidget {
  const PlayerStatsList({super.key, required this.rows});

  final List<PlayerStatsRow> rows;

  @override
  State<PlayerStatsList> createState() => _PlayerStatsListState();
}

class _PlayerStatsListState extends State<PlayerStatsList> {
  static const _arrowScrollStep = 48.0;

  final _scroll = ScrollController();
  final _focus = FocusNode(debugLabel: 'player-stream-stats-scroll');

  @override
  void dispose() {
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (!_scroll.hasClients) return KeyEventResult.ignored;
    final down = event.logicalKey == LogicalKeyboardKey.arrowDown;
    final up = event.logicalKey == LogicalKeyboardKey.arrowUp;
    if (!down && !up) return KeyEventResult.ignored;

    final pos = _scroll.position;
    final delta = down ? _arrowScrollStep : -_arrowScrollStep;
    final next = (pos.pixels + delta).clamp(0.0, pos.maxScrollExtent);
    if (next == pos.pixels) return KeyEventResult.ignored;
    _scroll.jumpTo(next);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: Scrollbar(
        controller: _scroll,
        child: forjaSuppressAutoScrollbar(
          context: context,
          child: ListView(
          controller: _scroll,
          primary: false,
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          children: [
            for (final r in widget.rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 108,
                      child: Text(
                        r.label,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        r.value,
                        style: GoogleFonts.spaceMono(
                          color: Colors.white,
                          fontSize: 11,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        ),
      ),
    );
  }
}
