# Subtitles

> Find, style, and sync subtitles while you watch.

## What it is

The player fetches subtitles from multiple sources in parallel — APIs (Wyzie, Levrx), [subtitle scrapers](../scrapers/subtitle-scrapers.md), and Stremio subtitle addons. Pick a track, adjust size, color, font, opacity, and delay. ASS/SSA subtitles render with native styling via libass.

## How to open it

During playback, tap the **Subtitles** icon in the bottom control bar. Languages open in a floating panel; tap a language to see individual tracks (with source name, e.g. opensubtitles).

## What you can do

- Floating subtitle picker: Off, embedded in-stream tracks (when the file has them), load from file, then online languages with track counts; drill into a language for specific files. Language names use native script (e.g. العربية, Français, தமிழ்)
- Enable, disable, or switch tracks
- Change appearance (size, color, font, opacity)
- Adjust sync delay if dialogue is early/late
- Use advanced ASS/SSA rendering for styled subs
- **Preferred language sticks across episodes** — picking French (or any category) remembers it; the next episode auto-selects the same language when available, otherwise **English**. **Off** clears the preference

## Tips

- Subtitle search works best when the title and year match TMDB metadata
- Stremio subtitle addons require IMDB id and installed addons with a subtitles resource

## Related

- [Subtitle scrapers](../scrapers/subtitle-scrapers.md)
- [Player](player.md)
- [Playback settings](../settings/playback-settings.md)
- [Stremio addons](../sources/stremio-addons.md)
