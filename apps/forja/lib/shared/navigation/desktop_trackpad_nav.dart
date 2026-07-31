import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Pan distance (logical px) at which the desktop swipe-back indicator commits.
const double kDesktopSwipeBackCommitPx = 160;

/// True when [globalPosition] is over a horizontal viewport that can scroll
/// (catalog rows, addon strips, filters, hero carousels, etc.).
///
/// Those surfaces own two-finger pans — never arm page-level swipe-back.
bool desktopHorizontalScrollableUnder(
  Offset globalPosition, {
  required int viewId,
}) {
  final result = HitTestResult();
  GestureBinding.instance.hitTestInView(result, globalPosition, viewId);
  for (final entry in result.path) {
    final target = entry.target;
    if (target is! RenderViewportBase) continue;
    if (axisDirectionToAxis(target.axisDirection) != Axis.horizontal) {
      continue;
    }
    final offset = target.offset;
    if (offset is ScrollPosition) {
      if (offset.maxScrollExtent > offset.minScrollExtent + 0.5) {
        return true;
      }
      continue;
    }
    // Horizontal viewport without a [ScrollPosition] — treat as scrollable.
    return true;
  }
  return false;
}
