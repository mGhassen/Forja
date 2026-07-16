globalThis.__nitro_main__ = import.meta.url;
import { a as toEventHandler, c as serve, i as defineLazyEventHandler, n as HTTPError, r as defineHandler, s as NodeResponse, t as H3Core } from "./_libs/h3+rou3+srvx.mjs";
import { i as withoutTrailingSlash, n as joinURL, r as withLeadingSlash, t as decodePath } from "./_libs/ufo.mjs";
import { promises } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";
//#region node_modules/.pnpm/nitro@3.0.260610-beta_chokidar@5.0.0_jiti@2.7.0_vite@8.1.5_@types+node@24.13.3_jiti@2.7.0_/node_modules/nitro/dist/runtime/internal/route-rules.mjs
var headers = ((m) => function headersRouteRule(event) {
	for (const [key, value] of Object.entries(m.options || {})) event.res.headers.set(key, value);
});
//#endregion
//#region #nitro/virtual/public-assets-data
var public_assets_data_default = {
	"/icons.svg": {
		"type": "image/svg+xml",
		"etag": "\"13a7-+Yl6wl4T3p6mAdLxrF2TU9++/No\"",
		"mtime": "2026-07-16T19:11:04.326Z",
		"size": 5031,
		"path": "../public/icons.svg"
	},
	"/assets/account.settings-DuhBYmQw.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"168-mPCp9Ejc5gQFC27+9O6i+cauyyc\"",
		"mtime": "2026-07-16T19:11:03.980Z",
		"size": 360,
		"path": "../public/assets/account.settings-DuhBYmQw.js"
	},
	"/assets/account.settings.playback-BJqLhBR_.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"111e-r8BZYVaLWyYK8jkre19EtBy6sl0\"",
		"mtime": "2026-07-16T19:11:03.980Z",
		"size": 4382,
		"path": "../public/assets/account.settings.playback-BJqLhBR_.js"
	},
	"/assets/arrow-left-C5eU-WxK.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"a1-Kr978zvvB1AlZEi/TQgSuorALFI\"",
		"mtime": "2026-07-16T19:11:03.980Z",
		"size": 161,
		"path": "../public/assets/arrow-left-C5eU-WxK.js"
	},
	"/assets/account-ZAhYyJHV.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"ca7-6sblpy9y2xuH038QgCzTNtrNJvw\"",
		"mtime": "2026-07-16T19:11:03.979Z",
		"size": 3239,
		"path": "../public/assets/account-ZAhYyJHV.js"
	},
	"/assets/account.settings.stremio-CLiCNcXV.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"9e5-9D7oj0So5U9bnQucP6kg9xLapqs\"",
		"mtime": "2026-07-16T19:11:03.980Z",
		"size": 2533,
		"path": "../public/assets/account.settings.stremio-CLiCNcXV.js"
	},
	"/assets/button-DGZk17KR.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"f1f-/jhDsXQAP4Ec4IKaZb+ECA9jhcI\"",
		"mtime": "2026-07-16T19:11:03.980Z",
		"size": 3871,
		"path": "../public/assets/button-DGZk17KR.js"
	},
	"/assets/download-D3I6yYxn.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"7773-sK/kLVY3Nt3aLNexIB/Ulj5jBkA\"",
		"mtime": "2026-07-16T19:11:03.981Z",
		"size": 30579,
		"path": "../public/assets/download-D3I6yYxn.js"
	},
	"/assets/index-DSWeXeu8.css": {
		"type": "text/css; charset=utf-8",
		"etag": "\"12986-J0whgT7kYHROLOI+x8z6MQPisqU\"",
		"mtime": "2026-07-16T19:11:03.984Z",
		"size": 76166,
		"path": "../public/assets/index-DSWeXeu8.css"
	},
	"/assets/iptv-B9u3H1NC.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"2f96-tGBfil7shOq5+rrGf7i4BaPjt6c\"",
		"mtime": "2026-07-16T19:11:03.981Z",
		"size": 12182,
		"path": "../public/assets/iptv-B9u3H1NC.js"
	},
	"/assets/label-DV-3ptEx.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"3bd-J1Nk18xZUwX0inB/vBn16ycs+Ak\"",
		"mtime": "2026-07-16T19:11:03.981Z",
		"size": 957,
		"path": "../public/assets/label-DV-3ptEx.js"
	},
	"/assets/legal-shell-DgPlSO61.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"14e6-Pct9mMhsQOZMq+DClnXDV8BCmPw\"",
		"mtime": "2026-07-16T19:11:03.981Z",
		"size": 5350,
		"path": "../public/assets/legal-shell-DgPlSO61.js"
	},
	"/assets/account.settings.iptv-E7f5gCF5.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"1a62-fKusnfzXv0rRJtWnxm31RHWhCG8\"",
		"mtime": "2026-07-16T19:11:03.980Z",
		"size": 6754,
		"path": "../public/assets/account.settings.iptv-E7f5gCF5.js"
	},
	"/assets/input-CH-WIxgr.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"20c-WsrfPkALgKj3yZ5JRiUCKqxG1Jc\"",
		"mtime": "2026-07-16T19:11:03.981Z",
		"size": 524,
		"path": "../public/assets/input-CH-WIxgr.js"
	},
	"/assets/login-B8I7ItIx.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"2535-XUIS52jdDGIgY7ZLMePKZbEueAY\"",
		"mtime": "2026-07-16T19:11:03.981Z",
		"size": 9525,
		"path": "../public/assets/login-B8I7ItIx.js"
	},
	"/assets/require-auth-DIBNmGQ9.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"678-ug0X6HQt0TKU97NuNcMDRms7PwM\"",
		"mtime": "2026-07-16T19:11:03.981Z",
		"size": 1656,
		"path": "../public/assets/require-auth-DIBNmGQ9.js"
	},
	"/assets/reveal--fzjaaHB.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"2b9-yF2FiEBv77dOPEqL6MYnabTKd2c\"",
		"mtime": "2026-07-16T19:11:03.981Z",
		"size": 697,
		"path": "../public/assets/reveal--fzjaaHB.js"
	},
	"/assets/routes-0Neea8aS.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"682c-uc7RaoeW3C+NxCDM/kmGY3VFoYU\"",
		"mtime": "2026-07-16T19:11:03.981Z",
		"size": 26668,
		"path": "../public/assets/routes-0Neea8aS.js"
	},
	"/assets/signup-BiEQWuZO.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"60c-YcLjBIi5VomcNlzO60r33HVjGX4\"",
		"mtime": "2026-07-16T19:11:03.981Z",
		"size": 1548,
		"path": "../public/assets/signup-BiEQWuZO.js"
	},
	"/assets/account.settings.providers-DwVU9crM.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"b22-yWqSpQLHXMwaU/TPYygQe1wLSoc\"",
		"mtime": "2026-07-16T19:11:03.980Z",
		"size": 2850,
		"path": "../public/assets/account.settings.providers-DwVU9crM.js"
	},
	"/assets/index-B0UYbSTO.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"830e3-M9yfp1aJXOdx7CuA2WI66dVJrPI\"",
		"mtime": "2026-07-16T19:11:03.979Z",
		"size": 536803,
		"path": "../public/assets/index-B0UYbSTO.js"
	},
	"/assets/site-header-DIvQc1RT.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"866c-15UHzaw3ELiZdqNh3mdqVKnJdmE\"",
		"mtime": "2026-07-16T19:11:03.982Z",
		"size": 34412,
		"path": "../public/assets/site-header-DIvQc1RT.js"
	},
	"/favicon.svg": {
		"type": "image/svg+xml",
		"etag": "\"2532-P1u486agW3ymimJYHS3VvIiBLK8\"",
		"mtime": "2026-07-16T19:11:04.326Z",
		"size": 9522,
		"path": "../public/favicon.svg"
	},
	"/assets/dmca-DvpNWY3x.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"107d-wzAGwziNrA24GSIh7tfQufsO/X0\"",
		"mtime": "2026-07-16T19:11:03.981Z",
		"size": 4221,
		"path": "../public/assets/dmca-DvpNWY3x.js"
	},
	"/assets/account.profiles-hPqYwDGD.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"13fb-jM5t2IGzqf+drcowS+Lc9hekBCA\"",
		"mtime": "2026-07-16T19:11:03.979Z",
		"size": 5115,
		"path": "../public/assets/account.profiles-hPqYwDGD.js"
	},
	"/assets/terms-Dux-xPra.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"ebd-JMNOGbNOysPKMIIKZp7T8yUmjpg\"",
		"mtime": "2026-07-16T19:11:03.983Z",
		"size": 3773,
		"path": "../public/assets/terms-Dux-xPra.js"
	},
	"/assets/sync-domains-CJ59McdJ.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"1e21-KYF8rwYE+mB8lcjfh4kNzXlF2ZU\"",
		"mtime": "2026-07-16T19:11:03.983Z",
		"size": 7713,
		"path": "../public/assets/sync-domains-CJ59McdJ.js"
	},
	"/assets/trash-2-C-bIGUDO.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"144-nuZ9upwGjjm+YSpUOpIGWKKyqpA\"",
		"mtime": "2026-07-16T19:11:03.983Z",
		"size": 324,
		"path": "../public/assets/trash-2-C-bIGUDO.js"
	},
	"/assets/useRouterState-dD2QYZ3L.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"aa-hugmp+59vWB6h+F+XC4SIzXxFDQ\"",
		"mtime": "2026-07-16T19:11:03.983Z",
		"size": 170,
		"path": "../public/assets/useRouterState-dD2QYZ3L.js"
	},
	"/assets/user-round-CqcS9fDp.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"b2-66/fjidEwJo9FU4VO0B+g9qdr7s\"",
		"mtime": "2026-07-16T19:11:03.983Z",
		"size": 178,
		"path": "../public/assets/user-round-CqcS9fDp.js"
	},
	"/assets/users-ClPeFYVH.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"12e-gcetto/XC4kJCHXrjA3P0CiMOiM\"",
		"mtime": "2026-07-16T19:11:03.984Z",
		"size": 302,
		"path": "../public/assets/users-ClPeFYVH.js"
	},
	"/assets/useMatch-CcToMSxM.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"6d97-4DNQJuKnBpctrJfHYFC3uVB/BEU\"",
		"mtime": "2026-07-16T19:11:03.983Z",
		"size": 28055,
		"path": "../public/assets/useMatch-CcToMSxM.js"
	},
	"/brand/forja-home-hero.jpg": {
		"type": "image/jpeg",
		"etag": "\"1d200-L0+Oz9HhdCpAp22rWckVFZgcmF0\"",
		"mtime": "2026-07-16T19:11:04.298Z",
		"size": 119296,
		"path": "../public/brand/forja-home-hero.jpg"
	},
	"/brand/forja-iptv-live.jpg": {
		"type": "image/jpeg",
		"etag": "\"242fa-VRunXGeKGlrqDyndnFDdGDB3IqM\"",
		"mtime": "2026-07-16T19:11:04.301Z",
		"size": 148218,
		"path": "../public/brand/forja-iptv-live.jpg"
	},
	"/brand/logo-dark.svg": {
		"type": "image/svg+xml",
		"etag": "\"623-o1Ih6F3W8f02vYigcZnwJkqjztE\"",
		"mtime": "2026-07-16T19:11:04.297Z",
		"size": 1571,
		"path": "../public/brand/logo-dark.svg"
	},
	"/brand/forja-iptv-desk.png": {
		"type": "image/png",
		"etag": "\"21af3-bnH1Edco6A+mnCLhYuopw3UNeUo\"",
		"mtime": "2026-07-16T19:11:04.300Z",
		"size": 137971,
		"path": "../public/brand/forja-iptv-desk.png"
	},
	"/brand/logo-light.svg": {
		"type": "image/svg+xml",
		"etag": "\"623-UE2GWyGrSadl1OAEPjm5EqQDdm8\"",
		"mtime": "2026-07-16T19:11:04.297Z",
		"size": 1571,
		"path": "../public/brand/logo-light.svg"
	},
	"/brand/help/macos-blocked-dialog.png": {
		"type": "image/png",
		"etag": "\"4234-ETu0ipjh2/XmNE3rGNv6w/dufp8\"",
		"mtime": "2026-07-16T19:11:04.297Z",
		"size": 16948,
		"path": "../public/brand/help/macos-blocked-dialog.png"
	},
	"/brand/forja-iptv-player.png": {
		"type": "image/png",
		"etag": "\"329e7-c/HMqC+n4Jp7FG1tZXnfHta3w/w\"",
		"mtime": "2026-07-16T19:11:04.300Z",
		"size": 207335,
		"path": "../public/brand/forja-iptv-player.png"
	},
	"/brand/help/windows-01-protected.png": {
		"type": "image/png",
		"etag": "\"8e2a-SpbOVK5Mey9lOts+NEEJckGzQ8E\"",
		"mtime": "2026-07-16T19:11:04.304Z",
		"size": 36394,
		"path": "../public/brand/help/windows-01-protected.png"
	},
	"/brand/help/macos-open-anyway-closeup.png": {
		"type": "image/png",
		"etag": "\"1b4fc-uRjEpWMzSGjW8a6YwWXA/v4+mog\"",
		"mtime": "2026-07-16T19:11:04.304Z",
		"size": 111868,
		"path": "../public/brand/help/macos-open-anyway-closeup.png"
	},
	"/brand/help/macos-privacy-open-anyway.png": {
		"type": "image/png",
		"etag": "\"13580-w52cWA6uCk5Effy9vmN6J6U0smk\"",
		"mtime": "2026-07-16T19:11:04.301Z",
		"size": 79232,
		"path": "../public/brand/help/macos-privacy-open-anyway.png"
	},
	"/brand/help/windows-02-more-info.png": {
		"type": "image/png",
		"etag": "\"55b5-5ZeYmjqvpBvc8A+DbeaTs4xTCEM\"",
		"mtime": "2026-07-16T19:11:04.304Z",
		"size": 21941,
		"path": "../public/brand/help/windows-02-more-info.png"
	},
	"/brand/help/macos-privacy-settings-top.png": {
		"type": "image/png",
		"etag": "\"20ade-UMf43poWGfxcQi1um7ppqpucbBY\"",
		"mtime": "2026-07-16T19:11:04.301Z",
		"size": 133854,
		"path": "../public/brand/help/macos-privacy-settings-top.png"
	},
	"/brand/help/windows-03-run-anyway.jpg": {
		"type": "image/jpeg",
		"etag": "\"12091-AALsao5OU43TsYsOoJagkdi8oEU\"",
		"mtime": "2026-07-16T19:11:04.302Z",
		"size": 73873,
		"path": "../public/brand/help/windows-03-run-anyway.jpg"
	},
	"/brand/open-films/big-buck-bunny.jpg": {
		"type": "image/jpeg",
		"etag": "\"ea1c-RJKu639IVTbZwVNOaOVb22Jj9mg\"",
		"mtime": "2026-07-16T19:11:04.310Z",
		"size": 59932,
		"path": "../public/brand/open-films/big-buck-bunny.jpg"
	},
	"/brand/open-films/ATTRIBUTION.txt": {
		"type": "text/plain; charset=utf-8",
		"etag": "\"393-xPruSu6qRlhGu+TAtC5Ewf2eRQ8\"",
		"mtime": "2026-07-16T19:11:04.296Z",
		"size": 915,
		"path": "../public/brand/open-films/ATTRIBUTION.txt"
	},
	"/brand/help/windows-05-red-unsafe.png": {
		"type": "image/png",
		"etag": "\"1363e-x3DL0x7BPVf8VDKT/lNw937VqtI\"",
		"mtime": "2026-07-16T19:11:04.310Z",
		"size": 79422,
		"path": "../public/brand/help/windows-05-red-unsafe.png"
	},
	"/brand/help/windows-04-on-desktop.jpg": {
		"type": "image/jpeg",
		"etag": "\"10063-Z44z7pPn+b6ftqouM1y7QnZasPo\"",
		"mtime": "2026-07-16T19:11:04.306Z",
		"size": 65635,
		"path": "../public/brand/help/windows-04-on-desktop.jpg"
	},
	"/brand/open-films/cosmos-laundromat.jpg": {
		"type": "image/jpeg",
		"etag": "\"30f02-FE+8w6lMr2TCfsXtx02x77pFj9o\"",
		"mtime": "2026-07-16T19:11:04.311Z",
		"size": 200450,
		"path": "../public/brand/open-films/cosmos-laundromat.jpg"
	},
	"/brand/open-films/sintel.jpg": {
		"type": "image/jpeg",
		"etag": "\"401f4-Y8JbpchdsJvC82z77RyJhPAMB0A\"",
		"mtime": "2026-07-16T19:11:04.313Z",
		"size": 262644,
		"path": "../public/brand/open-films/sintel.jpg"
	},
	"/brand/open-films/sprite-fright.jpg": {
		"type": "image/jpeg",
		"etag": "\"39f14-koYWpeks1jRbq4TSnLa/nnB8vNw\"",
		"mtime": "2026-07-16T19:11:04.314Z",
		"size": 237332,
		"path": "../public/brand/open-films/sprite-fright.jpg"
	},
	"/brand/hubs/tv/cbs.svg": {
		"type": "image/svg+xml",
		"etag": "\"1e4-AGhT51/0TlhHxScPHImbHAdUvVE\"",
		"mtime": "2026-07-16T19:11:04.325Z",
		"size": 484,
		"path": "../public/brand/hubs/tv/cbs.svg"
	},
	"/brand/hubs/tv/cnn.svg": {
		"type": "image/svg+xml",
		"etag": "\"5e8-q6GRN+oI8JdOGOGqeNsBRNllCCI\"",
		"mtime": "2026-07-16T19:11:04.325Z",
		"size": 1512,
		"path": "../public/brand/hubs/tv/cnn.svg"
	},
	"/brand/open-films/tears-of-steel.jpg": {
		"type": "image/jpeg",
		"etag": "\"20900-zDdyo5RecJkH+9VrLP2tmg1jFgw\"",
		"mtime": "2026-07-16T19:11:04.314Z",
		"size": 133376,
		"path": "../public/brand/open-films/tears-of-steel.jpg"
	},
	"/brand/hubs/tv/fox.svg": {
		"type": "image/svg+xml",
		"etag": "\"1d2-at+SHOWApDfW1BXkm22BV8W+Ioo\"",
		"mtime": "2026-07-16T19:11:04.325Z",
		"size": 466,
		"path": "../public/brand/hubs/tv/fox.svg"
	},
	"/brand/hubs/tv/hbo.svg": {
		"type": "image/svg+xml",
		"etag": "\"309-pqV4IzE3FtqrNYdzbDK+0fot5L0\"",
		"mtime": "2026-07-16T19:11:04.325Z",
		"size": 777,
		"path": "../public/brand/hubs/tv/hbo.svg"
	},
	"/brand/hubs/tv/nbc.svg": {
		"type": "image/svg+xml",
		"etag": "\"425-pAgrUtyFWNid0iUExBTA3aOdGf0\"",
		"mtime": "2026-07-16T19:11:04.326Z",
		"size": 1061,
		"path": "../public/brand/hubs/tv/nbc.svg"
	},
	"/brand/hubs/tv/sky.svg": {
		"type": "image/svg+xml",
		"etag": "\"416-0yi3whBAwbvz05E/VcP+UIj3ES0\"",
		"mtime": "2026-07-16T19:11:04.326Z",
		"size": 1046,
		"path": "../public/brand/hubs/tv/sky.svg"
	},
	"/brand/open-films/heroes/sintel-hero.jpg": {
		"type": "image/jpeg",
		"etag": "\"13a2b-05X9ixqlMQsH9Ltv0Qv2JgtVFjY\"",
		"mtime": "2026-07-16T19:11:04.318Z",
		"size": 80427,
		"path": "../public/brand/open-films/heroes/sintel-hero.jpg"
	},
	"/brand/open-films/heroes/cosmos-laundromat-hero.jpg": {
		"type": "image/jpeg",
		"etag": "\"31149-bY1Lk1yErAAF6Oxv3ap35bmdZjY\"",
		"mtime": "2026-07-16T19:11:04.320Z",
		"size": 201033,
		"path": "../public/brand/open-films/heroes/cosmos-laundromat-hero.jpg"
	},
	"/brand/hubs/sport/basketball.jpg": {
		"type": "image/jpeg",
		"etag": "\"a963-khkeFZ4+DAwun0r7EB5dyNJh4Lc\"",
		"mtime": "2026-07-16T19:11:04.325Z",
		"size": 43363,
		"path": "../public/brand/hubs/sport/basketball.jpg"
	},
	"/brand/open-films/heroes/big-buck-bunny-hero.jpg": {
		"type": "image/jpeg",
		"etag": "\"4e17f-lU3IkVnLsrEZ9w3oKmX+eGpg1vM\"",
		"mtime": "2026-07-16T19:11:04.300Z",
		"size": 319871,
		"path": "../public/brand/open-films/heroes/big-buck-bunny-hero.jpg"
	},
	"/brand/open-films/heroes/sprite-fright-hero.jpg": {
		"type": "image/jpeg",
		"etag": "\"4a3c9-xsz23TXZsi0RkktQSH82lw3h74s\"",
		"mtime": "2026-07-16T19:11:04.325Z",
		"size": 304073,
		"path": "../public/brand/open-films/heroes/sprite-fright-hero.jpg"
	},
	"/brand/hubs/sport/football.jpg": {
		"type": "image/jpeg",
		"etag": "\"fd7d-jNk5DatZs4RNlhyG1H/d+qRinCs\"",
		"mtime": "2026-07-16T19:11:04.326Z",
		"size": 64893,
		"path": "../public/brand/hubs/sport/football.jpg"
	},
	"/brand/open-films/heroes/tears-of-steel-hero.jpg": {
		"type": "image/jpeg",
		"etag": "\"3ac39-dEFQSuCa+Pnc+pjRT7rEenyxJT0\"",
		"mtime": "2026-07-16T19:11:04.320Z",
		"size": 240697,
		"path": "../public/brand/open-films/heroes/tears-of-steel-hero.jpg"
	},
	"/brand/hubs/sport/racing.jpg": {
		"type": "image/jpeg",
		"etag": "\"13a2f-QqmneUjZh+5YdFrEcm0KQCH8jUs\"",
		"mtime": "2026-07-16T19:11:04.325Z",
		"size": 80431,
		"path": "../public/brand/hubs/sport/racing.jpg"
	},
	"/brand/hubs/sport/tennis.jpg": {
		"type": "image/jpeg",
		"etag": "\"141bc-kIDMETjdQlwHQ/HaXGKtY3vRorE\"",
		"mtime": "2026-07-16T19:11:04.328Z",
		"size": 82364,
		"path": "../public/brand/hubs/sport/tennis.jpg"
	}
};
//#endregion
//#region #nitro/virtual/public-assets-node
function readAsset(id) {
	const serverDir = dirname(fileURLToPath(globalThis.__nitro_main__));
	return promises.readFile(resolve(serverDir, public_assets_data_default[id].path));
}
//#endregion
//#region #nitro/virtual/public-assets
var publicAssetBases = {};
function isPublicAssetURL(id = "") {
	if (public_assets_data_default[id]) return true;
	for (const base in publicAssetBases) if (id.startsWith(base)) return true;
	return false;
}
function getAsset(id) {
	return public_assets_data_default[id];
}
//#endregion
//#region node_modules/.pnpm/nitro@3.0.260610-beta_chokidar@5.0.0_jiti@2.7.0_vite@8.1.5_@types+node@24.13.3_jiti@2.7.0_/node_modules/nitro/dist/runtime/internal/static.mjs
var METHODS = /* @__PURE__ */ new Set(["HEAD", "GET"]);
var EncodingMap = {
	gzip: ".gz",
	br: ".br",
	zstd: ".zst"
};
var static_default = defineHandler((event) => {
	if (event.req.method && !METHODS.has(event.req.method)) return;
	let id = decodePath(withLeadingSlash(withoutTrailingSlash(event.url.pathname)));
	let asset;
	const encodings = [...(event.req.headers.get("accept-encoding") || "").split(",").map((e) => EncodingMap[e.trim()]).filter(Boolean).sort(), ""];
	for (const encoding of encodings) for (const _id of [id + encoding, joinURL(id, "index.html" + encoding)]) {
		const _asset = getAsset(_id);
		if (_asset) {
			asset = _asset;
			id = _id;
			break;
		}
	}
	if (!asset) {
		if (isPublicAssetURL(id)) {
			event.res.headers.delete("Cache-Control");
			throw new HTTPError({ status: 404 });
		}
		return;
	}
	if (encodings.length > 1) event.res.headers.append("Vary", "Accept-Encoding");
	if (event.req.headers.get("if-none-match") === asset.etag) {
		event.res.status = 304;
		event.res.statusText = "Not Modified";
		return "";
	}
	const ifModifiedSinceH = event.req.headers.get("if-modified-since");
	const mtimeDate = new Date(asset.mtime);
	if (ifModifiedSinceH && asset.mtime && new Date(ifModifiedSinceH) >= mtimeDate) {
		event.res.status = 304;
		event.res.statusText = "Not Modified";
		return "";
	}
	if (asset.type) event.res.headers.set("Content-Type", asset.type);
	if (asset.etag && !event.res.headers.has("ETag")) event.res.headers.set("ETag", asset.etag);
	if (asset.mtime && !event.res.headers.has("Last-Modified")) event.res.headers.set("Last-Modified", mtimeDate.toUTCString());
	if (asset.encoding && !event.res.headers.has("Content-Encoding")) event.res.headers.set("Content-Encoding", asset.encoding);
	if (asset.size > 0 && !event.res.headers.has("Content-Length")) event.res.headers.set("Content-Length", asset.size.toString());
	return readAsset(id);
});
//#endregion
//#region #nitro/virtual/routing
var findRouteRules = /* @__PURE__ */ (() => {
	const $0 = [{
		name: "headers",
		route: "/assets/**",
		handler: headers,
		options: { "cache-control": "public, max-age=31536000, immutable" }
	}];
	return (m, p) => {
		let r = [];
		if (p.charCodeAt(p.length - 1) === 47) p = p.slice(0, -1) || "/";
		let s = p.split("/");
		if (s.length > 1) {
			if (s[1] === "assets") r.unshift({
				data: $0,
				params: { "_": s.slice(2).join("/") }
			});
		}
		return r;
	};
})();
var _lazy_BCmKrJ = defineLazyEventHandler(() => import("./_chunks/ssr-renderer.mjs"));
var findRoute = /* @__PURE__ */ (() => {
	const data = {
		route: "/**",
		handler: _lazy_BCmKrJ
	};
	return ((_m, p) => {
		return {
			data,
			params: { "_": p.slice(1) }
		};
	});
})();
var globalMiddleware = [toEventHandler(static_default)].filter(Boolean);
//#endregion
//#region node_modules/.pnpm/nitro@3.0.260610-beta_chokidar@5.0.0_jiti@2.7.0_vite@8.1.5_@types+node@24.13.3_jiti@2.7.0_/node_modules/nitro/dist/runtime/internal/error/prod.mjs
var errorHandler = (error, event) => {
	const res = defaultHandler(error, event);
	return new NodeResponse(typeof res.body === "string" ? res.body : JSON.stringify(res.body, null, 2), res);
};
function defaultHandler(error, event) {
	const unhandled = error.unhandled ?? !HTTPError.isError(error);
	const { status = 500, statusText = "" } = unhandled ? {} : error;
	if (status === 404) {
		const url = event.url || new URL(event.req.url);
		const baseURL = "/";
		if (/^\/[^/]/.test(baseURL) && !url.pathname.startsWith(baseURL)) return {
			status: 302,
			headers: new Headers({ location: `${baseURL}${url.pathname.slice(1)}${url.search}` })
		};
	}
	const headers = new Headers(unhandled ? {} : error.headers);
	headers.set("content-type", "application/json; charset=utf-8");
	return {
		status,
		statusText,
		headers,
		body: {
			error: true,
			...unhandled ? {
				status,
				unhandled: true
			} : typeof error.toJSON === "function" ? error.toJSON() : {
				status,
				statusText,
				message: error.message
			}
		}
	};
}
//#endregion
//#region #nitro/virtual/error-handler
var errorHandlers = [errorHandler];
async function error_handler_default(error, event) {
	for (const handler of errorHandlers) try {
		const response = await handler(error, event, { defaultHandler });
		if (response) return response;
	} catch (error) {
		console.error(error);
	}
}
//#endregion
//#region #nitro/virtual/app
function createNitroApp() {
	const captureError = (error, errorCtx) => {
		if (errorCtx?.event) {
			const errors = errorCtx.event.req.context?.nitro?.errors;
			if (errors) errors.push({
				error,
				context: errorCtx
			});
		}
	};
	const h3App = createH3App({ onError(error, event) {
		return error_handler_default(error, event);
	} });
	let appHandler = (req) => {
		req.context ||= {};
		req.context.nitro = req.context.nitro || { errors: [] };
		return h3App.fetch(req);
	};
	return {
		fetch: appHandler,
		h3: h3App,
		hooks: void 0,
		captureError
	};
}
function createH3App(config) {
	const h3App = new H3Core(config);
	h3App["~findRoute"] = (event) => findRoute(event.req.method, event.url.pathname);
	h3App["~middleware"].push(...globalMiddleware);
	h3App["~getMiddleware"] = (event, route) => {
		const pathname = event.url.pathname;
		const method = event.req.method;
		const middleware = [];
		const routeRules = getRouteRules(method, pathname);
		event.context.routeRules = routeRules?.routeRules;
		if (routeRules?.routeRuleMiddleware.length) middleware.push(...routeRules.routeRuleMiddleware);
		middleware.push(...h3App["~middleware"]);
		if (route?.data?.middleware?.length) middleware.push(...route.data.middleware);
		return middleware;
	};
	return h3App;
}
//#endregion
//#region node_modules/.pnpm/nitro@3.0.260610-beta_chokidar@5.0.0_jiti@2.7.0_vite@8.1.5_@types+node@24.13.3_jiti@2.7.0_/node_modules/nitro/dist/runtime/internal/app.mjs
var APP_ID = "default";
function useNitroApp() {
	let instance = useNitroApp._instance;
	if (instance) return instance;
	instance = useNitroApp._instance = createNitroApp();
	globalThis.__nitro__ = globalThis.__nitro__ || {};
	globalThis.__nitro__[APP_ID] = instance;
	return instance;
}
function getRouteRules(method, pathname) {
	const m = findRouteRules(method, pathname);
	if (!m?.length) return { routeRuleMiddleware: [] };
	const routeRules = {};
	for (const layer of m) for (const rule of layer.data) {
		const currentRule = routeRules[rule.name];
		if (currentRule) {
			if (rule.options === false) {
				delete routeRules[rule.name];
				continue;
			}
			if (typeof currentRule.options === "object" && typeof rule.options === "object") currentRule.options = {
				...currentRule.options,
				...rule.options
			};
			else currentRule.options = rule.options;
			currentRule.route = rule.route;
			currentRule.params = {
				...currentRule.params,
				...layer.params
			};
		} else if (rule.options !== false) routeRules[rule.name] = {
			...rule,
			params: layer.params
		};
	}
	const middleware = [];
	const orderedRules = Object.values(routeRules).sort((a, b) => (a.handler?.order || 0) - (b.handler?.order || 0));
	for (const rule of orderedRules) {
		if (rule.options === false || !rule.handler) continue;
		middleware.push(rule.handler(rule));
	}
	return {
		routeRules,
		routeRuleMiddleware: middleware
	};
}
//#endregion
//#region node_modules/.pnpm/nitro@3.0.260610-beta_chokidar@5.0.0_jiti@2.7.0_vite@8.1.5_@types+node@24.13.3_jiti@2.7.0_/node_modules/nitro/dist/runtime/internal/error/hooks.mjs
function _captureError(error, type) {
	console.error(`[${type}]`, error);
	useNitroApp().captureError?.(error, { tags: [type] });
}
function trapUnhandledErrors() {
	process.on("unhandledRejection", (error) => _captureError(error, "unhandledRejection"));
	process.on("uncaughtException", (error) => _captureError(error, "uncaughtException"));
}
//#endregion
//#region #nitro/virtual/tracing
var tracingSrvxPlugins = [];
//#endregion
//#region node_modules/.pnpm/nitro@3.0.260610-beta_chokidar@5.0.0_jiti@2.7.0_vite@8.1.5_@types+node@24.13.3_jiti@2.7.0_/node_modules/nitro/dist/presets/node/runtime/node-server.mjs
var _parsedPort = Number.parseInt(process.env.NITRO_PORT ?? process.env.PORT ?? "");
var port = Number.isNaN(_parsedPort) ? 3e3 : _parsedPort;
var host = process.env.NITRO_HOST || process.env.HOST;
var cert = process.env.NITRO_SSL_CERT;
var key = process.env.NITRO_SSL_KEY;
var nitroApp = useNitroApp();
serve({
	port,
	hostname: host,
	tls: cert && key ? {
		cert,
		key
	} : void 0,
	fetch: nitroApp.fetch,
	plugins: [...tracingSrvxPlugins]
});
trapUnhandledErrors();
var node_server_default = {};
//#endregion
export { node_server_default as default };
