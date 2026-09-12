import Cocoa
import FlutterMacOS
import Darwin

/// Optional libVLC backend (system VLC.app). Texture / NSView via PlatformView.
final class ForjaVlcPlugin: NSObject, FlutterPlugin {
  private var sessions: [Int64: VlcSession] = [:]
  private var eventSink: FlutterEventSink?
  private var libHandle: UnsafeMutableRawPointer?
  private var available = false

  // Minimal libVLC symbols we need (fileprivate — used by VlcSession via api).
  fileprivate typealias LibVlcNew = @convention(c) (Int32, UnsafePointer<UnsafePointer<CChar>?>?) -> OpaquePointer?
  fileprivate typealias LibVlcRelease = @convention(c) (OpaquePointer?) -> Void
  fileprivate typealias MediaNew = @convention(c) (OpaquePointer?, UnsafePointer<CChar>?) -> OpaquePointer?
  fileprivate typealias MediaRelease = @convention(c) (OpaquePointer?) -> Void
  fileprivate typealias MediaAddOption = @convention(c) (OpaquePointer?, UnsafePointer<CChar>?) -> Void
  fileprivate typealias PlayerNew = @convention(c) (OpaquePointer?) -> OpaquePointer?
  fileprivate typealias PlayerRelease = @convention(c) (OpaquePointer?) -> Void
  fileprivate typealias PlayerSetMedia = @convention(c) (OpaquePointer?, OpaquePointer?) -> Void
  fileprivate typealias PlayerPlay = @convention(c) (OpaquePointer?) -> Int32
  fileprivate typealias PlayerStop = @convention(c) (OpaquePointer?) -> Void
  fileprivate typealias PlayerPause = @convention(c) (OpaquePointer?) -> Void
  fileprivate typealias PlayerSetPause = @convention(c) (OpaquePointer?, Int32) -> Void
  fileprivate typealias PlayerSetVolume = @convention(c) (OpaquePointer?, Int32) -> Int32
  fileprivate typealias PlayerSetNsobject = @convention(c) (OpaquePointer?, UnsafeMutableRawPointer?) -> Void

  private var libvlc_new: LibVlcNew?
  private var libvlc_release: LibVlcRelease?
  private var media_new: MediaNew?
  private var media_release: MediaRelease?
  private var media_add_option: MediaAddOption?
  private var player_new: PlayerNew?
  private var player_release: PlayerRelease?
  private var player_set_media: PlayerSetMedia?
  private var player_play: PlayerPlay?
  private var player_stop: PlayerStop?
  private var player_set_pause: PlayerSetPause?
  private var player_set_volume: PlayerSetVolume?
  private var player_set_nsobject: PlayerSetNsobject?

  private var instance: OpaquePointer?

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = ForjaVlcPlugin()
    instance.loadLibrary()
    let channel = FlutterMethodChannel(
      name: "com.forjahq.app/vlc",
      binaryMessenger: registrar.messenger
    )
    registrar.addMethodCallDelegate(instance, channel: channel)
    let events = FlutterEventChannel(
      name: "com.forjahq.app/vlc_events",
      binaryMessenger: registrar.messenger
    )
    events.setStreamHandler(instance)
    registrar.register(
      VlcViewFactory(plugin: instance),
      withId: "forja-vlc"
    )
  }

  private func loadLibrary() {
    let appLib = "/Applications/VLC.app/Contents/MacOS/lib"
    let appPlugins = "/Applications/VLC.app/Contents/MacOS/plugins"
    let candidates = [
      "\(appLib)/libvlc.dylib",
      "/usr/local/lib/libvlc.dylib",
      "/opt/homebrew/lib/libvlc.dylib",
    ]

    // Without this, libvlc_new returns null even when VLC.app is installed.
    setenv("VLC_PLUGIN_PATH", appPlugins, 1)

    for path in candidates {
      let dir = (path as NSString).deletingLastPathComponent
      // libvlc @rpath → libvlccore; load core first with GLOBAL.
      _ = dlopen("\(dir)/libvlccore.dylib", RTLD_NOW | RTLD_GLOBAL)

      guard let handle = dlopen(path, RTLD_NOW | RTLD_GLOBAL) else { continue }
      libHandle = handle
      libvlc_new = unsafeBitCast(dlsym(handle, "libvlc_new"), to: LibVlcNew?.self)
      libvlc_release = unsafeBitCast(dlsym(handle, "libvlc_release"), to: LibVlcRelease?.self)
      media_new = unsafeBitCast(dlsym(handle, "libvlc_media_new_location"), to: MediaNew?.self)
      media_release = unsafeBitCast(dlsym(handle, "libvlc_media_release"), to: MediaRelease?.self)
      media_add_option = unsafeBitCast(dlsym(handle, "libvlc_media_add_option"), to: MediaAddOption?.self)
      player_new = unsafeBitCast(dlsym(handle, "libvlc_media_player_new"), to: PlayerNew?.self)
      player_release = unsafeBitCast(dlsym(handle, "libvlc_media_player_release"), to: PlayerRelease?.self)
      player_set_media = unsafeBitCast(dlsym(handle, "libvlc_media_player_set_media"), to: PlayerSetMedia?.self)
      player_play = unsafeBitCast(dlsym(handle, "libvlc_media_player_play"), to: PlayerPlay?.self)
      player_stop = unsafeBitCast(dlsym(handle, "libvlc_media_player_stop"), to: PlayerStop?.self)
      player_set_pause = unsafeBitCast(dlsym(handle, "libvlc_media_player_set_pause"), to: PlayerSetPause?.self)
      player_set_volume = unsafeBitCast(dlsym(handle, "libvlc_audio_set_volume"), to: PlayerSetVolume?.self)
      player_set_nsobject = unsafeBitCast(dlsym(handle, "libvlc_media_player_set_nsobject"), to: PlayerSetNsobject?.self)

      guard libvlc_new != nil, player_new != nil, media_new != nil else { continue }

      instance = libvlc_new?(0, nil)
      available = instance != nil
      if available {
        NSLog("[ForjaVLC] libVLC ready (%@)", path)
        break
      }
      NSLog("[ForjaVLC] libvlc_new failed for %@", path)
    }

    if !available {
      NSLog("[ForjaVLC] not available — install VLC.app or Homebrew libvlc")
    }
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    let viewId = (args["viewId"] as? NSNumber)?.int64Value
      ?? (args["viewId"] as? Int).map { Int64($0) }
      ?? -1

    switch call.method {
    case "isAvailable":
      result(available)
    case "create":
      // Texture path unused on macOS — PlatformView hosts video. Return -1.
      result(-1)
    case "open":
      guard available, viewId >= 0,
            let url = args["url"] as? String
      else {
        result(FlutterError(code: "unavailable", message: "libVLC missing or bad args", details: nil))
        return
      }
      let headers = (args["headers"] as? [String: String]) ?? [:]
      let session = sessions[viewId] ?? VlcSession(viewId: viewId, plugin: self)
      sessions[viewId] = session
      session.open(url: url, headers: headers)
      result(nil)
    case "play":
      sessions[viewId]?.play()
      result(nil)
    case "pause":
      sessions[viewId]?.pause()
      result(nil)
    case "setVolume":
      let volume = (args["volume"] as? NSNumber)?.intValue ?? 100
      sessions[viewId]?.setVolume(volume)
      result(nil)
    case "dispose":
      sessions[viewId]?.dispose()
      sessions.removeValue(forKey: viewId)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func emit(viewId: Int64, type: String, value: Any? = nil) {
    var payload: [String: Any] = ["viewId": viewId, "type": type]
    if let value { payload["value"] = value }
    DispatchQueue.main.async { [weak self] in
      self?.eventSink?(payload)
    }
  }

  func attachView(viewId: Int64, view: VlcContainerView) {
    let session = sessions[viewId] ?? VlcSession(viewId: viewId, plugin: self)
    sessions[viewId] = session
    session.attach(view: view)
  }

  fileprivate func makePlayer() -> OpaquePointer? {
    guard let instance, let player_new else { return nil }
    return player_new(instance)
  }

  fileprivate func makeMedia(url: String) -> OpaquePointer? {
    guard let instance, let media_new else { return nil }
    return url.withCString { media_new(instance, $0) }
  }

  fileprivate var api: (
    media_release: MediaRelease?,
    media_add_option: MediaAddOption?,
    player_release: PlayerRelease?,
    player_set_media: PlayerSetMedia?,
    player_play: PlayerPlay?,
    player_stop: PlayerStop?,
    player_set_pause: PlayerSetPause?,
    player_set_volume: PlayerSetVolume?,
    player_set_nsobject: PlayerSetNsobject?
  ) {
    (
      media_release,
      media_add_option,
      player_release,
      player_set_media,
      player_play,
      player_stop,
      player_set_pause,
      player_set_volume,
      player_set_nsobject
    )
  }
}

extension ForjaVlcPlugin: FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}

final class VlcViewFactory: NSObject, FlutterPlatformViewFactory {
  private weak var plugin: ForjaVlcPlugin?

  init(plugin: ForjaVlcPlugin) {
    self.plugin = plugin
    super.init()
  }

  func create(withViewIdentifier viewId: Int64, arguments args: Any?) -> NSView {
    let params = args as? [String: Any]
    let dartViewId = (params?["viewId"] as? NSNumber)?.int64Value
      ?? (params?["viewId"] as? Int).map { Int64($0) }
      ?? viewId
    let view = VlcContainerView(frame: .zero)
    plugin?.attachView(viewId: dartViewId, view: view)
    return view
  }

  func createArgsCodec() -> (any FlutterMessageCodec & NSObjectProtocol)? {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

final class VlcContainerView: NSView {
  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    wantsLayer = true
    layer?.backgroundColor = NSColor.black.cgColor
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError() }
}

final class VlcSession {
  private let viewId: Int64
  private weak var plugin: ForjaVlcPlugin?
  private var player: OpaquePointer?
  private weak var view: VlcContainerView?

  init(viewId: Int64, plugin: ForjaVlcPlugin) {
    self.viewId = viewId
    self.plugin = plugin
  }

  func attach(view: VlcContainerView) {
    self.view = view
    if let player {
      plugin?.api.player_set_nsobject?(player, Unmanaged.passUnretained(view).toOpaque())
    }
  }

  func open(url: String, headers: [String: String]) {
    disposePlayerOnly()
    guard let plugin,
          let media = plugin.makeMedia(url: url),
          let player = plugin.makePlayer()
    else {
      plugin?.emit(viewId: viewId, type: "error", value: "libVLC open failed")
      return
    }
    self.player = player
    applyMediaOptions(media: media, url: url, headers: headers, plugin: plugin)
    plugin.api.player_set_media?(player, media)
    plugin.api.media_release?(media)
    if let view {
      plugin.api.player_set_nsobject?(player, Unmanaged.passUnretained(view).toOpaque())
    }
    plugin.emit(viewId: viewId, type: "buffering", value: true)
    _ = plugin.api.player_play?(player)
    plugin.emit(viewId: viewId, type: "ready")
    plugin.emit(viewId: viewId, type: "playing", value: true)
  }

  /// Live IPTV (esp. progressive MPEG-TS) needs loose clock + cache.
  /// VideoToolbox + broken PCR → ~2–3s freezes ("no reference clock").
  private func applyMediaOptions(
    media: OpaquePointer,
    url: String,
    headers: [String: String],
    plugin: ForjaVlcPlugin
  ) {
    func add(_ opt: String) {
      opt.withCString { plugin.api.media_add_option?(media, $0) }
    }

    add(":network-caching=2000")
    add(":live-caching=2000")
    add(":clock-jitter=0")
    add(":clock-synchro=0")
    add(":drop-late-frames")
    add(":skip-frames")
    add(":no-audio-time-stretch")

    let lower = url.lowercased()
    let progressiveTs = lower.contains(".ts") && !lower.contains(".m3u8")
    if progressiveTs {
      // SW decode avoids VT timestamp conversion failures on Xtream TS.
      add(":avcodec-hw=none")
    }

    if let ua = headers["User-Agent"] ?? headers["user-agent"] {
      add(":http-user-agent=\(ua)")
    }
    if let ref = headers["Referer"] ?? headers["referer"] {
      add(":http-referrer=\(ref)")
    }
  }

  func play() {
    plugin?.api.player_set_pause?(player, 0)
  }

  func pause() {
    plugin?.api.player_set_pause?(player, 1)
  }

  func setVolume(_ volume: Int) {
    _ = plugin?.api.player_set_volume?(player, Int32(max(0, min(100, volume))))
  }

  func dispose() {
    disposePlayerOnly()
    view = nil
  }

  private func disposePlayerOnly() {
    if let player {
      plugin?.api.player_stop?(player)
      plugin?.api.player_release?(player)
    }
    player = nil
  }
}

func registerForjaVlc(_ controller: FlutterViewController) {
  let registrar = controller.registrar(forPlugin: "ForjaVlcPlugin")
  ForjaVlcPlugin.register(with: registrar)
}
