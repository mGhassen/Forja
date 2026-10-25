import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forja/shared/engine/store/list_open_flow.dart';
import 'package:forja/shell/focus/shell_focusable_tap.dart';
import 'package:forja_foundation/widgets/catalog/letter_link_mark.dart';

/// Host asset for pack `trackerMark.icon: "simkl"` (CDN vendored).
const kSimklLogoAsset = 'assets/icon/simkl.png';

ImageProvider? trackerMarkImage(Map raw) {
  final icon = (raw['icon'] ?? '').toString().trim().toLowerCase();
  if (icon == 'simkl') return const AssetImage(kSimklLogoAsset);
  final url = (raw['imageUrl'] ?? raw['image'] ?? '').toString().trim();
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return NetworkImage(url);
  }
  final asset = (raw['asset'] ?? '').toString().trim();
  if (asset.isNotEmpty) return AssetImage(asset);
  return null;
}

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
  final image = trackerMarkImage(raw);
  if (letter.isEmpty && image == null) return null;
  final linked = raw['linked'] == true;
  final openLink = raw['openTrackerLink'] == true;
  final mark = LetterLinkMark(
    letter: letter.isEmpty ? 'S' : letter,
    linked: linked,
    size: size,
    image: image,
  );
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
    scaleOnFocus: 1,
    suppressInkHover: true,
    child: mark,
  );
}
