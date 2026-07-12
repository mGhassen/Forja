import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    registerExternalPlayerChannel(flutterViewController)

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

    let appURL = URL(fileURLWithPath: appPath, isDirectory: true)
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

    let config = NSWorkspace.OpenConfiguration()
    config.activates = true
    NSWorkspace.shared.open(
      [streamURL],
      withApplicationAt: appURL,
      configuration: config
    ) { _, error in
      if let error = error {
        result(
          FlutterError(
            code: "launch_failed",
            message: error.localizedDescription,
            details: nil
          )
        )
      } else {
        result(true)
      }
    }
  }
}
