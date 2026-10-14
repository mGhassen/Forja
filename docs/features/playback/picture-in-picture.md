# Picture-in-picture

> Keep watching in a small floating window while you use Forja or other apps.

## What it is

Forja supports picture-in-picture in the **movie player**, the **IPTV player**, and **Live Sports**.

- **Android** — system PiP (floating OS window). Returning to the app restores full-screen playback.
- **macOS / Windows** — a **separate** always-on-top float window plays the video. The main Forja window stays full-size. The player route unlocks so you can browse the shell, with a corner notice: **Playing in picture-in-picture** and **Expand**. Distinct from the [in-app mini player](in-app-mini-player.md) (video stays inside Forja).

## How to open it

- Use the **PiP** button in the player top-right (movie player or IPTV), next to **Player**. Availability is platform-gated (Android phone/tablet, Windows, macOS). **Android TV** does not show Cast or PiP — only **Player**.
- **Desktop auto PiP** (opt-in) — enable **Settings → Playback → Auto picture-in-picture**. While video is playing, switching Mission Control Space (macOS) or a Windows virtual desktop enters the float automatically. Off by default. Exit with **Expand** (restore) or **Close** on hover.

## What you can do

- Keep the main Forja window open and browse while the float plays
- Drag the float freely
- Hover the float: expand (restore full player), Minimize, Close, ±15s seek, play/pause, and scrub (VOD; live IPTV shows play/pause only)
- On macOS, switch Mission Control Spaces and keep watching in the float (auto or manual PiP)

## Tips

- Entering desktop PiP briefly reopens the stream in the float (same exclusive media_kit Player handoff as other engine swaps)
- In-app mini and OS PiP cannot be active at the same time
- PiP availability depends on Android version and OEM behavior
- Auto PiP only fires when the setting is on and playback is actually playing
- **Expand** restores the full player; **Minimize** sends the floating window to the dock/taskbar; **Close** exits playback
- Linux, iOS, and Android TV do not show the PiP button
- Controls and channel guide hide while IPTV PiP is active

## Related

- [Player](player.md)
- [In-app mini player](in-app-mini-player.md)
- [Playback settings](../settings/playback-settings.md)
- [IPTV — Xtream](../live/iptv-xtream.md)
- [Platforms](../getting-started/platforms.md)
