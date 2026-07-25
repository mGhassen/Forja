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

/// Optional native backup for system swipe gestures.
///
/// Primary path is Dart [PointerPanZoom] in BackNavigationScope - Flutter
/// already converts two-finger trackpad pans. This catches AppKit
/// `swipe(with:)` when System Settings uses swipe-with-fingers (not scroll).
final class ForjaFlutterViewController: FlutterViewController {
  private var navigationChannel: FlutterMethodChannel?
  private var swipeMonitor: Any?

  deinit {
    if let swipeMonitor {
      NSEvent.removeMonitor(swipeMonitor)
    }
  }

  func configureNavigationChannel() {
    navigationChannel = FlutterMethodChannel(
      name: "forja/navigation",
      binaryMessenger: engine.binaryMessenger
    )
    swipeMonitor = NSEvent.addLocalMonitorForEvents(matching: .swipe) {
      [weak self] event in
      // Apple: deltaX -1 = swipe-right (back), +1 = swipe-left (forward).
      if event.deltaX != 0 {
        self?.navigationChannel?.invokeMethod("trackpadBack", arguments: nil)
      }
      return event
    }
  }

  override func swipe(with event: NSEvent) {
    if event.deltaX != 0 {
      navigationChannel?.invokeMethod("trackpadBack", arguments: nil)
      return
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
