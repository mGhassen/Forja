import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let messenger = flutterViewController.engine.binaryMessenger
    let navigationChannel = FlutterMethodChannel(
      name: "forja/navigation",
      binaryMessenger: messenger
    )
    _ = NSEvent.addLocalMonitorForEvents(matching: .swipe) { event in
      // Two-finger swipe left on trackpad = back (Safari / App Store convention).
      if event.deltaX < 0 {
        navigationChannel.invokeMethod("trackpadBack", arguments: nil)
      }
      return event
    }

    // Let app content extend to the window edge; traffic lights float on top.
    titlebarAppearsTransparent = true
    titleVisibility = .hidden
    styleMask.insert(.fullSizeContentView)
    backgroundColor = NSColor.black

    super.awakeFromNib()
    repositionTrafficLights()
  }

  /// Match native title-bar spacing: inset from top-left, compact cluster.
  private func repositionTrafficLights() {
    guard
      let close = standardWindowButton(.closeButton),
      let mini = standardWindowButton(.miniaturizeButton),
      let zoom = standardWindowButton(.zoomButton)
    else { return }

    let left: CGFloat = 40
    let y = close.frame.origin.y - 8
    let spacing: CGFloat = 20

    close.setFrameOrigin(NSPoint(x: left, y: y))
    mini.setFrameOrigin(NSPoint(x: left + spacing, y: y))
    zoom.setFrameOrigin(NSPoint(x: left + spacing * 2, y: y))
  }
}
