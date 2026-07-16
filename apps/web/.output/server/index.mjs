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
	"/favicon.svg": {
		"type": "image/svg+xml",
		"etag": "\"2532-P1u486agW3ymimJYHS3VvIiBLK8\"",
		"mtime": "2026-07-16T19:42:00.447Z",
		"size": 9522,
		"path": "../public/favicon.svg"
	},
	"/icons.svg": {
		"type": "image/svg+xml",
		"etag": "\"13a7-+Yl6wl4T3p6mAdLxrF2TU9++/No\"",
		"mtime": "2026-07-16T19:42:00.448Z",
		"size": 5031,
		"path": "../public/icons.svg"
	},
	"/assets/account-B0Q5MLmu.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"cf1-J2yUIXb+qDLCig6AJ0q4tL/Wz4o\"",
		"mtime": "2026-07-16T19:41:59.225Z",
		"size": 3313,
		"path": "../public/assets/account-B0Q5MLmu.js"
	},
	"/assets/account.settings-BVhLaHJg.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"168-a/xMhB/ujy2hNgZ6XPUa+Sbnt1U\"",
		"mtime": "2026-07-16T19:41:59.225Z",
		"size": 360,
		"path": "../public/assets/account.settings-BVhLaHJg.js"
	},
	"/assets/account.profiles-CrT6FIBs.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"1870-mCs4soVmOJxfggSZdkwExwbiR0g\"",
		"mtime": "2026-07-16T19:41:59.225Z",
		"size": 6256,
		"path": "../public/assets/account.profiles-CrT6FIBs.js"
	},
	"/assets/account.settings.playback-C96n7gYK.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"1148-DAuM53kbPg+7gCg3eLIZgJgOk6E\"",
		"mtime": "2026-07-16T19:41:59.225Z",
		"size": 4424,
		"path": "../public/assets/account.settings.playback-C96n7gYK.js"
	},
	"/assets/account.settings.iptv-CNfGQJRn.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"3aba-r9xrCxROGI21iqNDR893Wg+4NQA\"",
		"mtime": "2026-07-16T19:41:59.225Z",
		"size": 15034,
		"path": "../public/assets/account.settings.iptv-CNfGQJRn.js"
	},
	"/assets/account.settings.stremio-ClO-20FB.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"a0d-MExdFISpxe5JLiuqwikBP31e9fU\"",
		"mtime": "2026-07-16T19:41:59.226Z",
		"size": 2573,
		"path": "../public/assets/account.settings.stremio-ClO-20FB.js"
	},
	"/assets/check-DHiYhY6l.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"e1-AB98K1GaqQXD6Z4f0NSBTIzBqZ0\"",
		"mtime": "2026-07-16T19:41:59.226Z",
		"size": 225,
		"path": "../public/assets/check-DHiYhY6l.js"
	},
	"/assets/dist-DSDlrMpl.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"254-3f5zw93QhKzluvb5ejJUoz9mXkg\"",
		"mtime": "2026-07-16T19:41:59.226Z",
		"size": 596,
		"path": "../public/assets/dist-DSDlrMpl.js"
	},
	"/assets/dmca-xo0DxdtY.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"1079-eSp2coF+ui0KBHN3tXXeuDXo/Og\"",
		"mtime": "2026-07-16T19:41:59.226Z",
		"size": 4217,
		"path": "../public/assets/dmca-xo0DxdtY.js"
	},
	"/assets/download-CMih7WuD.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"7740-1aLOwDJHnK1Ngz1vZ+aufhqp4fg\"",
		"mtime": "2026-07-16T19:41:59.226Z",
		"size": 30528,
		"path": "../public/assets/download-CMih7WuD.js"
	},
	"/assets/index-C1KAwdvk.css": {
		"type": "text/css; charset=utf-8",
		"etag": "\"13c72-881zS5lRE9VRssXIIAxAZcA6lUQ\"",
		"mtime": "2026-07-16T19:41:59.229Z",
		"size": 81010,
		"path": "../public/assets/index-C1KAwdvk.css"
	},
	"/assets/input-C5eHm51y.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"20b-ZmwpQ91mO/gPBOYpu3d/zUxhbVc\"",
		"mtime": "2026-07-16T19:41:59.226Z",
		"size": 523,
		"path": "../public/assets/input-C5eHm51y.js"
	},
	"/assets/iptv-Cr7z0sUc.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"2f44-DBTrAc52nPCc5NJVZ8AMWO4njoQ\"",
		"mtime": "2026-07-16T19:41:59.226Z",
		"size": 12100,
		"path": "../public/assets/iptv-Cr7z0sUc.js"
	},
	"/assets/legal-shell-CoI1dt1J.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"14e0-XcjSSCTOWVoAE8EouR8KnrCvJEk\"",
		"mtime": "2026-07-16T19:41:59.226Z",
		"size": 5344,
		"path": "../public/assets/legal-shell-CoI1dt1J.js"
	},
	"/assets/label-CXEzijqo.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"228-/I460Vr144gD6ASLoMi5Q7Mwom8\"",
		"mtime": "2026-07-16T19:41:59.226Z",
		"size": 552,
		"path": "../public/assets/label-CXEzijqo.js"
	},
	"/assets/login-Cbg9xDjJ.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"2093-U4ca6Ax4FVk3s9I9tFuuMV/52WA\"",
		"mtime": "2026-07-16T19:41:59.227Z",
		"size": 8339,
		"path": "../public/assets/login-Cbg9xDjJ.js"
	},
	"/assets/plus-DT9uVglY.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"8e-2699HpUMrWr4mvMPpYlDKUqRV3M\"",
		"mtime": "2026-07-16T19:41:59.227Z",
		"size": 142,
		"path": "../public/assets/plus-DT9uVglY.js"
	},
	"/assets/reveal-BZQ6Oztx.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"2b8-6fSPWmVwaztmxGCLR2V746Y8doU\"",
		"mtime": "2026-07-16T19:41:59.227Z",
		"size": 696,
		"path": "../public/assets/reveal-BZQ6Oztx.js"
	},
	"/assets/require-auth-Bmje4rPu.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"142-rXHWl4GCApzGGfMsUnT4Ax/0zSY\"",
		"mtime": "2026-07-16T19:41:59.227Z",
		"size": 322,
		"path": "../public/assets/require-auth-Bmje4rPu.js"
	},
	"/assets/account.settings.providers-Z6NSO4Hx.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"e22-KF/rcWh7e92839P894wHXZ4rTAs\"",
		"mtime": "2026-07-16T19:41:59.226Z",
		"size": 3618,
		"path": "../public/assets/account.settings.providers-Z6NSO4Hx.js"
	},
	"/assets/button-DqIoWOZ_.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"f20-CRhCvlnXeNhS5yovWEopcL2dQ1w\"",
		"mtime": "2026-07-16T19:41:59.226Z",
		"size": 3872,
		"path": "../public/assets/button-DqIoWOZ_.js"
	},
	"/assets/routes-B1MQo2XB.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"67a9-pQyMCdlKX1rD28+DUxqn7wMYqR4\"",
		"mtime": "2026-07-16T19:41:59.227Z",
		"size": 26537,
		"path": "../public/assets/routes-B1MQo2XB.js"
	},
	"/assets/index-CJS6mZTu.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"8d23e-cNbz3oLO4bjrJ5yY2B0R+FGOBps\"",
		"mtime": "2026-07-16T19:41:59.225Z",
		"size": 578110,
		"path": "../public/assets/index-CJS6mZTu.js"
	},
	"/assets/settings-section-kHgxTLUN.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"22f-PJeYkr1JGP4AnJV8PZ0RupgJcSI\"",
		"mtime": "2026-07-16T19:41:59.227Z",
		"size": 559,
		"path": "../public/assets/settings-section-kHgxTLUN.js"
	},
	"/assets/signup-Da0KX-Ik.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"60a-PBqhZWphv19rqBMlp1sxQAV0au4\"",
		"mtime": "2026-07-16T19:41:59.227Z",
		"size": 1546,
		"path": "../public/assets/signup-Da0KX-Ik.js"
	},
	"/assets/site-header-CszQEgDa.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"1bbd-wd086AP4pqWuOwO7WPchOAWBxhA\"",
		"mtime": "2026-07-16T19:41:59.227Z",
		"size": 7101,
		"path": "../public/assets/site-header-CszQEgDa.js"
	},
	"/assets/sync-domains-CTB8bm3Q.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"14e92-PQ9Z7QJ0B2al7QWUNVGqfhIrtVY\"",
		"mtime": "2026-07-16T19:41:59.228Z",
		"size": 85650,
		"path": "../public/assets/sync-domains-CTB8bm3Q.js"
	},
	"/assets/trash-2-ZegIVOxG.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"13d-uxP00C43oCF+NoQqSipXitmN23g\"",
		"mtime": "2026-07-16T19:41:59.228Z",
		"size": 317,
		"path": "../public/assets/trash-2-ZegIVOxG.js"
	},
	"/assets/terms-4L2-SHg9.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"eb5-H5psx+ZuO608EL7ny9eKPK77CK0\"",
		"mtime": "2026-07-16T19:41:59.228Z",
		"size": 3765,
		"path": "../public/assets/terms-4L2-SHg9.js"
	},
	"/assets/useMatch-CcToMSxM.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"6d97-4DNQJuKnBpctrJfHYFC3uVB/BEU\"",
		"mtime": "2026-07-16T19:41:59.228Z",
		"size": 28055,
		"path": "../public/assets/useMatch-CcToMSxM.js"
	},
	"/assets/useRouterState-dD2QYZ3L.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"aa-hugmp+59vWB6h+F+XC4SIzXxFDQ\"",
		"mtime": "2026-07-16T19:41:59.228Z",
		"size": 170,
		"path": "../public/assets/useRouterState-dD2QYZ3L.js"
	},
	"/brand/forja-home-hero.jpg": {
		"type": "image/jpeg",
		"etag": "\"1d200-L0+Oz9HhdCpAp22rWckVFZgcmF0\"",
		"mtime": "2026-07-16T19:42:00.377Z",
		"size": 119296,
		"path": "../public/brand/forja-home-hero.jpg"
	},
	"/brand/logo-dark.svg": {
		"type": "image/svg+xml",
		"etag": "\"623-o1Ih6F3W8f02vYigcZnwJkqjztE\"",
		"mtime": "2026-07-16T19:42:00.380Z",
		"size": 1571,
		"path": "../public/brand/logo-dark.svg"
	},
	"/brand/forja-iptv-desk.png": {
		"type": "image/png",
		"etag": "\"21af3-bnH1Edco6A+mnCLhYuopw3UNeUo\"",
		"mtime": "2026-07-16T19:42:00.381Z",
		"size": 137971,
		"path": "../public/brand/forja-iptv-desk.png"
	},
	"/brand/logo-light.svg": {
		"type": "image/svg+xml",
		"etag": "\"623-UE2GWyGrSadl1OAEPjm5EqQDdm8\"",
		"mtime": "2026-07-16T19:42:00.380Z",
		"size": 1571,
		"path": "../public/brand/logo-light.svg"
	},
	"/brand/forja-iptv-live.jpg": {
		"type": "image/jpeg",
		"etag": "\"242fa-VRunXGeKGlrqDyndnFDdGDB3IqM\"",
		"mtime": "2026-07-16T19:42:00.390Z",
		"size": 148218,
		"path": "../public/brand/forja-iptv-live.jpg"
	},
	"/brand/help/macos-blocked-dialog.png": {
		"type": "image/png",
		"etag": "\"4234-ETu0ipjh2/XmNE3rGNv6w/dufp8\"",
		"mtime": "2026-07-16T19:42:00.363Z",
		"size": 16948,
		"path": "../public/brand/help/macos-blocked-dialog.png"
	},
	"/brand/forja-iptv-player.png": {
		"type": "image/png",
		"etag": "\"329e7-c/HMqC+n4Jp7FG1tZXnfHta3w/w\"",
		"mtime": "2026-07-16T19:42:00.380Z",
		"size": 207335,
		"path": "../public/brand/forja-iptv-player.png"
	},
	"/brand/help/macos-open-anyway-closeup.png": {
		"type": "image/png",
		"etag": "\"1b4fc-uRjEpWMzSGjW8a6YwWXA/v4+mog\"",
		"mtime": "2026-07-16T19:42:00.387Z",
		"size": 111868,
		"path": "../public/brand/help/macos-open-anyway-closeup.png"
	},
	"/brand/help/macos-privacy-open-anyway.png": {
		"type": "image/png",
		"etag": "\"13580-w52cWA6uCk5Effy9vmN6J6U0smk\"",
		"mtime": "2026-07-16T19:42:00.382Z",
		"size": 79232,
		"path": "../public/brand/help/macos-privacy-open-anyway.png"
	},
	"/brand/help/windows-02-more-info.png": {
		"type": "image/png",
		"etag": "\"55b5-5ZeYmjqvpBvc8A+DbeaTs4xTCEM\"",
		"mtime": "2026-07-16T19:42:00.383Z",
		"size": 21941,
		"path": "../public/brand/help/windows-02-more-info.png"
	},
	"/brand/help/windows-01-protected.png": {
		"type": "image/png",
		"etag": "\"8e2a-SpbOVK5Mey9lOts+NEEJckGzQ8E\"",
		"mtime": "2026-07-16T19:42:00.391Z",
		"size": 36394,
		"path": "../public/brand/help/windows-01-protected.png"
	},
	"/brand/help/macos-privacy-settings-top.png": {
		"type": "image/png",
		"etag": "\"20ade-UMf43poWGfxcQi1um7ppqpucbBY\"",
		"mtime": "2026-07-16T19:42:00.390Z",
		"size": 133854,
		"path": "../public/brand/help/macos-privacy-settings-top.png"
	},
	"/brand/help/windows-04-on-desktop.jpg": {
		"type": "image/jpeg",
		"etag": "\"10063-Z44z7pPn+b6ftqouM1y7QnZasPo\"",
		"mtime": "2026-07-16T19:42:00.389Z",
		"size": 65635,
		"path": "../public/brand/help/windows-04-on-desktop.jpg"
	},
	"/brand/help/windows-05-red-unsafe.png": {
		"type": "image/png",
		"etag": "\"1363e-x3DL0x7BPVf8VDKT/lNw937VqtI\"",
		"mtime": "2026-07-16T19:42:00.414Z",
		"size": 79422,
		"path": "../public/brand/help/windows-05-red-unsafe.png"
	},
	"/brand/help/windows-03-run-anyway.jpg": {
		"type": "image/jpeg",
		"etag": "\"12091-AALsao5OU43TsYsOoJagkdi8oEU\"",
		"mtime": "2026-07-16T19:42:00.387Z",
		"size": 73873,
		"path": "../public/brand/help/windows-03-run-anyway.jpg"
	},
	"/brand/open-films/ATTRIBUTION.txt": {
		"type": "text/plain; charset=utf-8",
		"etag": "\"393-xPruSu6qRlhGu+TAtC5Ewf2eRQ8\"",
		"mtime": "2026-07-16T19:42:00.368Z",
		"size": 915,
		"path": "../public/brand/open-films/ATTRIBUTION.txt"
	},
	"/brand/open-films/big-buck-bunny.jpg": {
		"type": "image/jpeg",
		"etag": "\"ea1c-RJKu639IVTbZwVNOaOVb22Jj9mg\"",
		"mtime": "2026-07-16T19:42:00.392Z",
		"size": 59932,
		"path": "../public/brand/open-films/big-buck-bunny.jpg"
	},
	"/brand/open-films/sintel.jpg": {
		"type": "image/jpeg",
		"etag": "\"401f4-Y8JbpchdsJvC82z77RyJhPAMB0A\"",
		"mtime": "2026-07-16T19:42:00.418Z",
		"size": 262644,
		"path": "../public/brand/open-films/sintel.jpg"
	},
	"/brand/open-films/cosmos-laundromat.jpg": {
		"type": "image/jpeg",
		"etag": "\"30f02-FE+8w6lMr2TCfsXtx02x77pFj9o\"",
		"mtime": "2026-07-16T19:42:00.418Z",
		"size": 200450,
		"path": "../public/brand/open-films/cosmos-laundromat.jpg"
	},
	"/brand/open-films/tears-of-steel.jpg": {
		"type": "image/jpeg",
		"etag": "\"20900-zDdyo5RecJkH+9VrLP2tmg1jFgw\"",
		"mtime": "2026-07-16T19:42:00.427Z",
		"size": 133376,
		"path": "../public/brand/open-films/tears-of-steel.jpg"
	},
	"/brand/hubs/tv/cbs.svg": {
		"type": "image/svg+xml",
		"etag": "\"1e4-AGhT51/0TlhHxScPHImbHAdUvVE\"",
		"mtime": "2026-07-16T19:42:00.432Z",
		"size": 484,
		"path": "../public/brand/hubs/tv/cbs.svg"
	},
	"/brand/hubs/tv/cnn.svg": {
		"type": "image/svg+xml",
		"etag": "\"5e8-q6GRN+oI8JdOGOGqeNsBRNllCCI\"",
		"mtime": "2026-07-16T19:42:00.443Z",
		"size": 1512,
		"path": "../public/brand/hubs/tv/cnn.svg"
	},
	"/brand/hubs/tv/hbo.svg": {
		"type": "image/svg+xml",
		"etag": "\"309-pqV4IzE3FtqrNYdzbDK+0fot5L0\"",
		"mtime": "2026-07-16T19:42:00.447Z",
		"size": 777,
		"path": "../public/brand/hubs/tv/hbo.svg"
	},
	"/brand/hubs/tv/nbc.svg": {
		"type": "image/svg+xml",
		"etag": "\"425-pAgrUtyFWNid0iUExBTA3aOdGf0\"",
		"mtime": "2026-07-16T19:42:00.447Z",
		"size": 1061,
		"path": "../public/brand/hubs/tv/nbc.svg"
	},
	"/brand/hubs/tv/sky.svg": {
		"type": "image/svg+xml",
		"etag": "\"416-0yi3whBAwbvz05E/VcP+UIj3ES0\"",
		"mtime": "2026-07-16T19:42:00.447Z",
		"size": 1046,
		"path": "../public/brand/hubs/tv/sky.svg"
	},
	"/brand/hubs/sport/basketball.jpg": {
		"type": "image/jpeg",
		"etag": "\"a963-khkeFZ4+DAwun0r7EB5dyNJh4Lc\"",
		"mtime": "2026-07-16T19:42:00.438Z",
		"size": 43363,
		"path": "../public/brand/hubs/sport/basketball.jpg"
	},
	"/brand/hubs/sport/football.jpg": {
		"type": "image/jpeg",
		"etag": "\"fd7d-jNk5DatZs4RNlhyG1H/d+qRinCs\"",
		"mtime": "2026-07-16T19:42:00.442Z",
		"size": 64893,
		"path": "../public/brand/hubs/sport/football.jpg"
	},
	"/brand/hubs/sport/tennis.jpg": {
		"type": "image/jpeg",
		"etag": "\"141bc-kIDMETjdQlwHQ/HaXGKtY3vRorE\"",
		"mtime": "2026-07-16T19:42:00.447Z",
		"size": 82364,
		"path": "../public/brand/hubs/sport/tennis.jpg"
	},
	"/brand/hubs/sport/racing.jpg": {
		"type": "image/jpeg",
		"etag": "\"13a2f-QqmneUjZh+5YdFrEcm0KQCH8jUs\"",
		"mtime": "2026-07-16T19:42:00.449Z",
		"size": 80431,
		"path": "../public/brand/hubs/sport/racing.jpg"
	},
	"/brand/open-films/heroes/cosmos-laundromat-hero.jpg": {
		"type": "image/jpeg",
		"etag": "\"31149-bY1Lk1yErAAF6Oxv3ap35bmdZjY\"",
		"mtime": "2026-07-16T19:42:00.428Z",
		"size": 201033,
		"path": "../public/brand/open-films/heroes/cosmos-laundromat-hero.jpg"
	},
	"/brand/open-films/sprite-fright.jpg": {
		"type": "image/jpeg",
		"etag": "\"39f14-koYWpeks1jRbq4TSnLa/nnB8vNw\"",
		"mtime": "2026-07-16T19:42:00.415Z",
		"size": 237332,
		"path": "../public/brand/open-films/sprite-fright.jpg"
	},
	"/brand/open-films/heroes/sintel-hero.jpg": {
		"type": "image/jpeg",
		"etag": "\"13a2b-05X9ixqlMQsH9Ltv0Qv2JgtVFjY\"",
		"mtime": "2026-07-16T19:42:00.430Z",
		"size": 80427,
		"path": "../public/brand/open-films/heroes/sintel-hero.jpg"
	},
	"/brand/open-films/heroes/sprite-fright-hero.jpg": {
		"type": "image/jpeg",
		"etag": "\"4a3c9-xsz23TXZsi0RkktQSH82lw3h74s\"",
		"mtime": "2026-07-16T19:42:00.442Z",
		"size": 304073,
		"path": "../public/brand/open-films/heroes/sprite-fright-hero.jpg"
	},
	"/brand/open-films/heroes/big-buck-bunny-hero.jpg": {
		"type": "image/jpeg",
		"etag": "\"4e17f-lU3IkVnLsrEZ9w3oKmX+eGpg1vM\"",
		"mtime": "2026-07-16T19:42:00.381Z",
		"size": 319871,
		"path": "../public/brand/open-films/heroes/big-buck-bunny-hero.jpg"
	},
	"/brand/hubs/tv/fox.svg": {
		"type": "image/svg+xml",
		"etag": "\"1d2-at+SHOWApDfW1BXkm22BV8W+Ioo\"",
		"mtime": "2026-07-16T19:42:00.447Z",
		"size": 466,
		"path": "../public/brand/hubs/tv/fox.svg"
	},
	"/brand/open-films/heroes/tears-of-steel-hero.jpg": {
		"type": "image/jpeg",
		"etag": "\"3ac39-dEFQSuCa+Pnc+pjRT7rEenyxJT0\"",
		"mtime": "2026-07-16T19:42:00.441Z",
		"size": 240697,
		"path": "../public/brand/open-films/heroes/tears-of-steel-hero.jpg"
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
