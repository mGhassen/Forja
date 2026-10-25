import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/engine/store/list_open_flow.dart';
import 'package:forja/shell/focus/shell_focusable_tap.dart';
import 'package:forja_foundation/widgets/catalog/letter_link_mark.dart';

/// Paint pack-emitted `props.trackerMark` — host does not invent tracker product.
Widget? packTrackerMarkTrailing({
  required BuildContext context,
  required String pluginId,
  required Map<String, dynamic> props,
  Map<String, dynamic>? listItem,
  double size = 14,
}) {
  final raw = props['trackerMark'];
  if (raw is! Map) return null;
  final letter = (raw['letter'] ?? '').toString().trim();
  if (letter.isEmpty) return null;
  final linked = raw['linked'] == true;
  final openLink = raw['openTrackerLink'] == true;
  final mark = LetterLinkMark(letter: letter, linked: linked, size: size);
  if (!openLink) return mark;
  return shellFocusableTap(
    context: context,
    onTap: () {
      final row = listItem != null
          ? Map<String, dynamic>.from(listItem)
          : <String, dynamic>{...props};
      unawaited(
        openKitListItem(
          context,
          pluginId: pluginId,
          item: row,
          simklLinkMode: true,
        ),
      );
    },
    borderRadius: size / 2,
    child: mark,
  );
}
