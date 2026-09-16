import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  /// Frame before a Forja fill (green button / title-bar double-click).
  /// AppKit `zoom` + hidden titlebar snaps back on macOS 27 — we fill
  /// `visibleFrame` ourselves and toggle from this snapshot.
  private var forjaPreZoomFrame: NSRect?

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

  /// Fill the screen work area (or restore the pre-fill frame). Avoids the
  /// macOS 27 hidden-titlebar zoom animate-then-snap-back.
  override func zoom(_ sender: Any?) {
    guard let screen = screen ?? NSScreen.main else {
      super.zoom(sender)
      return
    }
    let target = screen.visibleFrame
    if Self.forjaFramesMatch(frame, target) {
      if let saved = forjaPreZoomFrame {
        forjaPreZoomFrame = nil
        setFrame(saved, display: true, animate: false)
      }
      // Already filled with no snapshot (e.g. boot maximize) — stay put.
      return
    }
    forjaPreZoomFrame = frame
    setFrame(target, display: true, animate: false)
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
