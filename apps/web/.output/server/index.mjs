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
		"mtime": "2026-07-16T18:38:21.341Z",
		"size": 9522,
		"path": "../public/favicon.svg"
	},
	"/icons.svg": {
		"type": "image/svg+xml",
		"etag": "\"13a7-+Yl6wl4T3p6mAdLxrF2TU9++/No\"",
		"mtime": "2026-07-16T18:38:21.341Z",
		"size": 5031,
		"path": "../public/icons.svg"
	},
	"/assets/account-DApztS47.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"7f3-UhyvcCV7PzeOx4BnCACJaAUOkAU\"",
		"mtime": "2026-07-16T18:38:21.129Z",
		"size": 2035,
		"path": "../public/assets/account-DApztS47.js"
	},
	"/assets/account.settings-Bf4bySK5.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"9d9-5zR79olFgj8pAPcOsNmJYvWFwII\"",
		"mtime": "2026-07-16T18:38:21.130Z",
		"size": 2521,
		"path": "../public/assets/account.settings-Bf4bySK5.js"
	},
	"/assets/account.settings.playback-DA2zmPvM.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"10a7-qz9CRTaj+7rDkrx8hSQcEt5Bxdk\"",
		"mtime": "2026-07-16T18:38:21.130Z",
		"size": 4263,
		"path": "../public/assets/account.settings.playback-DA2zmPvM.js"
	},
	"/assets/account.settings.iptv-C7yv9RfH.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"1b05-0ZNTy+wv2pSIgtseJzzUkI3VhCc\"",
		"mtime": "2026-07-16T18:38:21.130Z",
		"size": 6917,
		"path": "../public/assets/account.settings.iptv-C7yv9RfH.js"
	},
	"/assets/account.settings.providers-CEbOf8ER.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"c4b-8qSKcipZvJ55ou6tcLvg9q5GTHU\"",
		"mtime": "2026-07-16T18:38:21.130Z",
		"size": 3147,
		"path": "../public/assets/account.settings.providers-CEbOf8ER.js"
	},
	"/assets/account.settings.stremio-6V6OO4P1.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"a73-TR0ucQUGo/CNLxwPhWFhnSKw5os\"",
		"mtime": "2026-07-16T18:38:21.130Z",
		"size": 2675,
		"path": "../public/assets/account.settings.stremio-6V6OO4P1.js"
	},
	"/assets/card-DFJ7Qw9I.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"1185-KRR67H4Zld6Muaq2Qrc9oF3u4OY\"",
		"mtime": "2026-07-16T18:38:21.130Z",
		"size": 4485,
		"path": "../public/assets/card-DFJ7Qw9I.js"
	},
	"/assets/createLucideIcon-DcTHTA2E.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"567-mXKUs4eu8zodK7YaH2aywkVxD14\"",
		"mtime": "2026-07-16T18:38:21.130Z",
		"size": 1383,
		"path": "../public/assets/createLucideIcon-DcTHTA2E.js"
	},
	"/assets/dist-Dh2I9UKl.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"1f1-p5dxjsVuAhRmu8pKPcgsiuruzEo\"",
		"mtime": "2026-07-16T18:38:21.130Z",
		"size": 497,
		"path": "../public/assets/dist-Dh2I9UKl.js"
	},
	"/assets/dmca-WkSSXogA.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"105c-dQiy4GLsiX/G7gP6G6KAflxCCVs\"",
		"mtime": "2026-07-16T18:38:21.131Z",
		"size": 4188,
		"path": "../public/assets/dmca-WkSSXogA.js"
	},
	"/assets/download-B9u_UKsD.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"7777-2/va/PgSk882bQbI8oJv/YI9jM4\"",
		"mtime": "2026-07-16T18:38:21.131Z",
		"size": 30583,
		"path": "../public/assets/download-B9u_UKsD.js"
	},
	"/assets/input-Dl7NGhjV.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"20d-o6RZFsuh9tGuvVi4zT96qJeyfRc\"",
		"mtime": "2026-07-16T18:38:21.131Z",
		"size": 525,
		"path": "../public/assets/input-Dl7NGhjV.js"
	},
	"/assets/index-D5F9qvjj.css": {
		"type": "text/css; charset=utf-8",
		"etag": "\"11ee0-6Xs0zch+QLSPWRPUb8eaHu9IkGo\"",
		"mtime": "2026-07-16T18:38:21.132Z",
		"size": 73440,
		"path": "../public/assets/index-D5F9qvjj.css"
	},
	"/assets/iptv-D34viL-k.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"2f75-uPvW2Q0Pk8w9jc1JFaQ8HcLGGMk\"",
		"mtime": "2026-07-16T18:38:21.131Z",
		"size": 12149,
		"path": "../public/assets/iptv-D34viL-k.js"
	},
	"/assets/label-hx9fHIE6.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"22a-Xmr7xIbyuWlcvzjaHKz5cs3dONc\"",
		"mtime": "2026-07-16T18:38:21.131Z",
		"size": 554,
		"path": "../public/assets/label-hx9fHIE6.js"
	},
	"/assets/legal-shell-Coy1Ip6S.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"14c5-inFhILabFvqaNojzBaFn4N0CvTU\"",
		"mtime": "2026-07-16T18:38:21.131Z",
		"size": 5317,
		"path": "../public/assets/legal-shell-Coy1Ip6S.js"
	},
	"/assets/index-D62ixhSQ.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"4b72a-c9Eqznj3p34NjAxtJC7K2AgV3CY\"",
		"mtime": "2026-07-16T18:38:21.129Z",
		"size": 309034,
		"path": "../public/assets/index-D62ixhSQ.js"
	},
	"/assets/login-D59iyR6r.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"230c-ALyUVUoyCmiQNkmMmzAIXDBsUMk\"",
		"mtime": "2026-07-16T18:38:21.131Z",
		"size": 8972,
		"path": "../public/assets/login-D59iyR6r.js"
	},
	"/assets/require-auth-Czd7sLCO.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"142-MBjtJP0AkifocQZX/NuCmhEE1Bo\"",
		"mtime": "2026-07-16T18:38:21.131Z",
		"size": 322,
		"path": "../public/assets/require-auth-Czd7sLCO.js"
	},
	"/assets/routes-C2Sb40Yf.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"680c-JtuZzgXYVB5tRUoCxfCSsiNlJb0\"",
		"mtime": "2026-07-16T18:38:21.132Z",
		"size": 26636,
		"path": "../public/assets/routes-C2Sb40Yf.js"
	},
	"/assets/reveal-bfpubQba.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"2ba-Tco/mSQVWQI7V0+VJRKDrwPxdAM\"",
		"mtime": "2026-07-16T18:38:21.132Z",
		"size": 698,
		"path": "../public/assets/reveal-bfpubQba.js"
	},
	"/assets/signup-BvzoN_Dk.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"5eb-wzT8Rpq9y/vzO3jrrpt9/uqCZnI\"",
		"mtime": "2026-07-16T18:38:21.132Z",
		"size": 1515,
		"path": "../public/assets/signup-BvzoN_Dk.js"
	},
	"/assets/site-header-y0K7pmyN.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"8697-VCGrusDVVsLkQUbQf4EHnyoW+zM\"",
		"mtime": "2026-07-16T18:38:21.132Z",
		"size": 34455,
		"path": "../public/assets/site-header-y0K7pmyN.js"
	},
	"/assets/sync-domains-RvOHNqYv.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"18f4-1lJqekd1Q8oeQfLx/8+QBRcjiaY\"",
		"mtime": "2026-07-16T18:38:21.132Z",
		"size": 6388,
		"path": "../public/assets/sync-domains-RvOHNqYv.js"
	},
	"/assets/terms-CJrBI_RZ.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"e9c-jomquck146t2yS/tfUvJEsxt384\"",
		"mtime": "2026-07-16T18:38:21.132Z",
		"size": 3740,
		"path": "../public/assets/terms-CJrBI_RZ.js"
	},
	"/assets/trash-2-D_bhNkRn.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"148-luFF/es/bjgJ536Ojc5F7cs5lqA\"",
		"mtime": "2026-07-16T18:38:21.132Z",
		"size": 328,
		"path": "../public/assets/trash-2-D_bhNkRn.js"
	},
	"/assets/useQuery-Dnolun4T.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"2254-UR6JCaC8Nszpa/DIark/Aje3eNM\"",
		"mtime": "2026-07-16T18:38:21.132Z",
		"size": 8788,
		"path": "../public/assets/useQuery-Dnolun4T.js"
	},
	"/assets/use-auth-BKzP2_hN.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"3b204-Xt82aJrFTpy+FD8oyU4mChQd6Mw\"",
		"mtime": "2026-07-16T18:38:21.132Z",
		"size": 242180,
		"path": "../public/assets/use-auth-BKzP2_hN.js"
	},
	"/brand/forja-home-hero.jpg": {
		"type": "image/jpeg",
		"etag": "\"1d200-L0+Oz9HhdCpAp22rWckVFZgcmF0\"",
		"mtime": "2026-07-16T18:38:21.332Z",
		"size": 119296,
		"path": "../public/brand/forja-home-hero.jpg"
	},
	"/brand/forja-iptv-desk.png": {
		"type": "image/png",
		"etag": "\"21af3-bnH1Edco6A+mnCLhYuopw3UNeUo\"",
		"mtime": "2026-07-16T18:38:21.334Z",
		"size": 137971,
		"path": "../public/brand/forja-iptv-desk.png"
	},
	"/brand/forja-iptv-live.jpg": {
		"type": "image/jpeg",
		"etag": "\"242fa-VRunXGeKGlrqDyndnFDdGDB3IqM\"",
		"mtime": "2026-07-16T18:38:21.332Z",
		"size": 148218,
		"path": "../public/brand/forja-iptv-live.jpg"
	},
	"/brand/logo-dark.svg": {
		"type": "image/svg+xml",
		"etag": "\"623-o1Ih6F3W8f02vYigcZnwJkqjztE\"",
		"mtime": "2026-07-16T18:38:21.332Z",
		"size": 1571,
		"path": "../public/brand/logo-dark.svg"
	},
	"/brand/logo-light.svg": {
		"type": "image/svg+xml",
		"etag": "\"623-UE2GWyGrSadl1OAEPjm5EqQDdm8\"",
		"mtime": "2026-07-16T18:38:21.332Z",
		"size": 1571,
		"path": "../public/brand/logo-light.svg"
	},
	"/brand/forja-iptv-player.png": {
		"type": "image/png",
		"etag": "\"329e7-c/HMqC+n4Jp7FG1tZXnfHta3w/w\"",
		"mtime": "2026-07-16T18:38:21.334Z",
		"size": 207335,
		"path": "../public/brand/forja-iptv-player.png"
	},
	"/brand/help/macos-blocked-dialog.png": {
		"type": "image/png",
		"etag": "\"4234-ETu0ipjh2/XmNE3rGNv6w/dufp8\"",
		"mtime": "2026-07-16T18:38:21.334Z",
		"size": 16948,
		"path": "../public/brand/help/macos-blocked-dialog.png"
	},
	"/brand/help/macos-privacy-open-anyway.png": {
		"type": "image/png",
		"etag": "\"13580-w52cWA6uCk5Effy9vmN6J6U0smk\"",
		"mtime": "2026-07-16T18:38:21.334Z",
		"size": 79232,
		"path": "../public/brand/help/macos-privacy-open-anyway.png"
	},
	"/brand/help/macos-open-anyway-closeup.png": {
		"type": "image/png",
		"etag": "\"1b4fc-uRjEpWMzSGjW8a6YwWXA/v4+mog\"",
		"mtime": "2026-07-16T18:38:21.332Z",
		"size": 111868,
		"path": "../public/brand/help/macos-open-anyway-closeup.png"
	},
	"/brand/help/windows-01-protected.png": {
		"type": "image/png",
		"etag": "\"8e2a-SpbOVK5Mey9lOts+NEEJckGzQ8E\"",
		"mtime": "2026-07-16T18:38:21.335Z",
		"size": 36394,
		"path": "../public/brand/help/windows-01-protected.png"
	},
	"/brand/help/macos-privacy-settings-top.png": {
		"type": "image/png",
		"etag": "\"20ade-UMf43poWGfxcQi1um7ppqpucbBY\"",
		"mtime": "2026-07-16T18:38:21.335Z",
		"size": 133854,
		"path": "../public/brand/help/macos-privacy-settings-top.png"
	},
	"/brand/help/windows-02-more-info.png": {
		"type": "image/png",
		"etag": "\"55b5-5ZeYmjqvpBvc8A+DbeaTs4xTCEM\"",
		"mtime": "2026-07-16T18:38:21.335Z",
		"size": 21941,
		"path": "../public/brand/help/windows-02-more-info.png"
	},
	"/brand/open-films/ATTRIBUTION.txt": {
		"type": "text/plain; charset=utf-8",
		"etag": "\"393-xPruSu6qRlhGu+TAtC5Ewf2eRQ8\"",
		"mtime": "2026-07-16T18:38:21.335Z",
		"size": 915,
		"path": "../public/brand/open-films/ATTRIBUTION.txt"
	},
	"/brand/help/windows-04-on-desktop.jpg": {
		"type": "image/jpeg",
		"etag": "\"10063-Z44z7pPn+b6ftqouM1y7QnZasPo\"",
		"mtime": "2026-07-16T18:38:21.337Z",
		"size": 65635,
		"path": "../public/brand/help/windows-04-on-desktop.jpg"
	},
	"/brand/help/windows-03-run-anyway.jpg": {
		"type": "image/jpeg",
		"etag": "\"12091-AALsao5OU43TsYsOoJagkdi8oEU\"",
		"mtime": "2026-07-16T18:38:21.334Z",
		"size": 73873,
		"path": "../public/brand/help/windows-03-run-anyway.jpg"
	},
	"/brand/help/windows-05-red-unsafe.png": {
		"type": "image/png",
		"etag": "\"1363e-x3DL0x7BPVf8VDKT/lNw937VqtI\"",
		"mtime": "2026-07-16T18:38:21.337Z",
		"size": 79422,
		"path": "../public/brand/help/windows-05-red-unsafe.png"
	},
	"/brand/open-films/big-buck-bunny.jpg": {
		"type": "image/jpeg",
		"etag": "\"ea1c-RJKu639IVTbZwVNOaOVb22Jj9mg\"",
		"mtime": "2026-07-16T18:38:21.332Z",
		"size": 59932,
		"path": "../public/brand/open-films/big-buck-bunny.jpg"
	},
	"/brand/open-films/cosmos-laundromat.jpg": {
		"type": "image/jpeg",
		"etag": "\"30f02-FE+8w6lMr2TCfsXtx02x77pFj9o\"",
		"mtime": "2026-07-16T18:38:21.338Z",
		"size": 200450,
		"path": "../public/brand/open-films/cosmos-laundromat.jpg"
	},
	"/brand/open-films/sintel.jpg": {
		"type": "image/jpeg",
		"etag": "\"401f4-Y8JbpchdsJvC82z77RyJhPAMB0A\"",
		"mtime": "2026-07-16T18:38:21.338Z",
		"size": 262644,
		"path": "../public/brand/open-films/sintel.jpg"
	},
	"/brand/open-films/sprite-fright.jpg": {
		"type": "image/jpeg",
		"etag": "\"39f14-koYWpeks1jRbq4TSnLa/nnB8vNw\"",
		"mtime": "2026-07-16T18:38:21.339Z",
		"size": 237332,
		"path": "../public/brand/open-films/sprite-fright.jpg"
	},
	"/brand/open-films/tears-of-steel.jpg": {
		"type": "image/jpeg",
		"etag": "\"20900-zDdyo5RecJkH+9VrLP2tmg1jFgw\"",
		"mtime": "2026-07-16T18:38:21.337Z",
		"size": 133376,
		"path": "../public/brand/open-films/tears-of-steel.jpg"
	},
	"/brand/hubs/sport/basketball.jpg": {
		"type": "image/jpeg",
		"etag": "\"a963-khkeFZ4+DAwun0r7EB5dyNJh4Lc\"",
		"mtime": "2026-07-16T18:38:21.342Z",
		"size": 43363,
		"path": "../public/brand/hubs/sport/basketball.jpg"
	},
	"/brand/hubs/sport/football.jpg": {
		"type": "image/jpeg",
		"etag": "\"fd7d-jNk5DatZs4RNlhyG1H/d+qRinCs\"",
		"mtime": "2026-07-16T18:38:21.340Z",
		"size": 64893,
		"path": "../public/brand/hubs/sport/football.jpg"
	},
	"/brand/hubs/tv/cnn.svg": {
		"type": "image/svg+xml",
		"etag": "\"5e8-q6GRN+oI8JdOGOGqeNsBRNllCCI\"",
		"mtime": "2026-07-16T18:38:21.340Z",
		"size": 1512,
		"path": "../public/brand/hubs/tv/cnn.svg"
	},
	"/brand/hubs/tv/fox.svg": {
		"type": "image/svg+xml",
		"etag": "\"1d2-at+SHOWApDfW1BXkm22BV8W+Ioo\"",
		"mtime": "2026-07-16T18:38:21.340Z",
		"size": 466,
		"path": "../public/brand/hubs/tv/fox.svg"
	},
	"/brand/hubs/tv/hbo.svg": {
		"type": "image/svg+xml",
		"etag": "\"309-pqV4IzE3FtqrNYdzbDK+0fot5L0\"",
		"mtime": "2026-07-16T18:38:21.340Z",
		"size": 777,
		"path": "../public/brand/hubs/tv/hbo.svg"
	},
	"/brand/hubs/tv/cbs.svg": {
		"type": "image/svg+xml",
		"etag": "\"1e4-AGhT51/0TlhHxScPHImbHAdUvVE\"",
		"mtime": "2026-07-16T18:38:21.340Z",
		"size": 484,
		"path": "../public/brand/hubs/tv/cbs.svg"
	},
	"/brand/hubs/tv/nbc.svg": {
		"type": "image/svg+xml",
		"etag": "\"425-pAgrUtyFWNid0iUExBTA3aOdGf0\"",
		"mtime": "2026-07-16T18:38:21.340Z",
		"size": 1061,
		"path": "../public/brand/hubs/tv/nbc.svg"
	},
	"/brand/hubs/tv/sky.svg": {
		"type": "image/svg+xml",
		"etag": "\"416-0yi3whBAwbvz05E/VcP+UIj3ES0\"",
		"mtime": "2026-07-16T18:38:21.341Z",
		"size": 1046,
		"path": "../public/brand/hubs/tv/sky.svg"
	},
	"/brand/hubs/sport/racing.jpg": {
		"type": "image/jpeg",
		"etag": "\"13a2f-QqmneUjZh+5YdFrEcm0KQCH8jUs\"",
		"mtime": "2026-07-16T18:38:21.342Z",
		"size": 80431,
		"path": "../public/brand/hubs/sport/racing.jpg"
	},
	"/brand/hubs/sport/tennis.jpg": {
		"type": "image/jpeg",
		"etag": "\"141bc-kIDMETjdQlwHQ/HaXGKtY3vRorE\"",
		"mtime": "2026-07-16T18:38:21.342Z",
		"size": 82364,
		"path": "../public/brand/hubs/sport/tennis.jpg"
	},
	"/brand/open-films/heroes/sprite-fright-hero.jpg": {
		"type": "image/jpeg",
		"etag": "\"4a3c9-xsz23TXZsi0RkktQSH82lw3h74s\"",
		"mtime": "2026-07-16T18:38:21.340Z",
		"size": 304073,
		"path": "../public/brand/open-films/heroes/sprite-fright-hero.jpg"
	},
	"/brand/open-films/heroes/sintel-hero.jpg": {
		"type": "image/jpeg",
		"etag": "\"13a2b-05X9ixqlMQsH9Ltv0Qv2JgtVFjY\"",
		"mtime": "2026-07-16T18:38:21.339Z",
		"size": 80427,
		"path": "../public/brand/open-films/heroes/sintel-hero.jpg"
	},
	"/brand/open-films/heroes/tears-of-steel-hero.jpg": {
		"type": "image/jpeg",
		"etag": "\"3ac39-dEFQSuCa+Pnc+pjRT7rEenyxJT0\"",
		"mtime": "2026-07-16T18:38:21.340Z",
		"size": 240697,
		"path": "../public/brand/open-films/heroes/tears-of-steel-hero.jpg"
	},
	"/brand/open-films/heroes/big-buck-bunny-hero.jpg": {
		"type": "image/jpeg",
		"etag": "\"4e17f-lU3IkVnLsrEZ9w3oKmX+eGpg1vM\"",
		"mtime": "2026-07-16T18:38:21.334Z",
		"size": 319871,
		"path": "../public/brand/open-films/heroes/big-buck-bunny-hero.jpg"
	},
	"/brand/open-films/heroes/cosmos-laundromat-hero.jpg": {
		"type": "image/jpeg",
		"etag": "\"31149-bY1Lk1yErAAF6Oxv3ap35bmdZjY\"",
		"mtime": "2026-07-16T18:38:21.339Z",
		"size": 201033,
		"path": "../public/brand/open-films/heroes/cosmos-laundromat-hero.jpg"
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
