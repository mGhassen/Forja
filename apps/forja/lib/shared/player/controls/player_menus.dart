import 'package:flutter/material.dart';
import 'package:forja/shared/player/controls/player_popup_panel.dart';

const _kPlaybackSpeeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

void showSpeedMenu(
  BuildContext context,
  double currentSpeed,
  ValueChanged<double> onSpeedChanged, {
  BuildContext? anchorContext,
}) {
  PlayerPopupPanel.show(
    context: context,
    title: 'Playback speed',
    leadingIcon: Icons.speed_rounded,
    anchorContext: anchorContext,
    width: 300,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _kPlaybackSpeeds.map((speed) {
          final selected = speed == currentSpeed;
          return PlayerPopupOptionChip(
            label: speed == 1.0 ? 'Normal' : '${speed}x',
            selected: selected,
            expanded: true,
            onTap: () {
              onSpeedChanged(speed);
              PlayerPopupPanel.dismiss();
            },
          );
        }).toList(),
      ),
    ),
  );
}

void showTracksMenu(
  BuildContext context,
  String title,
  List<String> tracks,
  int selectedIndex,
  ValueChanged<int> onTrackSelected,
) {
  showModalBottomSheet(
    context: context,
    useRootNavigator: false,
    backgroundColor: PlayerPopupTokens.shellBg,
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(PlayerPopupTokens.shellRadius),
      ),
      side: BorderSide(color: PlayerPopupTokens.border),
    ),
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 3,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: PlayerPopupTokens.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.15,
                ),
              ),
            ),
            Divider(
              color: PlayerPopupTokens.border,
              height: 1,
              thickness: 0.5,
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                itemCount: tracks.length,
                itemBuilder: (context, index) {
                  final isSelected = index == selectedIndex;
                  return PlayerPopupListTile(
                    label: tracks[index],
                    selected: isSelected,
                    onTap: () {
                      onTrackSelected(index);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// One drill-in row in a floating Settings menu. Tapping opens a second page.
class PlayerSettingsEntry {
  const PlayerSettingsEntry({
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    required this.pageBuilder,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Current value badge shown on the root row (e.g. "AUTO", "1.5x").
  final String? value;

  /// Builds the second-page body for this parameter. Should manage its own
  /// [StatefulBuilder] so chip taps update live without closing the page.
  final WidgetBuilder pageBuilder;
}

/// Root Settings menu: a list of drill-in rows. Each opens its own page.
///
/// [buildEntries] is re-invoked on every (re)open so value badges and selected
/// states stay fresh when returning from a sub-page.
void showPlayerSettingsMenu({
  required BuildContext context,
  BuildContext? anchorContext,
  String title = 'Settings',
  required List<PlayerSettingsEntry> Function() buildEntries,
}) {
  final entries = buildEntries();
  PlayerPopupPanel.show(
    context: context,
    title: title,
    leadingIcon: Icons.tune_rounded,
    anchorContext: anchorContext,
    width: 340,
    maxHeight: 560,
    // Column (not ListView) - same as audio/quality so TV linear D-pad
    // walks every row without scrollable focus gaps.
    child: Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i != 0) const SizedBox(height: 8),
            PlayerPopupNavRow(
              icon: entries[i].icon,
              title: entries[i].title,
              subtitle: entries[i].subtitle,
              value: entries[i].value,
              onTap: () => _openPlayerSettingsPage(
                context: context,
                anchorContext: anchorContext,
                rootTitle: title,
                buildEntries: buildEntries,
                index: i,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

void _openPlayerSettingsPage({
  required BuildContext context,
  BuildContext? anchorContext,
  required String rootTitle,
  required List<PlayerSettingsEntry> Function() buildEntries,
  required int index,
}) {
  final entry = buildEntries()[index];
  PlayerPopupPanel.show(
    context: context,
    title: entry.title,
    leadingIcon: entry.icon,
    anchorContext: anchorContext,
    width: 340,
    maxHeight: 560,
    onBack: () => showPlayerSettingsMenu(
      context: context,
      anchorContext: anchorContext,
      title: rootTitle,
      buildEntries: buildEntries,
    ),
    child: Builder(
      builder: (panelContext) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
        child: entry.pageBuilder(panelContext),
      ),
    ),
  );
}

/// Equal-width chips in a left/right row (On/Off, Fit, decode).
Widget playerPopupChipRow(List<Widget> chips) {
  return Row(
    children: [
      for (var i = 0; i < chips.length; i++) ...[
        if (i != 0) const SizedBox(width: 6),
        Expanded(child: chips[i]),
      ],
    ],
  );
}

/// Lab-style toggle chip row used in floating Settings menus.
Widget playerPopupOnOffChips({
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  return playerPopupChipRow([
    PlayerPopupOptionChip(
      label: 'On',
      selected: value,
      expanded: true,
      grouped: true,
      onTap: () => onChanged(true),
    ),
    PlayerPopupOptionChip(
      label: 'Off',
      selected: !value,
      expanded: true,
      grouped: true,
      onTap: () => onChanged(false),
    ),
  ]);
}

/// Labeled On/Off chip pair for Settings section cards.
class PlayerPopupToggleRow extends StatelessWidget {
  const PlayerPopupToggleRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        playerPopupOnOffChips(value: value, onChanged: onChanged),
      ],
    );
  }
}
