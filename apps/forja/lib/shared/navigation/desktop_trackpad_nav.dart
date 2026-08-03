import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Pan distance (logical px) at which the desktop swipe-back indicator commits.
const double kDesktopSwipeBackCommitPx = 160;

/// Sentinel for [MetaData] regions that must never arm swipe-back
/// (Sources panel, catalog rows, chip strips, cards).
const Object kDesktopSwipeBackIgnoreMeta = Object();

/// Marks [child] so a trackpad swipe over it cannot commit page Back.
///
/// Prefer wrapping panels / horizontal strips rather than relying on
/// viewport overflow (chip rows often have `maxScrollExtent == 0`).
class DesktopSwipeBackIgnore extends StatelessWidget {
  const DesktopSwipeBackIgnore({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MetaData(
      metaData: kDesktopSwipeBackIgnoreMeta,
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }
}

/// True when [globalPosition] is over content that owns the pan
/// (horizontal strips, ignored panels, any scroll viewport).
bool desktopSwipeBackBlocked(
  Offset globalPosition, {
  required int viewId,
}) {
  final result = HitTestResult();
  GestureBinding.instance.hitTestInView(result, globalPosition, viewId);
  for (final entry in result.path) {
    final target = entry.target;
    if (target is RenderMetaData &&
        identical(target.metaData, kDesktopSwipeBackIgnoreMeta)) {
      return true;
    }
    // Chip rows / catalogs often fit without overflow — still block.
    if (target is RenderViewportBase &&
        axisDirectionToAxis(target.axisDirection) == Axis.horizontal) {
      return true;
    }
  }
  return false;
}

/// @nodoc Kept for call sites / tests that used the old name.
bool desktopHorizontalScrollableUnder(
  Offset globalPosition, {
  required int viewId,
}) =>
    desktopSwipeBackBlocked(globalPosition, viewId: viewId);
