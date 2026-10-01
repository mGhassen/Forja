import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var shellChannel: FlutterMethodChannel?
  /// Kept so [applicationDidBecomeActive] can nudge Flutter out of a stale
  /// `hidden` lifecycle (Cmd-Tab freeze — flutter/flutter#155977).
  private weak var flutterViewController: FlutterViewController?
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

  /// Flutter 3.44 still re-sends `hidden` on becomeActive when occlusion
  /// stayed stale after Cmd-Tab (engine `_visible` never flipped back). That
  /// gates frames — UI / video look frozen while the window is frontmost.
  /// Push `resumed` after AppKit becomes active when any window is visible
  /// (same rule as the upstream fix). Remove once Flutter ships #188772.
  override func applicationDidBecomeActive(_ notification: Notification) {
    super.applicationDidBecomeActive(notification)
    nudgeFlutterLifecycleResumedIfVisible()
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
    flutterViewController = controller
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

  /// Framework re-enables frames on `resumed`. Engine may still think we are
  /// hidden; sending the lifecycle string is enough for paint + video textures.
  private func nudgeFlutterLifecycleResumedIfVisible() {
    guard let controller = flutterViewController else { return }
    let anyVisible = NSApp.windows.contains { $0.isVisible && !$0.isMiniaturized }
    guard anyVisible else { return }
    let channel = FlutterBasicMessageChannel(
      name: "flutter/lifecycle",
      binaryMessenger: controller.engine.binaryMessenger,
      codec: FlutterStringCodec.sharedInstance()
    )
    channel.sendMessage("AppLifecycleState.resumed")
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
