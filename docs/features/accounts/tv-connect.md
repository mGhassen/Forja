# Link Android TV

> Sign in on Android TV with a short code or QR — approve on the web portal at `/connect`.

## What it is

Android TV cannot use desktop Web login (no loopback browser). Instead, the TV shows a one-time code and QR. On a phone or computer you open the Forja portal, sign in, enter the code on `/connect`, and the TV receives its own signed-in session. Guest mode remains available.

## How to open it

- **Cold start (Android TV):** after the update check, if you are not signed in, the link screen appears with the code and QR.
- **Settings:** **Profile & account** → **Link with code or QR** (when signed out on Android TV).
- **Web:** open `/connect` (or scan the QR from the TV). You must be signed in; otherwise you are sent to login and returned to `/connect` with the code.

## What you can do

- Show a large TV code and QR that opens `/connect?code=…`
- Approve the code while signed in on the portal
- Continue as guest without linking
- Sign out on TV to return to the link screen
- Revoke the TV session later from Account → Connections (“Forja Android TV”)

## Setup (if needed)

- A Forja account with an email (same as desktop Web login)
- Portal and app pointed at the same Supabase project
- Edge functions deployed: `create-device-link`, `approve-device-link`, `poll-device-link`
- Migration `device_link_codes` applied

## Tips

- Codes expire after about 10 minutes — generate a new one on the TV if needed
- The portal stays signed in; the TV gets a separate session (like desktop Web login)
- Prefer scanning the QR so the code is prefilled on `/connect`

## Related

- [Cloud sync](../settings/cloud-sync.md)
- [Platforms](../getting-started/platforms.md)
