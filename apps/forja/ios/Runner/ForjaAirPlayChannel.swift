import AVFoundation
import AVKit
import Flutter
import UIKit

/// AirPlay hand-off: a muted AVPlayer follows the stream, the system route
/// picker opens, and the player goes external once an AirPlay device is chosen.
final class ForjaAirPlayPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?
  private var player: AVPlayer?
  private var externalObservation: NSKeyValueObservation?
  private var statusObservation: NSKeyValueObservation?
  private var pickerView: AVRoutePickerView?
  private var pickTimeout: DispatchWorkItem?
  private var external = false

  /// Picker left open without a choice — release the hidden player.
  private static let pickTimeoutSeconds: TimeInterval = 90

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = ForjaAirPlayPlugin()
    let channel = FlutterMethodChannel(
      name: "com.forjahq.app/airplay",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(instance, channel: channel)
    let events = FlutterEventChannel(
      name: "com.forjahq.app/airplay_events",
      binaryMessenger: registrar.messenger()
    )
    events.setStreamHandler(instance)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "start":
      guard let urlString = args["url"] as? String, let url = URL(string: urlString) else {
        result(FlutterError(code: "bad_args", message: "Missing url", details: nil))
        return
      }
      let headers = (args["headers"] as? [String: String]) ?? [:]
      let positionMs = (args["positionMs"] as? NSNumber)?.int64Value ?? 0
      start(url: url, headers: headers, positionMs: positionMs)
      result(true)
    case "showPicker":
      result(showPicker())
    case "stop":
      let ms = positionMs()
      teardown()
      result(ms)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

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

  private func start(url: URL, headers: [String: String], positionMs: Int64) {
    teardown()
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.playback, mode: .moviePlayback)
    try? session.setActive(true)

    var options: [String: Any] = [:]
    if !headers.isEmpty {
      options["AVURLAssetHTTPHeaderFieldsKey"] = headers
    }
    let item = AVPlayerItem(asset: AVURLAsset(url: url, options: options))
    let player = AVPlayer(playerItem: item)
    player.allowsExternalPlayback = true
    player.usesExternalPlaybackWhileExternalScreenIsActive = true
    player.isMuted = true
    self.player = player

    statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
      guard item.status == .failed else { return }
      DispatchQueue.main.async {
        guard let self else { return }
        self.emit([
          "event": "error",
          "message": item.error?.localizedDescription ?? "AirPlay could not play this stream",
          "positionMs": self.positionMs(),
        ])
        self.teardown()
      }
    }
    externalObservation = player.observe(\.isExternalPlaybackActive, options: [.new]) {
      [weak self] player, _ in
      DispatchQueue.main.async { self?.externalChanged(player.isExternalPlaybackActive) }
    }

    if positionMs > 0 {
      player.seek(
        to: CMTime(value: positionMs, timescale: 1000),
        toleranceBefore: .zero,
        toleranceAfter: .zero
      )
    }
    player.play()
    armPickTimeout()
    _ = showPicker()
  }

  private func showPicker() -> Bool {
    guard player != nil, let host = Self.hostView() else { return false }
    let picker = pickerView ?? AVRoutePickerView(frame: .zero)
    picker.prioritizesVideoDevices = true
    picker.alpha = 0.01
    // Top-right, under the player's Cast button, so an iPad popover opens there.
    let side = Self.pickerAnchorSize
    picker.frame = CGRect(
      x: host.bounds.maxX - Self.pickerAnchorInset - side,
      y: host.safeAreaInsets.top + Self.pickerAnchorInset,
      width: side,
      height: side
    )
    picker.autoresizingMask = [.flexibleLeftMargin, .flexibleBottomMargin]
    if picker.superview == nil {
      host.addSubview(picker)
    }
    pickerView = picker
    guard let button = Self.findButton(in: picker) else { return false }
    button.sendActions(for: .touchUpInside)
    return true
  }

  private static let pickerAnchorSize: CGFloat = 24
  private static let pickerAnchorInset: CGFloat = 56

  private static func findButton(in view: UIView) -> UIButton? {
    for sub in view.subviews {
      if let button = sub as? UIButton { return button }
      if let nested = findButton(in: sub) { return nested }
    }
    return nil
  }

  private func armPickTimeout() {
    pickTimeout?.cancel()
    let work = DispatchWorkItem { [weak self] in
      guard let self, !self.external else { return }
      self.teardown()
      self.emit(["event": "cancelled"])
    }
    pickTimeout = work
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.pickTimeoutSeconds, execute: work)
  }

  private func externalChanged(_ active: Bool) {
    guard let player else { return }
    if active {
      guard !external else { return }
      external = true
      pickTimeout?.cancel()
      player.isMuted = false
      if player.rate == 0 { player.play() }
      emit(["event": "active", "positionMs": positionMs()])
    } else {
      guard external else { return }
      let ms = positionMs()
      teardown()
      emit(["event": "inactive", "positionMs": ms])
    }
  }

  private func positionMs() -> Int64 {
    guard let time = player?.currentTime(), time.isNumeric else { return 0 }
    return Int64(CMTimeGetSeconds(time) * 1000)
  }

  private func teardown() {
    pickTimeout?.cancel()
    pickTimeout = nil
    externalObservation?.invalidate()
    externalObservation = nil
    statusObservation?.invalidate()
    statusObservation = nil
    player?.pause()
    player?.replaceCurrentItem(with: nil)
    player = nil
    pickerView?.removeFromSuperview()
    pickerView = nil
    external = false
  }

  private func emit(_ payload: [String: Any]) {
    eventSink?(payload)
  }

  private static func hostView() -> UIView? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let windows = scenes.flatMap { $0.windows }
    return (windows.first { $0.isKeyWindow } ?? windows.first)?.rootViewController?.view
  }
}
