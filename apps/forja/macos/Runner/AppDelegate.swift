import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var shellChannel: FlutterMethodChannel?

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  /// Wire Edit → Find… (⌘F) to Flutter. The stock MainMenu uses
  /// `performFindPanelAction:`, which stays disabled with no NSTextView —
  /// macOS then eats ⌘F and plays the system beep.
  func configureShellChannel(with controller: FlutterViewController) {
    shellChannel = FlutterMethodChannel(
      name: "forja.macos/shell",
      binaryMessenger: controller.engine.binaryMessenger
    )
    rewireFindMenuItem()
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
