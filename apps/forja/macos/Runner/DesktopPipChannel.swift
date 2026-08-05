import Cocoa
import FlutterMacOS
import QuartzCore

/// Safari-like PiP chrome for the main Flutter window: floating level,
/// rounded clip, shadow, Space/fullscreen join, and AX opt-out so Magnet /
/// Rectangle / tiling tools do not steal throw/drag gestures.
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
  private var localMouseUpMonitor: Any?
  private var localMouseDownMonitor: Any?
  private var dragStartOrigin: NSPoint?

  init(window: NSWindow) {
    self.window = window
    super.init()
  }

  deinit {
    stopDragMonitors()
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "setEnabled":
      let enabled = (call.arguments as? [String: Any])?["enabled"] as? Bool ?? false
      setPipEnabled(enabled)
      result(nil)
    case "snapToNearestCorner":
      snapToNearestCorner(animated: true)
      result(nil)
    case "dockBottomRight":
      dockBottomRight()
      result(nil)
    case "visibleFrame":
      result(visibleFramePayload())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func setPipEnabled(_ enabled: Bool) {
    guard let window else { return }
    if enabled {
      if !pipEnabled {
        savedLevel = window.level
        savedCollection = window.collectionBehavior
        savedStyleMask = window.styleMask
        savedOpaque = window.isOpaque
        savedHasShadow = window.hasShadow
        savedBackground = window.backgroundColor ?? .black
        savedMovableByBackground = window.isMovableByWindowBackground
        pipEnabled = true
      }
      applyPipChrome()
      startDragMonitors()
    } else if pipEnabled {
      pipEnabled = false
      stopDragMonitors()
      restoreChrome()
    }
  }

  private func startDragMonitors() {
    stopDragMonitors()
    dragStartOrigin = nil
    localMouseDownMonitor = NSEvent.addLocalMonitorForEvents(
      matching: [.leftMouseDown]
    ) { [weak self] event in
      self?.dragStartOrigin = self?.window?.frame.origin
      return event
    }
    localMouseUpMonitor = NSEvent.addLocalMonitorForEvents(
      matching: [.leftMouseUp]
    ) { [weak self] event in
      guard let self, self.pipEnabled, let start = self.dragStartOrigin else {
        return event
      }
      self.dragStartOrigin = nil
      let now = self.window?.frame.origin ?? start
      let moved = abs(now.x - start.x) > 8 || abs(now.y - start.y) > 8
      guard moved else { return event }
      DispatchQueue.main.async {
        self.snapToNearestCorner(animated: true)
      }
      return event
    }
  }

  private func stopDragMonitors() {
    if let localMouseDownMonitor {
      NSEvent.removeMonitor(localMouseDownMonitor)
      self.localMouseDownMonitor = nil
    }
    if let localMouseUpMonitor {
      NSEvent.removeMonitor(localMouseUpMonitor)
      self.localMouseUpMonitor = nil
    }
    dragStartOrigin = nil
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

  private func snapToNearestCorner(animated: Bool) {
    guard let window else { return }
    let work = visibleFrame()
    let pad: CGFloat = 12
    let size = window.frame.size
    let center = NSPoint(x: window.frame.midX, y: window.frame.midY)

    let corners: [NSPoint] = [
      NSPoint(x: work.minX + pad, y: work.maxY - size.height - pad),
      NSPoint(x: work.maxX - size.width - pad, y: work.maxY - size.height - pad),
      NSPoint(x: work.minX + pad, y: work.minY + pad),
      NSPoint(x: work.maxX - size.width - pad, y: work.minY + pad),
    ]

    var best = corners[0]
    var bestDist = CGFloat.greatestFiniteMagnitude
    for c in corners {
      let dx = (c.x + size.width / 2) - center.x
      let dy = (c.y + size.height / 2) - center.y
      let d = dx * dx + dy * dy
      if d < bestDist {
        bestDist = d
        best = c
      }
    }

    let target = NSRect(origin: best, size: size)
    if animated {
      NSAnimationContext.runAnimationGroup { ctx in
        ctx.duration = 0.22
        ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
        window.animator().setFrame(target, display: true)
      }
    } else {
      window.setFrame(target, display: true)
    }
  }
}

private var _desktopPipController: DesktopPipController?

func registerDesktopPipChannel(_ controller: FlutterViewController, window: NSWindow) {
  let pip = DesktopPipController(window: window)
  _desktopPipController = pip
  let channel = FlutterMethodChannel(
    name: "forja/desktop_pip",
    binaryMessenger: controller.engine.binaryMessenger
  )
  channel.setMethodCallHandler { call, result in
    pip.handle(call, result: result)
  }
}
