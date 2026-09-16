import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  /// Frame before a Forja fill (green button / title-bar double-click).
  private var forjaPreZoomFrame: NSRect?
  /// AppKit on macOS 27 often invokes `zoom` twice per gesture; the second
  /// call must not undo the fill (that was the fill→flash→boxed bug).
  private var forjaZoomGateUntil: Date?

  override func awakeFromNib() {
    let flutterViewController = ForjaFlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    flutterViewController.configureNavigationChannel()
    registerExternalPlayerChannel(flutterViewController)
    registerDesktopSpaceChannel(flutterViewController)
    registerDesktopPipChannel(flutterViewController, window: self)
    registerForjaAvPlayer(flutterViewController)
    registerForjaVlc(flutterViewController)
    if let appDelegate = NSApp.delegate as? AppDelegate {
      appDelegate.configureShellChannel(with: flutterViewController)
    }

    // Let app content extend to the window edge; traffic lights float on top.
    titlebarAppearsTransparent = true
    titleVisibility = .hidden
    styleMask.insert(.fullSizeContentView)
    backgroundColor = NSColor.black

    // Drop leaked PiP aspect / max caps so fill is not constrained.
    resizeIncrements = NSSize(width: 1.0, height: 1.0)
    minSize = NSSize(width: 640, height: 480)
    maxSize = NSSize(
      width: CGFloat.greatestFiniteMagnitude,
      height: CGFloat.greatestFiniteMagnitude
    )

    super.awakeFromNib()
    repositionTrafficLights()
  }

  /// Fill the screen work area (or restore the pre-fill frame). Never call
  /// `super.zoom` — hidden titlebar + macOS 27 animate-then-snap.
  override func zoom(_ sender: Any?) {
    if let until = forjaZoomGateUntil, Date() < until {
      return
    }

    guard let screen = screen ?? NSScreen.main else { return }
    let target: NSRect
    let restoring: Bool
    if Self.forjaFramesMatch(frame, screen.visibleFrame) {
      guard let saved = forjaPreZoomFrame else { return }
      forjaPreZoomFrame = nil
      target = saved
      restoring = true
    } else {
      forjaPreZoomFrame = frame
      target = screen.visibleFrame
      restoring = false
    }

    let duration = animationResizeTime(target)
    // Gate covers the whole animation so AppKit’s second zoom can’t undo mid-flight.
    forjaZoomGateUntil = Date().addingTimeInterval(max(0.45, duration + 0.12))
    setFrame(target, display: true, animate: true)

    if restoring { return }
    // After settle, re-assert fill if Tahoe reverted once (no animate — already there).
    let pinned = target
    DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.05) { [weak self] in
      guard let self else { return }
      if !Self.forjaFramesMatch(self.frame, pinned) {
        self.setFrame(pinned, display: true, animate: false)
      }
    }
  }

  override func animationResizeTime(_ newFrame: NSRect) -> TimeInterval {
    // Native zoom feel — short enough to stay snappy, long enough to read as fluid.
    0.25
  }

  private static func forjaFramesMatch(_ a: NSRect, _ b: NSRect) -> Bool {
    abs(a.origin.x - b.origin.x) < 2
      && abs(a.origin.y - b.origin.y) < 2
      && abs(a.size.width - b.size.width) < 4
      && abs(a.size.height - b.size.height) < 4
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

/// Navigation method channel (kept for Dart). Trackpad Back is progressive
/// PointerPanZoom in BackNavigationScope — AppKit swipe must not instant-pop
/// (it stole horizontal scroll on catalog/addon strips).
final class ForjaFlutterViewController: FlutterViewController {
  private var navigationChannel: FlutterMethodChannel?

  func configureNavigationChannel() {
    navigationChannel = FlutterMethodChannel(
      name: "forja/navigation",
      binaryMessenger: engine.binaryMessenger
    )
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
