# Link Android TV

> Sign in on Android TV or desktop with a short code or QR — approve on the web portal at `/connect`.

## What it is

Cold start on **Android TV and desktop** is the same centered welcome (logo, **Your cinema**, **Sign in** / **Continue as guest**) over the animated background, with a soft dark shadow under the copy for readability. Sign in opens the code + QR screen (code under the QR as `XXXX-XXXX`); approve on `/connect`. After a successful link, Forja opens **Who’s watching?** so you can pick a profile. Desktop email/password, passkey, and Web login are not on this screen (mobile keeps email/password in Settings if you continue as guest; desktop guest **Settings → Profile & account** uses the same code + QR flow).

## How to open it

- **Cold start (desktop and Android TV):** after the update check, choose **Sign in** or **Continue as guest**.
- **Sign in:** the app shows the link code and QR; approve on the portal.
- **Settings (desktop):** profile avatar at the bottom of the rail → **Profile & account** → **Sign in** when signed out (loads code + QR inline).
- **Settings (Android TV):** profile avatar at the bottom of the TV rail → **Profile & account** → **Link with code or QR** when signed out.
- **Web:** open `/connect` (or scan the QR). You must be signed in; otherwise you are sent to login and returned to `/connect` with the code.

## What you can do

- Switch between code and QR on the same screen while the app waits for approval
- On **desktop**, click the QR to open `/connect?code=…` in your browser — if you are already signed in, the portal counts down 5s then approves (Cancel or Link now). On success it shows OK and closes the tab after 5s
- Approve on the portal while signed in
- Continue as guest without linking
- After link: pick a profile on **Who’s watching?** (avatar profile splash). On Android TV the picker and splash use a tighter centered layout than desktop so title, avatars, and loading status fit leanback screens.
- After the first profile is active, if the profile is not yet **onboarded**, Forja shows a **packs** step: install the official ForjaHQ pack bundle, browse Community Packs (`https://www.forjahq.xyz/plugins`), or **Skip for now**. Skipping or installing marks the profile onboarded (synced) so the step does not return. Restored sessions with a missing onboarded flag (upgrades) get the same step once.
- **Continue as guest** uses the same packs step on this device (local flag only — not synced). Once skipped or installed, later guest cold starts skip it.
- Next cold start (same install, already onboarded): skip link + Who’s watching + packs — open on the last active profile via the logo boot splash. The app refreshes the access token before cloud sync so a stale JWT from the previous day does not fail the boot pull.
- Sign out on desktop or TV to return to the link welcome screen
- Revoke the device-link session later from Account → Connections (“Forja Android TV”)

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
