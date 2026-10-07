import Foundation
import Network

/// AirPlay receivers fetch the stream themselves and only show subtitles the
/// HLS stream carries. While a cast runs, this serves a copy of the stream's
/// master playlist with Forja's subtitle added as a WebVTT rendition, on the
/// local network address the receiver can reach. Paths carry a random token.
///
/// Shared by the iOS and macOS Runner targets.
final class ForjaAirPlaySubtitleRelay {
  enum Failure: Error {
    /// The stream is not HLS, so there is no playlist to add a subtitle to.
    case notHls
    case noNetwork
  }

  struct Subtitle {
    let vtt: String
    let name: String
    let language: String?
  }

  static let groupId = "forja-subs"
  private static let fetchTimeout: TimeInterval = 8
  private static let maxRequestBytes = 8192
  /// Placeholder rate for a media playlist wrapped as a single variant.
  private static let wrappedBandwidth = 2_000_000
  private static let mpegurl = "application/vnd.apple.mpegurl"

  private let queue = DispatchQueue(label: "com.forjahq.app.airplay.relay")
  private let token = UUID().uuidString.lowercased()
  private let files: [String: (body: Data, type: String)]
  private var listener: NWListener?

  private init(files: [String: (body: Data, type: String)]) {
    self.files = files
  }

  /// Fetches [source], builds the wrapper and starts serving. Calls back on
  /// the main queue with the master playlist URL on the local network.
  static func start(
    source: URL,
    headers: [String: String],
    subtitle: Subtitle,
    durationSeconds: Double,
    startTimeSeconds: Double,
    completion: @escaping (Result<(ForjaAirPlaySubtitleRelay, URL), Failure>) -> Void
  ) {
    let done: (Result<(ForjaAirPlaySubtitleRelay, URL), Failure>) -> Void = { result in
      DispatchQueue.main.async { completion(result) }
    }
    guard durationSeconds > 0 else {
      done(.failure(.notHls))
      return
    }
    var request = URLRequest(url: source, timeoutInterval: fetchTimeout)
    for (key, value) in headers {
      request.setValue(value, forHTTPHeaderField: key)
    }
    // The session holds its delegate until the fetch finishes.
    PlaylistFetch().start(request) { text, finalURL in
      guard let text else {
        done(.failure(.notHls))
        return
      }
      guard let host = lanAddress() else {
        done(.failure(.noNetwork))
        return
      }
      let master = wrapperMaster(playlist: text, base: finalURL ?? source, subtitle: subtitle)
      let relay = ForjaAirPlaySubtitleRelay(files: [
        "master.m3u8": (Data(master.utf8), mpegurl),
        "subs.m3u8": (Data(subtitlePlaylist(durationSeconds: durationSeconds).utf8), mpegurl),
        "subs.vtt": (
          Data(mappedVtt(subtitle.vtt, startTimeSeconds: startTimeSeconds).utf8),
          "text/vtt; charset=utf-8"
        ),
      ])
      relay.listen { port in
        guard let port, let url = URL(string: "http://\(host):\(port)/\(relay.token)/master.m3u8")
        else {
          relay.stop()
          done(.failure(.noNetwork))
          return
        }
        done(.success((relay, url)))
      }
    }
  }

  func stop() {
    listener?.cancel()
    listener = nil
  }

  // MARK: Playlists

  /// The source master with every variant pointing at our subtitle group.
  /// A media playlist becomes the single variant of a new master.
  static func wrapperMaster(playlist: String, base: URL, subtitle: Subtitle) -> String {
    var media =
      "#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID=\"\(groupId)\",NAME=\"\(attrSafe(subtitle.name))\""
    if let language = subtitle.language.flatMap(languageTag) {
      media += ",LANGUAGE=\"\(attrSafe(language))\""
    }
    media += ",DEFAULT=YES,AUTOSELECT=YES,FORCED=NO,URI=\"subs.m3u8\""

    let lines = playlist.components(separatedBy: .newlines)
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
    let isMaster = lines.contains { $0.hasPrefix("#EXT-X-STREAM-INF") }
    guard isMaster else {
      return [
        "#EXTM3U",
        media,
        "#EXT-X-STREAM-INF:BANDWIDTH=\(wrappedBandwidth),SUBTITLES=\"\(groupId)\"",
        base.absoluteString,
        "",
      ].joined(separator: "\n")
    }

    var out = ["#EXTM3U", media]
    for line in lines {
      if line.isEmpty || line.hasPrefix("#EXTM3U") { continue }
      if line.hasPrefix("#EXT-X-MEDIA:"), line.uppercased().contains("TYPE=SUBTITLES") {
        // Variants now point at our group; the stream's own subtitle groups go.
        continue
      }
      if line.hasPrefix("#EXT-X-STREAM-INF:") {
        out.append(streamInfWithSubtitles(line))
        continue
      }
      if line.hasPrefix("#") {
        out.append(absoluteUriAttribute(line, base: base))
        continue
      }
      out.append(URL(string: line, relativeTo: base)?.absoluteString ?? line)
    }
    out.append("")
    return out.joined(separator: "\n")
  }

  static func subtitlePlaylist(durationSeconds: Double) -> String {
    [
      "#EXTM3U",
      "#EXT-X-VERSION:3",
      "#EXT-X-TARGETDURATION:\(Int(durationSeconds.rounded(.up)))",
      "#EXT-X-MEDIA-SEQUENCE:0",
      "#EXT-X-PLAYLIST-TYPE:VOD",
      String(format: "#EXTINF:%.3f,", durationSeconds),
      "subs.vtt",
      "#EXT-X-ENDLIST",
      "",
    ].joined(separator: "\n")
  }

  /// Cue zero sits at the stream's first timestamp (90 kHz clock).
  static func mappedVtt(_ vtt: String, startTimeSeconds: Double) -> String {
    let ticks = Int64((max(0, startTimeSeconds) * 90_000).rounded())
    let map = "X-TIMESTAMP-MAP=MPEGTS:\(ticks),LOCAL:00:00:00.000"
    var body = Substring(vtt)
    if body.hasPrefix("WEBVTT") {
      body = body.drop { $0 != "\n" }
    }
    return "WEBVTT\n\(map)\(body.hasPrefix("\n") ? "" : "\n")\(body)"
  }

  private static func streamInfWithSubtitles(_ line: String) -> String {
    let colon = line.firstIndex(of: ":")!
    let attrs = splitAttributes(String(line[line.index(after: colon)...]))
      .filter { !$0.uppercased().hasPrefix("SUBTITLES=") }
    return "#EXT-X-STREAM-INF:" + (attrs + ["SUBTITLES=\"\(groupId)\""]).joined(separator: ",")
  }

  /// Attribute list split on commas outside quotes.
  private static func splitAttributes(_ list: String) -> [String] {
    var out: [String] = []
    var current = ""
    var quoted = false
    for ch in list {
      if ch == "\"" { quoted.toggle() }
      if ch == ",", !quoted {
        if !current.isEmpty { out.append(current) }
        current = ""
      } else {
        current.append(ch)
      }
    }
    if !current.isEmpty { out.append(current) }
    return out
  }

  private static func absoluteUriAttribute(_ line: String, base: URL) -> String {
    guard let start = line.range(of: "URI=\""),
      let end = line[start.upperBound...].firstIndex(of: "\"")
    else { return line }
    let raw = String(line[start.upperBound..<end])
    let absolute = URL(string: raw, relativeTo: base)?.absoluteString ?? raw
    return line.replacingCharacters(in: start.upperBound..<end, with: absolute)
  }

  /// RFC 5646 tag for HLS `LANGUAGE` (`eng` → `en`). Nil when unknown.
  private static func languageTag(_ raw: String) -> String? {
    let trimmed = raw.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty, trimmed.lowercased() != "und" else { return nil }
    return Locale.canonicalLanguageIdentifier(from: trimmed).replacingOccurrences(of: "_", with: "-")
  }

  private static func attrSafe(_ value: String) -> String {
    value.replacingOccurrences(of: "\"", with: "'")
      .components(separatedBy: .newlines).joined(separator: " ")
  }

  // MARK: Network

  /// IPv4 address of the Wi-Fi or Ethernet interface (`en*`), `en0` first.
  static func lanAddress() -> String? {
    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
    defer { freeifaddrs(ifaddr) }
    var fallback: String?
    for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
      let ifa = ptr.pointee
      guard let addr = ifa.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) else { continue }
      let flags = Int32(ifa.ifa_flags)
      guard flags & IFF_UP != 0, flags & IFF_RUNNING != 0, flags & IFF_LOOPBACK == 0 else {
        continue
      }
      let name = String(cString: ifa.ifa_name)
      guard name.hasPrefix("en") else { continue }
      var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
      guard
        getnameinfo(
          addr, socklen_t(addr.pointee.sa_len), &host, socklen_t(host.count), nil, 0,
          NI_NUMERICHOST) == 0
      else { continue }
      let ip = String(cString: host)
      if name == "en0" { return ip }
      fallback = fallback ?? ip
    }
    return fallback
  }

  private func listen(_ ready: @escaping (UInt16?) -> Void) {
    guard let listener = try? NWListener(using: .tcp, on: .any) else {
      ready(nil)
      return
    }
    self.listener = listener
    var reported = false
    listener.stateUpdateHandler = { state in
      switch state {
      case .ready:
        if !reported {
          reported = true
          ready(listener.port?.rawValue)
        }
      case .failed, .cancelled:
        if !reported {
          reported = true
          ready(nil)
        }
      default:
        break
      }
    }
    listener.newConnectionHandler = { [weak self] connection in
      guard let self else {
        connection.cancel()
        return
      }
      connection.start(queue: self.queue)
      self.receive(connection, buffer: Data())
    }
    listener.start(queue: queue)
  }

  private func receive(_ connection: NWConnection, buffer: Data) {
    connection.receive(minimumIncompleteLength: 1, maximumLength: Self.maxRequestBytes) {
      [weak self] data, _, complete, error in
      guard let self else {
        connection.cancel()
        return
      }
      var buffer = buffer
      if let data { buffer.append(data) }
      if let end = buffer.range(of: Data("\r\n\r\n".utf8)) {
        self.respond(connection, head: buffer[..<end.lowerBound])
        return
      }
      if error != nil || complete || buffer.count > Self.maxRequestBytes {
        connection.cancel()
        return
      }
      self.receive(connection, buffer: buffer)
    }
  }

  private func respond(_ connection: NWConnection, head: Data) {
    let requestLine = String(decoding: head, as: UTF8.self)
      .components(separatedBy: "\r\n").first ?? ""
    let parts = requestLine.split(separator: " ")
    let method = parts.first.map(String.init) ?? ""
    let path = parts.count > 1 ? String(parts[1]) : ""
    let prefix = "/\(token)/"

    var status = "404 Not Found"
    var body = Data()
    var type = "text/plain"
    if method == "GET" || method == "HEAD", path.hasPrefix(prefix) {
      let name = String(path.dropFirst(prefix.count)).components(separatedBy: "?").first ?? ""
      if let file = files[name] {
        status = "200 OK"
        body = file.body
        type = file.type
      }
    }
    let header =
      "HTTP/1.1 \(status)\r\nContent-Type: \(type)\r\nContent-Length: \(body.count)\r\n"
      + "Cache-Control: no-cache\r\nConnection: close\r\n\r\n"
    var out = Data(header.utf8)
    if method != "HEAD" { out.append(body) }
    connection.send(content: out, completion: .contentProcessed { _ in connection.cancel() })
  }
}

/// Reads a playlist and gives up as soon as the body is not one, so a direct
/// video link is never downloaded.
private final class PlaylistFetch: NSObject, URLSessionDataDelegate {
  private static let maxBytes = 4 << 20
  private static let sniffBytes = 64

  private var data = Data()
  private var session: URLSession?
  private var completion: ((String?, URL?) -> Void)?

  func start(_ request: URLRequest, completion: @escaping (String?, URL?) -> Void) {
    self.completion = completion
    let session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)
    self.session = session
    session.dataTask(with: request).resume()
  }

  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive chunk: Data) {
    data.append(chunk)
    if data.count > Self.maxBytes || Self.notPlaylist(data) {
      dataTask.cancel()
      finish(nil, nil)
    }
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?)
  {
    guard error == nil, let text = String(data: data, encoding: .utf8),
      Self.trimmedHead(text).hasPrefix("#EXTM3U")
    else {
      finish(nil, nil)
      return
    }
    finish(text, task.response?.url)
  }

  private func finish(_ text: String?, _ url: URL?) {
    guard let completion else { return }
    self.completion = nil
    session?.invalidateAndCancel()
    session = nil
    completion(text, url)
  }

  /// True once enough bytes arrived to tell the body is not a playlist.
  private static func notPlaylist(_ data: Data) -> Bool {
    let head = trimmedHead(String(decoding: data.prefix(sniffBytes), as: UTF8.self))
    if head.count >= 7 { return !head.hasPrefix("#EXTM3U") }
    return data.count >= sniffBytes
  }

  private static func trimmedHead(_ text: String) -> String {
    text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(["\u{FEFF}"]))
  }
}
