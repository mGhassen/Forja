import AVFoundation
import AVKit
import Cocoa
import FlutterMacOS

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
  private var relay: ForjaAirPlaySubtitleRelay?
  /// Bumped on teardown so late callbacks from an old cast are dropped.
  private var generation = 0

  /// Picker left open without a choice — release the hidden player.
  private static let pickTimeoutSeconds: TimeInterval = 90

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = ForjaAirPlayPlugin()
    let channel = FlutterMethodChannel(
      name: "com.forjahq.app/airplay",
      binaryMessenger: registrar.messenger
    )
    registrar.addMethodCallDelegate(instance, channel: channel)
    let events = FlutterEventChannel(
      name: "com.forjahq.app/airplay_events",
      binaryMessenger: registrar.messenger
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
      start(
        url: url,
        headers: headers,
        positionMs: (args["positionMs"] as? NSNumber)?.int64Value ?? 0,
        durationMs: (args["durationMs"] as? NSNumber)?.int64Value ?? 0,
        startTimeMs: (args["startTimeMs"] as? NSNumber)?.int64Value ?? 0,
        subtitle: args["subtitle"] as? [String: Any]
      )
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

  private func start(
    url: URL,
    headers: [String: String],
    positionMs: Int64,
    durationMs: Int64,
    startTimeMs: Int64,
    subtitle: [String: Any]?
  ) {
    teardown()
    let player = AVPlayer()
    player.allowsExternalPlayback = true
    player.isMuted = true
    self.player = player
    externalObservation = player.observe(\.isExternalPlaybackActive, options: [.new]) {
      [weak self] player, _ in
      DispatchQueue.main.async { self?.externalChanged(player.isExternalPlaybackActive) }
    }

    // The picker opens right away; the stream item follows once ready.
    armPickTimeout()
    _ = showPicker()

    let openedAt = Date()
    let session = generation
    let kind = subtitle?["kind"] as? String
    let open: (URL, SubtitleChoice) -> Void = { [weak self] itemURL, choice in
      guard let self, self.generation == session else { return }
      let elapsedMs = Int64(Date().timeIntervalSince(openedAt) * 1000)
      self.openItem(
        itemURL,
        headers: headers,
        positionMs: positionMs > 0 ? positionMs + elapsedMs : 0,
        subtitle: choice
      )
    }

    guard kind == "external", let vtt = subtitle?["vtt"] as? String else {
      switch kind {
      case "off": open(url, .off)
      case "embedded":
        open(
          url,
          .match(
            name: subtitle?["name"] as? String,
            language: subtitle?["language"] as? String,
            index: (subtitle?["index"] as? NSNumber)?.intValue
          ))
      default: open(url, .keep)
      }
      return
    }
    let name = (subtitle?["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "Subtitles"
    let language = subtitle?["language"] as? String
    ForjaAirPlaySubtitleRelay.start(
      source: url,
      headers: headers,
      subtitle: .init(vtt: vtt, name: name, language: language),
      durationSeconds: Double(durationMs) / 1000,
      startTimeSeconds: Double(startTimeMs) / 1000
    ) { [weak self] result in
      guard let self, self.generation == session else {
        if case .success(let (relay, _)) = result { relay.stop() }
        return
      }
      switch result {
      case .success(let (relay, master)):
        self.relay = relay
        open(master, .match(name: name, language: language, index: nil))
      case .failure:
        self.emit(["event": "subtitles", "status": "unavailable"])
        open(url, .keep)
      }
    }
  }

  private enum SubtitleChoice {
    /// Leave the receiver's own default.
    case keep
    case off
    /// [index]: position among the stream's subtitle tracks, used when
    /// neither name nor language matches.
    case match(name: String?, language: String?, index: Int?)
  }

  private func openItem(
    _ url: URL,
    headers: [String: String],
    positionMs: Int64,
    subtitle: SubtitleChoice
  ) {
    guard let player else { return }
    var options: [String: Any] = [:]
    if !headers.isEmpty {
      options["AVURLAssetHTTPHeaderFieldsKey"] = headers
    }
    let item = AVPlayerItem(asset: AVURLAsset(url: url, options: options))
    statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
      DispatchQueue.main.async {
        guard let self, self.player?.currentItem === item else { return }
        switch item.status {
        case .readyToPlay:
          self.applySubtitle(subtitle, to: item)
        case .failed:
          self.emit([
            "event": "error",
            "message": item.error?.localizedDescription ?? "AirPlay could not play this stream",
            "positionMs": self.positionMs(),
          ])
          self.teardown()
        default:
          break
        }
      }
    }
    player.replaceCurrentItem(with: item)
    if positionMs > 0 {
      player.seek(
        to: CMTime(value: positionMs, timescale: 1000),
        toleranceBefore: .zero,
        toleranceAfter: .zero
      )
    }
    player.play()
  }

  private func applySubtitle(_ choice: SubtitleChoice, to item: AVPlayerItem) {
    if case .keep = choice { return }
    let apply: (AVMediaSelectionGroup?) -> Void = { [weak item] group in
      DispatchQueue.main.async {
        guard let item, let group else {
          NSLog("[AirPlay] no legible group on the stream; subtitle \(choice)")
          return
        }
        NSLog(
          "[AirPlay] legible options: %@",
          group.options.map { "\($0.displayName) [\($0.extendedLanguageTag ?? "-")]" }
            .joined(separator: ", "))
        switch choice {
        case .keep:
          return
        case .off:
          if group.allowsEmptySelection { item.select(nil, in: group) }
        case .match(let name, let language, let index):
          let options = group.options.filter {
            !$0.hasMediaCharacteristic(.containsOnlyForcedSubtitles)
          }
          let want = Self.languageCode(language)
          let byIndex = index.flatMap { options.indices.contains($0) ? options[$0] : nil }
          let pick =
            options.first { name != nil && $0.displayName == name }
            ?? options.first {
              want != nil && Self.languageCode($0.extendedLanguageTag ?? $0.locale?.identifier) == want
            }
            ?? byIndex
          NSLog(
            "[AirPlay] subtitle want name=%@ lang=%@ index=%@ -> %@",
            name ?? "-", language ?? "-", index.map(String.init) ?? "-",
            pick?.displayName ?? "none")
          if let pick { item.select(pick, in: group) }
        }
      }
    }
    let asset = item.asset
    if #available(iOS 15.0, macOS 12.0, *) {
      Task { apply(try? await asset.loadMediaSelectionGroup(for: .legible)) }
    } else {
      apply(asset.mediaSelectionGroup(forMediaCharacteristic: .legible))
    }
  }

  /// Two-letter language code from mpv / HLS tags (`eng`, `en-US`, `ger`).
  private static func languageCode(_ raw: String?) -> String? {
    guard let raw, !raw.isEmpty, raw.lowercased() != "und" else { return nil }
    let id = Locale.canonicalLanguageIdentifier(from: raw)
    return id.split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map { $0.lowercased() }
  }

  private func showPicker() -> Bool {
    guard let player, let host = NSApp.keyWindow?.contentView ?? NSApp.mainWindow?.contentView
    else { return false }
    let picker = pickerView ?? AVRoutePickerView(frame: .zero)
    picker.player = player
    picker.alphaValue = 0.01
    // Top-right, under the player's Cast button, so the menu opens there.
    let side = Self.pickerAnchorSize
    picker.frame = NSRect(
      x: host.bounds.maxX - Self.pickerAnchorInset - side,
      y: host.isFlipped ? Self.pickerAnchorInset : host.bounds.maxY - Self.pickerAnchorInset - side,
      width: side,
      height: side
    )
    picker.autoresizingMask = [.minXMargin, host.isFlipped ? .maxYMargin : .minYMargin]
    if picker.superview == nil {
      host.addSubview(picker)
    }
    pickerView = picker
    guard let button = Self.findButton(in: picker) else { return false }
    button.performClick(nil)
    return true
  }

  private static let pickerAnchorSize: CGFloat = 24
  private static let pickerAnchorInset: CGFloat = 56

  private static func findButton(in view: NSView) -> NSButton? {
    for sub in view.subviews {
      if let button = sub as? NSButton { return button }
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
    relay?.stop()
    relay = nil
    generation += 1
  }

  private func emit(_ payload: [String: Any]) {
    eventSink?(payload)
  }
}

func registerForjaAirPlay(_ controller: FlutterViewController) {
  ForjaAirPlayPlugin.register(with: controller.registrar(forPlugin: "ForjaAirPlayPlugin"))
}
