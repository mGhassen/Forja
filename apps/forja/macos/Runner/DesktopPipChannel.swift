import Cocoa
import FlutterMacOS
import media_kit_libs_macos_video
import media_kit_video
import volume_controller
import wakelock_plus

/// Desktop PiP: secondary always-on-top float window with its own FlutterEngine.
/// Main Forja window stays full-size; Dart shows a placeholder there.
final class DesktopPipController: NSObject {
  private weak var mainWindow: NSWindow?
  private weak var mainMessenger: FlutterBinaryMessenger?

  private var spaceLeavePrepared = false
  private var spaceLeavePrepAllowed = false
  private var savedLevel: NSWindow.Level = .normal
  private var savedCollection: NSWindow.CollectionBehavior = []

  private var floatWindow: NSPanel?
  private var floatEngine: FlutterEngine?
  private var floatViewController: FlutterViewController?
  private var floatChannel: FlutterMethodChannel?
  private var pendingOpen: [String: Any]?
  private var floatReady = false

  init(window: NSWindow, messenger: FlutterBinaryMessenger) {
    self.mainWindow = window
    self.mainMessenger = messenger
    super.init()
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
    case "setSpaceLeavePrepAllowed":
      let allowed =
        (call.arguments as? [String: Any])?["allowed"] as? Bool ?? false
      setSpaceLeavePrepAllowed(allowed)
      result(nil)
    case "cancelSpaceLeavePrep":
      cancelSpaceLeavePrep()
      result(nil)
    case "createFloat":
      let args = call.arguments as? [String: Any] ?? [:]
      let width = (args["width"] as? Double) ?? 360
      let height = (args["height"] as? Double) ?? 203
      result(createFloat(width: width, height: height))
    case "openFloat":
      let args = call.arguments as? [String: Any] ?? [:]
      openFloat(args)
      result(nil)
    case "destroyFloat":
      destroyFloat()
      result(nil)
    // Legacy no-ops — main window is never the PiP surface anymore.
    case "setEnabled", "enterPip", "dockBottomRight":
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

  func cancelSpaceLeavePrep() {
    guard let window = mainWindow, spaceLeavePrepared, floatWindow == nil else {
      spaceLeavePrepared = false
      return
    }
    window.level = savedLevel
    window.collectionBehavior = savedCollection
    spaceLeavePrepared = false
  }

  /// Soft arm while Auto PiP is on — does not shrink. Dart creates the float.
  func prepareForSpaceLeave() {
    guard let window = mainWindow, floatWindow == nil, spaceLeavePrepAllowed
    else { return }
    if !spaceLeavePrepared {
      savedLevel = window.level
      savedCollection = window.collectionBehavior
      spaceLeavePrepared = true
    }
    // Do not float the main window — float host owns always-on-top.
  }

  private func createFloat(width: Double, height: Double) -> Bool {
    destroyFloat()
    cancelSpaceLeavePrep()

    let project = FlutterDartProject()
    let engine = FlutterEngine(name: "forja.pip_float", project: project)
    // macOS has no libraryURI — entrypoint must live in the same library as main().
    let ran = engine.run(withEntrypoint: "pipFloatMain")
    guard ran else {
      NSLog("[DesktopPip] float engine failed to run pipFloatMain")
      return false
    }
    RegisterPipFloatPlugins(registry: engine)

    let fvc = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
    let work = visibleFrame()
    let pad: CGFloat = 12
    let size = NSSize(width: width, height: height)
    let origin = NSPoint(
      x: work.maxX - size.width - pad,
      y: work.minY + pad
    )

    let panel = NSPanel(
      contentRect: NSRect(origin: origin, size: size),
      styleMask: [.borderless, .resizable, .fullSizeContentView, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.contentViewController = fvc
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.level = .floating
    panel.collectionBehavior = [
      .canJoinAllSpaces,
      .fullScreenAuxiliary,
      .transient,
      .ignoresCycle,
    ]
    panel.isMovableByWindowBackground = true
    panel.titleVisibility = .hidden
    panel.titlebarAppearsTransparent = true
    panel.isFloatingPanel = true
    panel.becomesKeyOnlyIfNeeded = true
    panel.hidesOnDeactivate = false
    if let content = panel.contentView {
      content.wantsLayer = true
      content.layer?.cornerRadius = 12
      content.layer?.masksToBounds = true
    }
    panel.setAccessibilityElement(false)
    panel.setAccessibilityRole(.none)
    panel.setFrame(NSRect(origin: origin, size: size), display: true)
    panel.orderFrontRegardless()

    let channel = FlutterMethodChannel(
      name: "forja/pip_float",
      binaryMessenger: engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handleFloatCall(call, result: result)
    }

    floatEngine = engine
    floatViewController = fvc
    floatWindow = panel
    floatChannel = channel
    floatReady = false
    (mainWindow as? MainFlutterWindow)?.forjaSetPipActive(false)
    return true
  }

  private func openFloat(_ args: [String: Any]) {
    pendingOpen = args
    flushPendingOpen()
  }

  private func flushPendingOpen() {
    guard floatReady, let pending = pendingOpen, let channel = floatChannel else {
      return
    }
    pendingOpen = nil
    channel.invokeMethod("open", arguments: pending)
  }

  private func destroyFloat() {
    floatChannel?.invokeMethod("teardown", arguments: nil)
    floatChannel?.setMethodCallHandler(nil)
    floatChannel = nil
    floatWindow?.orderOut(nil)
    floatWindow?.contentViewController = nil
    floatWindow = nil
    floatViewController = nil
    // Do not shutDownEngine synchronously — teardown is async and racing
    // shutDown produces "Invalid engine handle" lifecycle spam.
    let engine = floatEngine
    floatEngine = nil
    pendingOpen = nil
    floatReady = false
    if let engine {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
        engine.shutDownEngine()
      }
    }
  }

  private func handleFloatCall(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    switch call.method {
    case "floatReady":
      floatReady = true
      flushPendingOpen()
      result(nil)
    case "expand":
      notifyMain("floatExpand", arguments: call.arguments)
      result(nil)
    case "close":
      notifyMain("floatClose", arguments: nil)
      result(nil)
    case "minimize":
      floatWindow?.miniaturize(nil)
      result(nil)
    case "startDrag":
      if let event = NSApp.currentEvent, let window = floatWindow {
        window.performDrag(with: event)
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func notifyMain(_ method: String, arguments: Any?) {
    guard let messenger = mainMessenger else { return }
    let channel = FlutterMethodChannel(
      name: "forja/desktop_pip",
      binaryMessenger: messenger
    )
    channel.invokeMethod(method, arguments: arguments)
  }

  private func visibleFrame() -> NSRect {
    guard let window = mainWindow else {
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
}

/// Minimal plugin set for the PiP float engine (media_kit + volume).
func RegisterPipFloatPlugins(registry: FlutterPluginRegistry) {
  MediaKitLibsMacosVideoPlugin.register(
    with: registry.registrar(forPlugin: "MediaKitLibsMacosVideoPlugin")
  )
  MediaKitVideoPlugin.register(
    with: registry.registrar(forPlugin: "MediaKitVideoPlugin")
  )
  VolumeControllerPlugin.register(
    with: registry.registrar(forPlugin: "VolumeControllerPlugin")
  )
  WakelockPlusMacosPlugin.register(
    with: registry.registrar(forPlugin: "WakelockPlusMacosPlugin")
  )
}

var desktopPipController: DesktopPipController?

func registerDesktopPipChannel(_ controller: FlutterViewController, window: NSWindow) {
  let pip = DesktopPipController(
    window: window,
    messenger: controller.engine.binaryMessenger
  )
  desktopPipController = pip
  let channel = FlutterMethodChannel(
    name: "forja/desktop_pip",
    binaryMessenger: controller.engine.binaryMessenger
  )
  channel.setMethodCallHandler { call, result in
    pip.handle(call, result: result)
  }
}
