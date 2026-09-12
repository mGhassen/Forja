import AVFoundation
import Cocoa
import FlutterMacOS

/// IPTV HLS via AVPlayer + AVPlayerLayer inside a Flutter PlatformView.
final class ForjaAvPlayerPlugin: NSObject, FlutterPlugin {
  private var players: [Int64: AvPlayerSession] = [:]
  private var eventSink: FlutterEventSink?
  private weak var messenger: FlutterBinaryMessenger?

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = ForjaAvPlayerPlugin()
    instance.messenger = registrar.messenger
    let channel = FlutterMethodChannel(
      name: "com.forjahq.app/avplayer",
      binaryMessenger: registrar.messenger
    )
    registrar.addMethodCallDelegate(instance, channel: channel)

    let events = FlutterEventChannel(
      name: "com.forjahq.app/avplayer_events",
      binaryMessenger: registrar.messenger
    )
    events.setStreamHandler(instance)

    registrar.register(
      AvPlayerViewFactory(plugin: instance),
      withId: "forja-avplayer"
    )
  }

  /// Called from MainFlutterWindow without a FlutterPluginRegistrar.
  static func register(messenger: FlutterBinaryMessenger, registry: FlutterPluginRegistry) {
    let registrar = registry.registrar(forPlugin: "ForjaAvPlayerPlugin")
    register(with: registrar)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    let viewId = (args["viewId"] as? NSNumber)?.int64Value
      ?? (args["viewId"] as? Int).map { Int64($0) }
      ?? -1

    switch call.method {
    case "open":
      guard viewId >= 0,
            let urlString = args["url"] as? String,
            let url = URL(string: urlString)
      else {
        result(
          FlutterError(code: "bad_args", message: "Missing viewId/url", details: nil)
        )
        return
      }
      let headers = (args["headers"] as? [String: String]) ?? [:]
      let session = players[viewId] ?? AvPlayerSession(viewId: viewId, plugin: self)
      players[viewId] = session
      session.open(url: url, headers: headers)
      result(nil)
    case "play":
      players[viewId]?.play()
      result(nil)
    case "pause":
      players[viewId]?.pause()
      result(nil)
    case "setVolume":
      let volume = (args["volume"] as? NSNumber)?.doubleValue ?? 1.0
      players[viewId]?.setVolume(Float(volume))
      result(nil)
    case "dispose":
      players[viewId]?.dispose()
      players.removeValue(forKey: viewId)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func emit(viewId: Int64, type: String, value: Any? = nil) {
    var payload: [String: Any] = ["viewId": viewId, "type": type]
    if let value {
      payload["value"] = value
    }
    DispatchQueue.main.async { [weak self] in
      self?.eventSink?(payload)
    }
  }

  func attachView(viewId: Int64, container: AvPlayerContainerView) {
    let session = players[viewId] ?? AvPlayerSession(viewId: viewId, plugin: self)
    players[viewId] = session
    session.attach(container: container)
  }
}

extension ForjaAvPlayerPlugin: FlutterStreamHandler {
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

final class AvPlayerViewFactory: NSObject, FlutterPlatformViewFactory {
  private weak var plugin: ForjaAvPlayerPlugin?

  init(plugin: ForjaAvPlayerPlugin) {
    self.plugin = plugin
    super.init()
  }

  func create(
    withViewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> NSView {
    let params = args as? [String: Any]
    let dartViewId = (params?["viewId"] as? NSNumber)?.int64Value
      ?? (params?["viewId"] as? Int).map { Int64($0) }
      ?? viewId
    let container = AvPlayerContainerView(frame: .zero)
    plugin?.attachView(viewId: dartViewId, container: container)
    return container
  }

  func createArgsCodec() -> (any FlutterMessageCodec & NSObjectProtocol)? {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

final class AvPlayerContainerView: NSView {
  let playerLayer = AVPlayerLayer()

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    wantsLayer = true
    layer = CALayer()
    layer?.backgroundColor = NSColor.black.cgColor
    playerLayer.videoGravity = .resizeAspect
    layer?.addSublayer(playerLayer)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layout() {
    super.layout()
    playerLayer.frame = bounds
  }
}

final class AvPlayerSession {
  private let viewId: Int64
  private weak var plugin: ForjaAvPlayerPlugin?
  private var player: AVPlayer?
  private var container: AvPlayerContainerView?
  private var statusObs: NSKeyValueObservation?
  private var rateObs: NSKeyValueObservation?
  private var itemStatusObs: NSKeyValueObservation?
  private var failObs: NSObjectProtocol?
  private var stallObs: NSObjectProtocol?

  init(viewId: Int64, plugin: ForjaAvPlayerPlugin) {
    self.viewId = viewId
    self.plugin = plugin
  }

  func attach(container: AvPlayerContainerView) {
    self.container = container
    if let player {
      container.playerLayer.player = player
    }
  }

  func open(url: URL, headers: [String: String]) {
    disposePlayerOnly()
    let asset: AVURLAsset
    if headers.isEmpty {
      asset = AVURLAsset(url: url)
    } else {
      asset = AVURLAsset(
        url: url,
        options: ["AVURLAssetHTTPHeaderFieldsKey": headers]
      )
    }
    let item = AVPlayerItem(asset: asset)
    let player = AVPlayer(playerItem: item)
    player.automaticallyWaitsToMinimizeStalling = true
    self.player = player
    container?.playerLayer.player = player

    itemStatusObs = item.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
      guard let self else { return }
      switch item.status {
      case .readyToPlay:
        self.plugin?.emit(viewId: self.viewId, type: "ready")
        player.play()
        self.plugin?.emit(viewId: self.viewId, type: "playing", value: true)
      case .failed:
        let msg = item.error?.localizedDescription ?? "AVPlayer item failed"
        self.plugin?.emit(viewId: self.viewId, type: "error", value: msg)
      default:
        break
      }
    }

    rateObs = player.observe(\.rate, options: [.new]) { [weak self] player, _ in
      guard let self else { return }
      self.plugin?.emit(
        viewId: self.viewId,
        type: "playing",
        value: player.rate > 0
      )
    }

    failObs = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemFailedToPlayToEndTime,
      object: item,
      queue: .main
    ) { [weak self] note in
      guard let self else { return }
      let err = note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
      self.plugin?.emit(
        viewId: self.viewId,
        type: "error",
        value: err?.localizedDescription ?? "playback failed"
      )
    }

    stallObs = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemPlaybackStalled,
      object: item,
      queue: .main
    ) { [weak self] _ in
      guard let self else { return }
      self.plugin?.emit(viewId: self.viewId, type: "buffering", value: true)
    }

    plugin?.emit(viewId: viewId, type: "buffering", value: true)
    player.play()
  }

  func play() {
    player?.play()
  }

  func pause() {
    player?.pause()
  }

  func setVolume(_ volume: Float) {
    player?.volume = max(0, min(1, volume))
  }

  func dispose() {
    disposePlayerOnly()
    container?.playerLayer.player = nil
    container = nil
  }

  private func disposePlayerOnly() {
    if let failObs {
      NotificationCenter.default.removeObserver(failObs)
      self.failObs = nil
    }
    if let stallObs {
      NotificationCenter.default.removeObserver(stallObs)
      self.stallObs = nil
    }
    statusObs = nil
    rateObs = nil
    itemStatusObs = nil
    player?.pause()
    player?.replaceCurrentItem(with: nil)
    player = nil
  }
}

func registerForjaAvPlayer(_ controller: FlutterViewController) {
  let registrar = controller.registrar(forPlugin: "ForjaAvPlayerPlugin")
  ForjaAvPlayerPlugin.register(with: registrar)
}
