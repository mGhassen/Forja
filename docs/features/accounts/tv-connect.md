# Link Android TV

> Sign in on Android TV with a short code or QR — approve on the web portal at `/connect`.

## What it is

Android TV cannot use desktop Web login (no loopback browser). Cold start is a centered welcome (logo, **Your cinema**, **Sign in** / **Continue as guest**) over the animated background, with a soft dark shadow under the copy for readability. Sign in opens the code + QR screen the same way (code under the QR as `XXXX-XXXX`); approve on `/connect`. After a successful link, Forja opens **Who’s watching?** so you can pick a profile — same flow as desktop.

## How to open it

- **Cold start (Android TV):** after the update check, choose **Sign in** or **Continue as guest**.
- **Sign in:** TV shows the link code and QR; approve on the portal.
- **Settings:** open the profile avatar at the bottom of the TV rail → **Profile & account** → **Link with code or QR** when signed out.
- **Web:** open `/connect` (or scan the QR). You must be signed in; otherwise you are sent to login and returned to `/connect` with the code.

## What you can do

- Switch between code and QR on the same screen while the TV waits for approval
- Approve on the portal while signed in
- Continue as guest without linking
- After link: pick a profile on **Who’s watching?** (avatar profile splash). On Android TV the picker and splash use a tighter centered layout than desktop so title, avatars, and loading status fit leanback screens.
- Next cold start (same install): skip link + Who’s watching — open on the last active profile via the logo boot splash. The app refreshes the access token before cloud sync so a stale JWT from the previous day does not fail the boot pull.
- Sign out on TV to return to the link welcome screen
- Revoke the TV session later from Account → Connections (“Forja Android TV”)

## Setup (if needed)

- A Forja account with an email (same as desktop Web login)
- Portal and app pointed at the same Supabase project
- Edge functions deployed: `create-device-link`, `approve-device-link`, `poll-device-link`
- Migration `device_link_codes` applied

## Tips

- Codes expire after about 10 minutes — start again on the TV if needed
- If the TV cannot reach Forja (no network / DNS), **Preparing a code…** fails within ~15s with an error — use **Retry** or **Continue as guest**
- The portal stays signed in; the TV gets a separate session (like desktop Web login)
- Prefer QR so `/connect` opens with the code prefilled

## Related

- [Cloud sync](../settings/cloud-sync.md)
- [Settings overview](../settings/overview.md)
- [Platforms](../getting-started/platforms.md)
