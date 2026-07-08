import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
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
