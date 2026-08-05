# Subtitles

> Find, style, and sync subtitles while you watch.

## What it is

The player fetches subtitles from multiple sources in parallel — APIs (Wyzie, Levrx), [subtitle scrapers](../scrapers/subtitle-scrapers.md), and Stremio subtitle addons — and **merges them with tracks from the stream you are playing** (provider / KissKh / Videasy sideloads) into one language list. Pick a track, adjust size, color, font, opacity, and delay. ASS/SSA subtitles render with native styling via libass (**MediaKit** only). On **Android ExoPlayer** (default on phone and Android TV), SRT/VTT work for online search, provider sideloads (including local Asian Drama tracks), and **Load from file**; appearance sliders and ASS styling stay on MediaKit.

## How to open it

During playback, tap the **Subtitles** icon in the bottom control bar. Languages open in a floating panel; tap a language to see individual tracks (with source name, e.g. opensubtitles).

## What you can do

- Floating subtitle picker: on **MediaKit**, Off, embedded in-stream tracks, **Load from file**, then online language folders (drill-in). On **ExoPlayer**, a two-column dialog like Sources — left = groups (Off, In-stream, languages, Load from file); right = tracks inside the selected group. Tapping **Off** turns subtitles off immediately (no second tap). Language names use native script (e.g. العربية, Français, தமிழ்)
- Enable, disable, or switch tracks
- Change appearance (size, color, font, opacity, position) — tune icon next to Close in the Subtitles header on **MediaKit** and **ExoPlayer**. On **TV**, focus a slider and use **Left/Right** to adjust (no OK first). Sync **delay** applies on MediaKit only
- Adjust sync delay if dialogue is early/late (MediaKit)
- Use advanced ASS/SSA rendering for styled subs (MediaKit)
- **Preferred language sticks across episodes** — picking French (or any category) remembers it; the next episode auto-selects the same language when available, otherwise **English**. **Off** clears the preference

## Tips

- Stream tracks and Wyzie/online tracks share one language folder (English, Français, …) — open the folder to see both sources
- Anime / Asian Drama still search by title (SubtitleCat / MySubs); Wyzie needs a real TMDB id (movies / TV)
- Subtitle search works best when the title and year match TMDB metadata
- Stremio subtitle addons require IMDB id and installed addons with a subtitles resource

## Related

- [Subtitle scrapers](../scrapers/subtitle-scrapers.md)
- [Player](player.md)
- [Playback settings](../settings/playback-settings.md)
- [Stremio addons](../sources/stremio-addons.md)
