import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = ForjaFlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    flutterViewController.configureNavigationChannel()
    registerExternalPlayerChannel(flutterViewController)
    if let appDelegate = NSApp.delegate as? AppDelegate {
      appDelegate.configureShellChannel(with: flutterViewController)
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

/// Trackpad "Swipe between pages" → Flutter `forja/navigation` / `trackpadBack`.
///
/// AppKit delivers swipe gestures to the **view under the pointer** via
/// `swipe(with:)`, not a window-level event monitor. Two-finger "scroll left
/// or right" page navigation is often plain `scrollWheel` (FlutterView eats
/// those), so we also watch scroll events at the left edge.
final class ForjaFlutterViewController: FlutterViewController {
  private var navigationChannel: FlutterMethodChannel?
  private var scrollMonitor: Any?
  private var swipeMonitor: Any?

  private var scrollNavDx: CGFloat = 0
  private var scrollNavDy: CGFloat = 0
  private var scrollNavFromLeftEdge = false
  private var scrollNavActive = false

  deinit {
    if let scrollMonitor {
      NSEvent.removeMonitor(scrollMonitor)
    }
    if let swipeMonitor {
      NSEvent.removeMonitor(swipeMonitor)
    }
  }

  func configureNavigationChannel() {
    navigationChannel = FlutterMethodChannel(
      name: "forja/navigation",
      binaryMessenger: engine.binaryMessenger
    )
    installScrollNavigationMonitor()
    installSwipeNavigationMonitor()
  }

  private func notifyTrackpadBack() {
    navigationChannel?.invokeMethod("trackpadBack", arguments: nil)
  }

  /// Three-finger / "Swipe with two or three fingers" preference.
  /// Apple: deltaX **-1** = swipe-right (back), **+1** = swipe-left (forward).
  override func swipe(with event: NSEvent) {
    if event.deltaX < 0 {
      notifyTrackpadBack()
      return
    }
  }

  private func installSwipeNavigationMonitor() {
    swipeMonitor = NSEvent.addLocalMonitorForEvents(matching: .swipe) {
      [weak self] event in
      if event.deltaX < 0 {
        self?.notifyTrackpadBack()
      }
      return event
    }
  }

  /// Two-finger horizontal page swipe when Settings uses scroll-between-pages.
  /// Only from the left edge so poster-row flicks do not navigate back.
  private func installScrollNavigationMonitor() {
    scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) {
      [weak self] event in
      self?.handleScrollNavigation(event)
      return event
    }
  }

  private func handleScrollNavigation(_ event: NSEvent) {
    guard event.hasPreciseScrollingDeltas else { return }

    let phase = event.phase
    if phase.contains(.began) {
      scrollNavActive = true
      scrollNavDx = 0
      scrollNavDy = 0
      // Left strip of the window (nav rail / back chevron band).
      scrollNavFromLeftEdge = event.locationInWindow.x < 96
    }

    guard scrollNavActive, scrollNavFromLeftEdge else { return }

    // Natural scroll: fingers right → negative scrollingDeltaX (Safari back).
    scrollNavDx += event.scrollingDeltaX
    scrollNavDy += event.scrollingDeltaY

    if phase.contains(.ended) || phase.contains(.cancelled) {
      scrollNavActive = false
      let horizontal = abs(scrollNavDx) > abs(scrollNavDy) * 1.5
      if horizontal && scrollNavDx < -80 {
        notifyTrackpadBack()
      }
      scrollNavDx = 0
      scrollNavDy = 0
      scrollNavFromLeftEdge = false
    }
  }
}

private func registerExternalPlayerChannel(_ controller: FlutterViewController) {
  let channel = FlutterMethodChannel(
    name: "forja.macos/external_player",
    binaryMessenger: controller.engine.binaryMessenger
  )
  channel.setMethodCallHandler { call, result in
    guard call.method == "launchUrl" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard
      let args = call.arguments as? [String: Any],
      let appPath = args["appPath"] as? String,
      let urlString = args["url"] as? String,
      let streamURL = URL(string: urlString)
    else {
      result(
        FlutterError(
          code: "bad_args",
          message: "Missing or invalid appPath/url",
          details: nil
        )
      )
      return
    }

    guard FileManager.default.fileExists(atPath: appPath) else {
      result(
        FlutterError(
          code: "app_missing",
          message: "Application not found at \(appPath)",
          details: nil
        )
      )
      return
    }

    var components = URLComponents()
    components.scheme = "iina"
    components.host = "weblink"
    components.queryItems = [
      URLQueryItem(name: "url", value: streamURL.absoluteString)
    ]
    guard let iinaURL = components.url else {
      result(
        FlutterError(
          code: "bad_iina_url",
          message: "Could not build IINA URL scheme",
          details: nil
        )
      )
      return
    }

    if NSWorkspace.shared.open(iinaURL) {
      result(true)
    } else {
      result(
        FlutterError(
          code: "launch_failed",
          message: "IINA URL scheme launch returned false",
          details: nil
        )
      )
    }
  }
}
