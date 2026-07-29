# Picture-in-picture

> Keep watching in a small window while you use other apps or browse the desktop.

## What it is

Forja supports picture-in-picture in the **movie player** and the **IPTV player**.

- **Android** — system PiP (floating OS window). Returning to the app restores full-screen playback.
- **macOS** — compact always-on-top player window that stays on **all Spaces** (and can float over other fullscreen apps). Hover and tap the PiP icon to restore.
- **Windows** — same compact always-on-top window (stays on the current virtual desktop). Hover and tap the PiP icon to restore.

## How to open it

Use the **PiP** button in the player top-right (movie player or IPTV), next to **Player**. Availability is platform-gated (Android phone/tablet, Windows, macOS). **Android TV** does not show Cast or PiP — only **Player**.

## What you can do

- Shrink video to a corner overlay while playback continues
- Resume full screen when leaving PiP (tap the system PiP window on Android, or the hover PiP icon on desktop)
- Continue audio/video while PiP is active (Android phone/tablet or desktop). Leaving Forja for another full-screen app **without** PiP pauses the main player so audio does not keep playing under that app.
- On macOS, switch Mission Control Spaces and keep watching in the same floating window

## Tips

- PiP availability depends on Android version and OEM behavior
- Desktop PiP is Forja’s own compact window (not Apple/Windows system media PiP) — required because playback uses media_kit/mpv
- Linux, iOS, and Android TV do not show the PiP button
- Controls and channel guide hide while IPTV PiP is active

## Related

- [Player](player.md)
- [IPTV — Xtream](../live/iptv-xtream.md)
- [Platforms](../getting-started/platforms.md)
