import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var shellChannel: FlutterMethodChannel?
  /// Set after Flutter finishes mpv / engine teardown so terminate can proceed.
  private var allowTerminate = false
  /// True while waiting for Flutter `prepareQuit` after returning `.terminateLater`.
  private var waitingForFlutterQuit = false

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  /// ⌘Q / Quit menu skips `windowShouldClose` / Flutter `onWindowClose`.
  /// Ask Dart to stop media_kit (mpv) first - otherwise demux SIGSEGVs in
  /// `msg_wakeup` while Flutter joins threads during `NSApplication.terminate`.
  override func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    if allowTerminate {
      return .terminateNow
    }
    if waitingForFlutterQuit {
      return .terminateLater
    }
    waitingForFlutterQuit = true
    shellChannel?.invokeMethod("prepareQuit", arguments: nil)
    // Failsafe if Flutter never replies (engine already torn down).
    DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) { [weak self] in
      guard let self, self.waitingForFlutterQuit else { return }
      self.allowTerminate = true
      self.waitingForFlutterQuit = false
      NSApp.reply(toApplicationShouldTerminate: true)
    }
    return .terminateLater
  }

  /// Wire Edit → Find… (⌘F) and quit-ready reply to Flutter.
  func configureShellChannel(with controller: FlutterViewController) {
    shellChannel = FlutterMethodChannel(
      name: "forja.macos/shell",
      binaryMessenger: controller.engine.binaryMessenger
    )
    shellChannel?.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "replyReadyToTerminate":
        self?.finishTerminateAfterFlutterQuit()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    rewireFindMenuItem()
  }

  private func finishTerminateAfterFlutterQuit() {
    allowTerminate = true
    if waitingForFlutterQuit {
      waitingForFlutterQuit = false
      NSApp.reply(toApplicationShouldTerminate: true)
    } else {
      // Red-X path: Flutter already tore down via onWindowClose - terminate now.
      NSApp.terminate(nil)
    }
  }

  @objc func openFind(_ sender: Any?) {
    shellChannel?.invokeMethod("find", arguments: nil)
  }

  private func rewireFindMenuItem() {
    guard let editMenu = NSApp.mainMenu?.items.first(where: {
      $0.title == "Edit" || $0.submenu?.title == "Edit"
    })?.submenu else {
      return
    }

    guard let findSubmenu = editMenu.items.first(where: {
      $0.title == "Find" || $0.submenu?.title == "Find"
    })?.submenu else {
      return
    }

    // Find… is tag 1 with plain ⌘F (not ⌥⌘F Find and Replace).
    let findItem = findSubmenu.items.first(where: { item in
      guard item.keyEquivalent.lowercased() == "f" else { return false }
      let mods = item.keyEquivalentModifierMask
      return mods.contains(.command) && !mods.contains(.option)
    }) ?? findSubmenu.items.first(where: { $0.tag == 1 })

    guard let findItem else { return }

    findItem.target = self
    findItem.action = #selector(openFind(_:))
  }

  @objc func showAboutPanel(_ sender: Any?) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    paragraph.paragraphSpacing = 6

    let body = NSMutableAttributedString(
      string: "Your cinema universe. One app for everything you watch, read, and listen to.\n\n",
      attributes: [
        .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
        .foregroundColor: NSColor.secondaryLabelColor,
        .paragraphStyle: paragraph,
      ]
    )

    body.append(
      NSAttributedString(
        string: "Movies, series & live TV\nMusic, manga & audiobooks\nTorrents, debrid & IPTV\nStremio addons & Jellyfin",
        attributes: [
          .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize - 1),
          .foregroundColor: NSColor.tertiaryLabelColor,
          .paragraphStyle: paragraph,
        ]
      )
    )

    NSApp.orderFrontStandardAboutPanel(
      options: [
        .credits: body,
      ]
    )
  }
}
