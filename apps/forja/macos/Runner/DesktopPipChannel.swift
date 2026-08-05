import Cocoa
import FlutterMacOS

/// Compact PiP chrome for the main Flutter window: floating level, rounded
/// clip, shadow, Space/fullscreen join, and AX opt-out so Magnet / Rectangle
/// do not steal the drag. Free positioning — no corner snap.
final class DesktopPipController: NSObject {
  private weak var window: NSWindow?
  private var pipEnabled = false
  private var savedLevel: NSWindow.Level = .normal
  private var savedCollection: NSWindow.CollectionBehavior = []
  private var savedStyleMask: NSWindow.StyleMask = []
  private var savedOpaque = true
  private var savedHasShadow = true
  private var savedBackground: NSColor = .black
  private var savedMovableByBackground = false
  /// Saved level/collection already captured by [prepareForSpaceLeave].
  private var spaceLeavePrepared = false
  /// Dart gates this — only when Auto PiP is armed. Otherwise Space swipes
  /// must not leave the window floating / on all Spaces forever.
  private var spaceLeavePrepAllowed = false

  init(window: NSWindow) {
    self.window = window
    super.init()
    // Recover leaked Space-leave prep (floating + all Spaces with no PiP).
    if window.level == .floating {
      window.level = .normal
    }
    var behavior = window.collectionBehavior
    if behavior.contains(.canJoinAllSpaces) {
      behavior.remove(.canJoinAllSpaces)
      behavior.remove(.fullScreenAuxiliary)
      window.collectionBehavior = behavior
    }
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "setEnabled":
      let enabled = (call.arguments as? [String: Any])?["enabled"] as? Bool ?? false
      setPipEnabled(enabled)
      result(nil)
    case "setSpaceLeavePrepAllowed":
      let allowed =
        (call.arguments as? [String: Any])?["allowed"] as? Bool ?? false
      setSpaceLeavePrepAllowed(allowed)
      result(nil)
    case "cancelSpaceLeavePrep":
      cancelSpaceLeavePrep()
      result(nil)
    case "enterPip":
      let args = call.arguments as? [String: Any] ?? [:]
      let width = (args["width"] as? Double) ?? 360
      let height = (args["height"] as? Double) ?? 203
      result(enterPipAtomic(width: width, height: height))
    case "dockBottomRight":
      dockBottomRight()
      result(nil)
    case "visibleFrame":
      result(visibleFramePayload())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func setSpaceLeavePrepAllowed(_ allowed: Bool) {
    spaceLeavePrepAllowed = allowed
    if !allowed {
      cancelSpaceLeavePrep()
    }
  }

  /// Undo floating / all-Spaces prep when Auto PiP did not actually enter.
  func cancelSpaceLeavePrep() {
    guard let window, spaceLeavePrepared, !pipEnabled else {
      if !pipEnabled {
        spaceLeavePrepared = false
      }
      return
    }
    window.level = savedLevel
    window.collectionBehavior = savedCollection
    spaceLeavePrepared = false
  }

  /// One-shot PiP enter. Returns saved frame so Dart can restore on leave.
  private func enterPipAtomic(width: Double, height: Double) -> [String: Double] {
    guard let window else {
      return [:]
    }
    let frame = window.frame
    let saved: [String: Double] = [
      "x": frame.origin.x,
      "y": frame.origin.y,
      "width": frame.size.width,
      "height": frame.size.height,
    ]

    if window.styleMask.contains(.fullScreen) {
      window.toggleFullScreen(nil)
    }

    if !pipEnabled {
      if !spaceLeavePrepared {
        savedLevel = window.level
        savedCollection = window.collectionBehavior
      }
      savedStyleMask = window.styleMask
      savedOpaque = window.isOpaque
      savedHasShadow = window.hasShadow
      savedBackground = window.backgroundColor ?? .black
      savedMovableByBackground = window.isMovableByWindowBackground
      pipEnabled = true
      spaceLeavePrepared = false
    }
    applyPipChrome()

    let work = visibleFrame()
    let pad: CGFloat = 12
    let size = NSSize(width: width, height: height)
    let origin = NSPoint(
      x: work.maxX - size.width - pad,
      y: work.minY + pad
    )
    window.setFrame(NSRect(origin: origin, size: size), display: true, animate: false)
    window.orderFrontRegardless()
    return saved
  }

  private func setPipEnabled(_ enabled: Bool) {
    guard let window else { return }
    if enabled {
      if !pipEnabled {
        if !spaceLeavePrepared {
          savedLevel = window.level
          savedCollection = window.collectionBehavior
        }
        savedStyleMask = window.styleMask
        savedOpaque = window.isOpaque
        savedHasShadow = window.hasShadow
        savedBackground = window.backgroundColor ?? .black
        savedMovableByBackground = window.isMovableByWindowBackground
        pipEnabled = true
        spaceLeavePrepared = false
      }
      applyPipChrome()
    } else if pipEnabled {
      pipEnabled = false
      spaceLeavePrepared = false
      restoreChrome()
    } else {
      // Leave without PiP — still clear a leaked Space-leave prep.
      cancelSpaceLeavePrep()
    }
  }

  /// Join all Spaces + floating so a Space swipe does not occlude/pause.
  /// No-op unless Dart armed Auto PiP — otherwise the window sticks on top.
  func prepareForSpaceLeave() {
    guard let window, !pipEnabled, spaceLeavePrepAllowed else { return }
    if !spaceLeavePrepared {
      savedLevel = window.level
      savedCollection = window.collectionBehavior
      spaceLeavePrepared = true
    }
    var behavior = savedCollection
    behavior.insert(.canJoinAllSpaces)
    behavior.insert(.fullScreenAuxiliary)
    window.collectionBehavior = behavior
    window.level = .floating
    window.orderFrontRegardless()
  }

  private func applyPipChrome() {
    guard let window else { return }

    window.styleMask = [.borderless, .resizable, .fullSizeContentView]
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = true
    window.level = .floating
    window.collectionBehavior = [
      .canJoinAllSpaces,
      .fullScreenAuxiliary,
      .transient,
      .ignoresCycle,
    ]
    window.isMovableByWindowBackground = true
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.standardWindowButton(.closeButton)?.isHidden = true
    window.standardWindowButton(.miniaturizeButton)?.isHidden = true
    window.standardWindowButton(.zoomButton)?.isHidden = true

    if let content = window.contentView {
      content.wantsLayer = true
      content.layer?.cornerRadius = 12
      content.layer?.masksToBounds = true
    }

    // Hide from Magnet / Rectangle / Hammerspoon window managers.
    window.setAccessibilityElement(false)
    window.setAccessibilityRole(.none)
  }

  private func restoreChrome() {
    guard let window else { return }
    window.level = savedLevel
    window.collectionBehavior = savedCollection
    window.styleMask = savedStyleMask
    window.isOpaque = savedOpaque
    window.hasShadow = savedHasShadow
    window.backgroundColor = savedBackground
    window.isMovableByWindowBackground = savedMovableByBackground
    window.standardWindowButton(.closeButton)?.isHidden = false
    window.standardWindowButton(.miniaturizeButton)?.isHidden = false
    window.standardWindowButton(.zoomButton)?.isHidden = false
    if let content = window.contentView {
      content.layer?.cornerRadius = 0
      content.layer?.masksToBounds = false
    }
    window.setAccessibilityElement(true)
    window.setAccessibilityRole(.window)
  }

  private func visibleFrame() -> NSRect {
    guard let window else {
      return NSScreen.main?.visibleFrame ?? .zero
    }
    return window.screen?.visibleFrame
      ?? NSScreen.main?.visibleFrame
      ?? .zero
  }

  private func visibleFramePayload() -> [String: Double] {
    let f = visibleFrame()
    return [
      "x": f.origin.x,
      "y": f.origin.y,
      "width": f.size.width,
      "height": f.size.height,
    ]
  }

  private func dockBottomRight() {
    guard let window else { return }
    let work = visibleFrame()
    let pad: CGFloat = 12
    let size = window.frame.size
    let origin = NSPoint(
      x: work.maxX - size.width - pad,
      y: work.minY + pad
    )
    window.setFrame(NSRect(origin: origin, size: size), display: true, animate: false)
  }
}

var desktopPipController: DesktopPipController?

func registerDesktopPipChannel(_ controller: FlutterViewController, window: NSWindow) {
  let pip = DesktopPipController(window: window)
  desktopPipController = pip
  let channel = FlutterMethodChannel(
    name: "forja/desktop_pip",
    binaryMessenger: controller.engine.binaryMessenger
  )
  channel.setMethodCallHandler { call, result in
    pip.handle(call, result: result)
  }
}
