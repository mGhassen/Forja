import Foundation
import Network

/// Serves a local offline file over LAN so an AirPlay receiver can fetch it.
/// Apple TV cannot open `file://` on the phone; it needs an HTTP URL on Wi-Fi.
/// Paths carry a random token. Range requests are supported for seek.
///
/// Shared by the iOS and macOS Runner targets.
final class ForjaAirPlayLocalFileRelay {
  enum Failure: Error {
    case missingFile
    case noNetwork
  }

  private static let maxRequestBytes = 8192
  private static let chunkBytes = 256 * 1024

  private let queue = DispatchQueue(label: "com.forjahq.app.airplay.local")
  private let token = UUID().uuidString.lowercased()
  private let fileURL: URL
  private let fileLength: UInt64
  private let mediaName: String
  private let mediaType: String
  private var listener: NWListener?

  private init(fileURL: URL, fileLength: UInt64, mediaName: String, mediaType: String) {
    self.fileURL = fileURL
    self.fileLength = fileLength
    self.mediaName = mediaName
    self.mediaType = mediaType
  }

  /// Starts serving [fileURL]. Calls back on the main queue with the LAN HTTP URL.
  static func start(
    fileURL: URL,
    completion: @escaping (Result<(ForjaAirPlayLocalFileRelay, URL), Failure>) -> Void
  ) {
    let done: (Result<(ForjaAirPlayLocalFileRelay, URL), Failure>) -> Void = { result in
      DispatchQueue.main.async { completion(result) }
    }

    let resolved = fileURL.standardizedFileURL
    guard resolved.isFileURL,
      FileManager.default.fileExists(atPath: resolved.path),
      let attrs = try? FileManager.default.attributesOfItem(atPath: resolved.path),
      let length = attrs[.size] as? UInt64, length > 0
    else {
      done(.failure(.missingFile))
      return
    }
    guard let host = ForjaAirPlaySubtitleRelay.lanAddress() else {
      done(.failure(.noNetwork))
      return
    }

    let ext = resolved.pathExtension.lowercased()
    let mediaName = ext.isEmpty ? "media" : "media.\(ext)"
    let relay = ForjaAirPlayLocalFileRelay(
      fileURL: resolved,
      fileLength: length,
      mediaName: mediaName,
      mediaType: mimeType(forExtension: ext)
    )
    relay.listen { port in
      guard let port,
        let url = URL(string: "http://\(host):\(port)/\(relay.token)/\(mediaName)")
      else {
        relay.stop()
        done(.failure(.noNetwork))
        return
      }
      done(.success((relay, url)))
    }
  }

  func stop() {
    listener?.cancel()
    listener = nil
  }

  private static func mimeType(forExtension ext: String) -> String {
    switch ext {
    case "mp4", "m4v", "mov": return "video/mp4"
    case "m3u8": return "application/vnd.apple.mpegurl"
    case "ts", "m2ts": return "video/mp2t"
    case "mp3": return "audio/mpeg"
    case "aac", "m4a": return "audio/mp4"
    case "webm": return "video/webm"
    case "mkv": return "video/x-matroska"
    default: return "application/octet-stream"
    }
  }

  // MARK: Network

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
    let text = String(decoding: head, as: UTF8.self)
    let lines = text.components(separatedBy: "\r\n")
    let requestLine = lines.first ?? ""
    let parts = requestLine.split(separator: " ")
    let method = parts.first.map(String.init) ?? ""
    let path = parts.count > 1 ? String(parts[1]) : ""
    let prefix = "/\(token)/"
    let rangeHeader = lines.first {
      $0.lowercased().hasPrefix("range:")
    }.map { String($0.dropFirst("range:".count)).trimmingCharacters(in: .whitespaces) }

    guard method == "GET" || method == "HEAD", path.hasPrefix(prefix) else {
      sendEmpty(connection, status: "404 Not Found")
      return
    }
    let name = String(path.dropFirst(prefix.count)).components(separatedBy: "?").first ?? ""
    guard name == mediaName else {
      sendEmpty(connection, status: "404 Not Found")
      return
    }
    serveFile(connection, method: method, rangeHeader: rangeHeader)
  }

  private func serveFile(_ connection: NWConnection, method: String, rangeHeader: String?) {
    let total = fileLength
    let headOnly = method == "HEAD"

    if let rangeHeader, let range = parseBytesRange(rangeHeader, total: total) {
      let (start, end) = range
      let length = end - start + 1
      let header =
        "HTTP/1.1 206 Partial Content\r\nContent-Type: \(mediaType)\r\n"
        + "Accept-Ranges: bytes\r\nContent-Length: \(length)\r\n"
        + "Content-Range: bytes \(start)-\(end)/\(total)\r\n"
        + "Cache-Control: no-cache\r\nConnection: close\r\n\r\n"
      if headOnly {
        connection.send(
          content: Data(header.utf8),
          completion: .contentProcessed { _ in connection.cancel() })
        return
      }
      streamFile(connection, header: Data(header.utf8), offset: start, remaining: length)
      return
    }

    let header =
      "HTTP/1.1 200 OK\r\nContent-Type: \(mediaType)\r\n"
      + "Accept-Ranges: bytes\r\nContent-Length: \(total)\r\n"
      + "Cache-Control: no-cache\r\nConnection: close\r\n\r\n"
    if headOnly {
      connection.send(
        content: Data(header.utf8),
        completion: .contentProcessed { _ in connection.cancel() })
      return
    }
    streamFile(connection, header: Data(header.utf8), offset: 0, remaining: total)
  }

  private func streamFile(
    _ connection: NWConnection, header: Data, offset: UInt64, remaining: UInt64
  ) {
    guard let handle = try? FileHandle(forReadingFrom: fileURL) else {
      connection.cancel()
      return
    }
    connection.send(content: header, completion: .contentProcessed { [weak self] error in
      guard let self, error == nil else {
        try? handle.close()
        connection.cancel()
        return
      }
      self.sendChunks(connection, handle: handle, offset: offset, remaining: remaining)
    })
  }

  private func sendChunks(
    _ connection: NWConnection, handle: FileHandle, offset: UInt64, remaining: UInt64
  ) {
    if remaining == 0 {
      try? handle.close()
      connection.cancel()
      return
    }
    do {
      try handle.seek(toOffset: offset)
      let take = min(UInt64(Self.chunkBytes), remaining)
      guard let data = try handle.read(upToCount: Int(take)), !data.isEmpty else {
        try? handle.close()
        connection.cancel()
        return
      }
      let nextOffset = offset + UInt64(data.count)
      let nextRemaining = remaining - UInt64(data.count)
      connection.send(content: data, completion: .contentProcessed { [weak self] error in
        guard let self, error == nil else {
          try? handle.close()
          connection.cancel()
          return
        }
        self.sendChunks(
          connection, handle: handle, offset: nextOffset, remaining: nextRemaining)
      })
    } catch {
      try? handle.close()
      connection.cancel()
    }
  }

  private func sendEmpty(_ connection: NWConnection, status: String) {
    let header =
      "HTTP/1.1 \(status)\r\nContent-Type: text/plain\r\nContent-Length: 0\r\n"
      + "Connection: close\r\n\r\n"
    connection.send(
      content: Data(header.utf8),
      completion: .contentProcessed { _ in connection.cancel() })
  }

  /// Parses `bytes=START-END` / `bytes=START-` / `bytes=-N`. Nil when unusable.
  private func parseBytesRange(_ header: String, total: UInt64) -> (UInt64, UInt64)? {
    let trimmed = header.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.lowercased().hasPrefix("bytes=") else { return nil }
    let spec = String(trimmed.dropFirst("bytes=".count))
    let first = spec.split(separator: ",", maxSplits: 1).first.map(String.init) ?? spec
    let parts = first.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
    guard parts.count == 2 else { return nil }
    let startRaw = String(parts[0])
    let endRaw = String(parts[1])
    if startRaw.isEmpty {
      guard let suffix = UInt64(endRaw), suffix > 0, total > 0 else { return nil }
      let length = min(suffix, total)
      return (total - length, total - 1)
    }
    guard let start = UInt64(startRaw), start < total else { return nil }
    let end: UInt64
    if endRaw.isEmpty {
      end = total - 1
    } else {
      guard let parsed = UInt64(endRaw), parsed >= start else { return nil }
      end = min(parsed, total - 1)
    }
    return (start, end)
  }
}
