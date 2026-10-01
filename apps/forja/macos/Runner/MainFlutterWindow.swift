import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  /// Frame before a Forja fill (green button / title-bar double-click).
  private var forjaPreZoomFrame: NSRect?
  /// AppKit on macOS 27 often invokes `zoom` twice per gesture; the second
  /// call must not undo the fill (that was the fill→flash→boxed bug).
  private var forjaZoomGateUntil: Date?
  /// Point size the user (or window_manager / green-button) last chose.
  /// Space and display moves must not replace it.
  private var forjaStableSize: NSSize = .zero
  private var forjaStableSizeValid = false
  /// While set, AppKit frame changes keep [forjaStableSize].
  private var forjaPinSizeUntil: Date?
  /// Outer zoom `setFrame` — animation ticks must not become the stable size.
  private var forjaApplyingZoom = false
  /// Putting the stable size back after AppKit changed it.
  private var forjaRestoringStable = false
  /// Native PiP owns the frame until chrome is restored.
  private var forjaPipActive = false
  private var forjaFullscreenTransition = false
  private var forjaSpaceObservers: [NSObjectProtocol] = []
  private var forjaWorkspaceObserver: NSObjectProtocol?

  override func awakeFromNib() {
    forjaStableSize = frame.size
    forjaStableSizeValid = true
    forjaStartSpaceSizeGuard()

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

  deinit {
    let center = NotificationCenter.default
    for token in forjaSpaceObservers {
      center.removeObserver(token)
    }
    if let forjaWorkspaceObserver {
      NSWorkspace.shared.notificationCenter.removeObserver(forjaWorkspaceObserver)
    }
  }

  /// PiP shrink/restore sets the frame on purpose. While this is true, Space
  /// moves must not snap the window back to the pre-PiP size.
  func forjaSetPipActive(_ active: Bool) {
    forjaPipActive = active
  }

  /// Fill the screen work area (or restore the pre-fill frame). Never call
  /// `super.zoom` — hidden titlebar + macOS 27 animate-then-snap.
  ///
  /// AppKit also calls `zoom` when the window changes Space or display. That
  /// is not a click on the green button — ignore it so the size stays put.
  override func zoom(_ sender: Any?) {
    let explicit =
      Self.forjaIsUserZoom(sender) || Self.forjaCalledFromWindowManager()
    if !explicit {
      // Space / display rezoom. Hold the current size against the setFrame
      // that AppKit often follows with.
      forjaArmSizePin()
      return
    }
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
    forjaStableSize = target.size
    forjaStableSizeValid = true
    forjaApplyingZoom = true
    setFrame(target, display: true, animate: true)
    forjaApplyingZoom = false

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
      && forjaSizesClose(a.size, b.size)
  }

  private static func forjaSizesClose(_ a: NSSize, _ b: NSSize) -> Bool {
    abs(a.width - b.width) < 4 && abs(a.height - b.height) < 4
  }

  /// Green button, or a title-bar double-click (window is the sender).
  private static func forjaIsUserZoom(_ sender: Any?) -> Bool {
    if sender is NSButton { return true }
    guard let event = NSApp.currentEvent else { return false }
    return event.type == .leftMouseUp && event.clickCount >= 2
  }

  /// `window_manager` maximize / setSize. AppKit Space moves do not come from there.
  /// Match the module (or `WindowManager.set…`). This method's own symbol
  /// contains "WindowManager" and must not count.
  private static func forjaCalledFromWindowManager() -> Bool {
    for symbol in Thread.callStackSymbols {
      if symbol.contains("window_manager") || symbol.contains("WindowManager.") {
        return true
      }
    }
    return false
  }

  private var forjaInsideSetFrame = false

  override func setFrame(_ frameRect: NSRect, display displayFlag: Bool) {
    if forjaInsideSetFrame {
      super.setFrame(frameRect, display: displayFlag)
      return
    }
    forjaInsideSetFrame = true
    let trusted = forjaFrameChangeIsTrusted(frameRect)
    let rect = trusted ? frameRect : forjaSizeKept(frameRect)
    super.setFrame(rect, display: displayFlag)
    forjaCommitStableSizeIfNeeded(trusted: trusted)
    forjaInsideSetFrame = false
  }

  override func setFrame(
    _ frameRect: NSRect,
    display displayFlag: Bool,
    animate animateFlag: Bool
  ) {
    if forjaInsideSetFrame {
      super.setFrame(frameRect, display: displayFlag, animate: animateFlag)
      return
    }
    if !animateFlag {
      setFrame(frameRect, display: displayFlag)
      return
    }
    forjaInsideSetFrame = true
    let trusted = forjaFrameChangeIsTrusted(frameRect)
    let rect = trusted ? frameRect : forjaSizeKept(frameRect)
    super.setFrame(rect, display: displayFlag, animate: true)
    forjaCommitStableSizeIfNeeded(trusted: trusted)
    forjaInsideSetFrame = false
  }

  private func forjaFrameChangeIsTrusted(_ proposed: NSRect) -> Bool {
    if inLiveResize || forjaApplyingZoom || forjaRestoringStable || forjaPipActive
      || forjaFullscreenTransition
    {
      return true
    }
    if styleMask.contains(.fullScreen) { return true }
    if let until = forjaZoomGateUntil, Date() < until { return true }
    if !forjaStableSizeValid { return true }
    if Self.forjaSizesClose(proposed.size, forjaStableSize) { return true }
    if Self.forjaCalledFromWindowManager() { return true }
    // Edge-tiling and other on-space resizes stick. A Space/display move does not.
    if isOnActiveSpace && !forjaSizePinArmed() { return true }
    return false
  }

  private func forjaArmSizePin() {
    let until = Date().addingTimeInterval(0.65)
    if let existing = forjaPinSizeUntil, existing > until { return }
    forjaPinSizeUntil = until
  }

  private func forjaSizePinArmed() -> Bool {
    guard let until = forjaPinSizeUntil else { return false }
    return Date() < until
  }

  /// Keep the last user size. Clamp to the current work area when that display
  /// is smaller — do not write the clamp back into the stable size.
  private func forjaSizeKept(_ proposed: NSRect) -> NSRect {
    let vis = (screen ?? NSScreen.main)?.visibleFrame
    var size = forjaStableSize
    if let vis {
      size.width = min(size.width, vis.width)
      size.height = min(size.height, vis.height)
    }
    return NSRect(origin: proposed.origin, size: size)
  }

  private func forjaCommitStableSizeIfNeeded(trusted: Bool) {
    guard trusted, !forjaPipActive, !forjaRestoringStable, !inLiveResize else { return }
    if styleMask.contains(.fullScreen) || forjaFullscreenTransition { return }
    if let until = forjaZoomGateUntil, Date() < until, !forjaApplyingZoom { return }
    let userChoseSize =
      forjaApplyingZoom
      || (isOnActiveSpace && !forjaSizePinArmed())
      || Self.forjaCalledFromWindowManager()
    guard userChoseSize else { return }
    forjaStableSize = frame.size
    forjaStableSizeValid = true
  }

  private func forjaStartSpaceSizeGuard() {
    let center = NotificationCenter.default
    let names: [Notification.Name] = [
      NSWindow.didChangeScreenNotification,
      NSWindow.didChangeOcclusionStateNotification,
      NSWindow.willEnterFullScreenNotification,
      NSWindow.didEnterFullScreenNotification,
      NSWindow.willExitFullScreenNotification,
      NSWindow.didExitFullScreenNotification,
      NSWindow.didEndLiveResizeNotification,
    ]
    for name in names {
      let token = center.addObserver(forName: name, object: self, queue: .main) {
        [weak self] note in
        self?.forjaHandleWindowNote(note)
      }
      forjaSpaceObservers.append(token)
    }
    forjaWorkspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.activeSpaceDidChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.forjaArmSizePin()
      self?.forjaScheduleStableRestore()
    }
  }

  private func forjaHandleWindowNote(_ note: Notification) {
    switch note.name {
    case NSWindow.willEnterFullScreenNotification,
      NSWindow.willExitFullScreenNotification:
      forjaFullscreenTransition = true
    case NSWindow.didEnterFullScreenNotification,
      NSWindow.didExitFullScreenNotification:
      forjaFullscreenTransition = false
      if note.name == NSWindow.didExitFullScreenNotification {
        forjaScheduleStableRestore()
      }
    case NSWindow.didEndLiveResizeNotification:
      if !forjaPipActive && !styleMask.contains(.fullScreen) {
        forjaStableSize = frame.size
        forjaStableSizeValid = true
      }
    case NSWindow.didChangeScreenNotification,
      NSWindow.didChangeOcclusionStateNotification:
      forjaArmSizePin()
      forjaScheduleStableRestore()
    default:
      break
    }
  }

  private func forjaScheduleStableRestore() {
    DispatchQueue.main.async { [weak self] in
      self?.forjaRestoreStableSizeIfNeeded()
    }
  }

  private func forjaRestoreStableSizeIfNeeded() {
    guard forjaStableSizeValid, !forjaPipActive, !inLiveResize,
      !forjaFullscreenTransition, !styleMask.contains(.fullScreen)
    else { return }
    if let until = forjaZoomGateUntil, Date() < until { return }
    let kept = forjaSizeKept(frame)
    if Self.forjaSizesClose(frame.size, kept.size) { return }
    forjaRestoringStable = true
    setFrame(kept, display: true, animate: false)
    forjaRestoringStable = false
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
