import Cocoa
import FlutterMacOS

/// Streams Mission Control Space switches so Dart can auto-enter desktop PiP.
final class DesktopSpaceStreamHandler: NSObject, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?
  private var observer: NSObjectProtocol?

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    observer = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.activeSpaceDidChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.emitActiveSpace()
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    if let observer {
      NSWorkspace.shared.notificationCenter.removeObserver(observer)
    }
    observer = nil
    eventSink = nil
    return nil
  }

  private func emitActiveSpace() {
    let window = NSApp.mainWindow
      ?? NSApp.windows.first(where: { $0.isVisible })
      ?? NSApp.keyWindow
    let onActive = window?.isOnActiveSpace ?? false
    // Join all Spaces immediately when leaving — before Dart round-trips —
    // so the window never vanishes mid-swipe (audio/video stay alive).
    if !onActive {
      desktopPipController?.prepareForSpaceLeave()
    }
    eventSink?(["onActiveSpace": onActive])
  }
}

func registerDesktopSpaceChannel(_ controller: FlutterViewController) {
  let channel = FlutterEventChannel(
    name: "forja/desktop_space",
    binaryMessenger: controller.engine.binaryMessenger
  )
  channel.setStreamHandler(DesktopSpaceStreamHandler())
}
