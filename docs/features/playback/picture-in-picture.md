# Picture-in-picture

> Keep watching in a small window while you use other apps or browse the desktop.

## What it is

Forja supports picture-in-picture in the **movie player** and the **IPTV player**.

- **Android** — system PiP (floating OS window). Returning to the app restores full-screen playback.
- **macOS** — compact floating player (rounded, shadowed, always-on-top, all Spaces). Drag freely (no corner snap). Hover for play/pause and restore. Opted out of Magnet/Rectangle so tiling apps do not steal the drag.
- **Windows** — same compact always-on-top window with free drag. Hover for play/pause and restore.

## How to open it

- Use the **PiP** button in the player top-right (movie player or IPTV), next to **Player**. Availability is platform-gated (Android phone/tablet, Windows, macOS). **Android TV** does not show Cast or PiP — only **Player**.
- **Desktop auto PiP** — while video is playing, switching Mission Control Space (macOS) enters PiP automatically and the window follows you across Spaces. On Windows, switching virtual desktop also enters PiP (the compact window stays on the desktop you left — OS limit). Exit with the hover restore control.

## What you can do

- Shrink video to a corner overlay while playback continues
- Drag freely anywhere on screen
- Hover: play/pause or restore full player
- Continue audio/video while PiP is active (Android phone/tablet or desktop). Leaving Forja for another full-screen app **without** PiP pauses the main player so audio does not keep playing under that app.
- On macOS, switch Mission Control Spaces and keep watching in the same floating window (auto or manual PiP)

## Tips

- PiP availability depends on Android version and OEM behavior
- Desktop PiP is Forja’s own compact window (not Apple/Windows system media PiP) — required because playback uses media_kit/mpv. Title-bar chrome is applied by the native PiP channel, not by flipping window_manager title-bar style after the window is borderless
- Auto PiP only fires when playback is actually playing (paused video stays on the Space you left)
- Linux, iOS, and Android TV do not show the PiP button
- Controls and channel guide hide while IPTV PiP is active

## Related

- [Player](player.md)
- [IPTV — Xtream](../live/iptv-xtream.md)
- [Platforms](../getting-started/platforms.md)
