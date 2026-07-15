import 'package:flutter/foundation.dart';

final Set<VoidCallback> _seekScrubCancelCallbacks = <VoidCallback>{};

/// Seek bars register so menus can release a captured scrub pointer.
void playerChromeRegisterSeekScrubCancel(VoidCallback cb) =>
    _seekScrubCancelCallbacks.add(cb);

void playerChromeUnregisterSeekScrubCancel(VoidCallback cb) =>
    _seekScrubCancelCallbacks.remove(cb);

/// Call when a player Overlay menu/panel opens — stops the progress thumb
/// from staying magnetized to the cursor over the menu.
void playerChromeCancelSeekScrubs() {
  for (final cb in List<VoidCallback>.from(_seekScrubCancelCallbacks)) {
    cb();
  }
}
