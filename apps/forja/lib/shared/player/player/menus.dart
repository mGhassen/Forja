import 'package:flutter/material.dart';
import 'package:forja/shared/design/design.dart';

void showSpeedMenu(BuildContext context, double currentSpeed, ValueChanged<double> onSpeedChanged) {
  showModalBottomSheet(
    context: context,
    useRootNavigator: false,
    backgroundColor: ForjaShellColors.cinematic.menuSurface,
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      side: BorderSide(color: ForjaShellColors.cinematic.borderSubtle),
    ),
    builder: (context) {
      final speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
      final cinematic = ForjaShellColors.cinematic;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: cinematic.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                'Playback Speed',
                style: TextStyle(
                  color: cinematic.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: speeds.map((speed) {
                  final isSelected = speed == currentSpeed;
                  return InkWell(
                    onTap: () {
                      onSpeedChanged(speed);
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? ForjaShellColors.chipSelectedBg
                            : Colors.white.withValues(alpha: 0.07),
                        border: Border.all(
                          color: isSelected
                              ? ForjaShellColors.chipSelectedBorder
                              : cinematic.borderSubtle,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${speed}x',
                        style: TextStyle(
                          color: isSelected
                              ? cinematic.textPrimary
                              : cinematic.textSecondary,
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      );
    },
  );
}

void showTracksMenu(BuildContext context, String title, List<String> tracks, int selectedIndex, ValueChanged<int> onTrackSelected) {
  showModalBottomSheet(
    context: context,
    useRootNavigator: false,
    backgroundColor: ForjaShellColors.cinematic.menuSurface,
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      side: BorderSide(color: ForjaShellColors.cinematic.borderSubtle),
    ),
    builder: (context) {
      final cinematic = ForjaShellColors.cinematic;
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
                  color: cinematic.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(
                title,
                style: TextStyle(
                  color: cinematic.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Divider(color: cinematic.borderSubtle, height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: tracks.length,
                itemBuilder: (context, index) {
                  final isSelected = index == selectedIndex;
                  return ListTile(
                    leading: Icon(
                      Icons.subtitles_outlined,
                      color: isSelected
                          ? cinematic.textPrimary
                          : cinematic.textSecondary,
                    ),
                    title: Text(
                      tracks[index],
                      style: TextStyle(
                        color: cinematic.textPrimary,
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_rounded, color: ForjaShellColors.chipSelectedIcon)
                        : null,
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
