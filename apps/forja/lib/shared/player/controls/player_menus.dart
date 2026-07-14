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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
      child: PlayerPopupSectionCard(
        icon: Icons.speed_rounded,
        title: 'Speed',
        subtitle: 'Playback rate',
        valueBadge: _speedBadge(currentSpeed),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _kPlaybackSpeeds.map((speed) {
            final selected = speed == currentSpeed;
            return PlayerPopupOptionChip(
              label: speed == 1.0 ? 'Normal' : '${speed}x',
              selected: selected,
              onTap: () {
                onSpeedChanged(speed);
                PlayerPopupPanel.dismiss();
              },
            );
          }).toList(),
        ),
      ),
    ),
  );
}

String _speedBadge(double speed) => speed == 1.0 ? 'Normal' : '${speed}x';

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
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: PlayerPopupTokens.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Divider(color: PlayerPopupTokens.border, height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.all(12),
                itemCount: tracks.length,
                itemBuilder: (context, index) {
                  final isSelected = index == selectedIndex;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: PlayerPopupListTile(
                      label: tracks[index],
                      selected: isSelected,
                      onTap: () {
                        onTrackSelected(index);
                        Navigator.pop(context);
                      },
                    ),
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

/// Lab-style toggle chip row used in floating Settings menus.
Widget playerPopupOnOffChips({
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  return Row(
    children: [
      Expanded(
        child: PlayerPopupOptionChip(
          label: 'On',
          selected: value,
          expanded: true,
          onTap: () => onChanged(true),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: PlayerPopupOptionChip(
          label: 'Off',
          selected: !value,
          expanded: true,
          onTap: () => onChanged(false),
        ),
      ),
    ],
  );
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
