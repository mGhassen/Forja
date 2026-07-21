# WebStreamr extractors

> Resolve embed hosts (FileMoon, DoodStream, VidSrc chain, etc.) into playable URLs.

## What it is

After WebStreamr [sources](webstreamr-sources.md) find embed pages, **extractors** turn host links into actual stream URLs (HLS, MP4, etc.). Forja ships 25 extractors. Some require MediaFlow Proxy (MFP) to bypass host protections.

## Built-in extractors

StreamEmbed · SaveFiles · Dropload · SuperVideo · Vidora · FSST · VixSrc · KinoGer · YouTube · FileMoon* · HubDrive · HubCloud · RGShows · VidSrc · MovieBox · VidZee · Mixdrop* · Streamtape* · Uqload* · DoodStream* · FileLions* · LuluStream* · Fastream* · Voe* · External

\* *Requires MFP — configure in [WebStreamr settings](webstreamr-settings.md)*

## How to open it

Automatic during WebStreamr resolution. Disable specific extractors in **Settings → WebStreamr**.

## What you can do

- Turn off extractors that fail often for you
- Exclude resolutions (e.g. skip 4K) in **Settings → WebStreamr**
- Rely on MFP-backed extractors when you run a MediaFlow Proxy

## Tips

- If many hosts fail, set up MFP URL and password in **Settings → WebStreamr**
- FlareSolverr helps with Cloudflare-protected pages — optional URL in settings

## Related

- [WebStreamr settings](webstreamr-settings.md)
- [WebStreamr sources](webstreamr-sources.md)
