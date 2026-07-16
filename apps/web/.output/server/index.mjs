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
		"mtime": "2026-07-16T14:18:31.240Z",
		"size": 9522,
		"path": "../public/favicon.svg"
	},
	"/assets/account-MLyt_BSv.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"8ee-yznLgB7uKxXoguLSFwZ2PKgDpYI\"",
		"mtime": "2026-07-16T14:18:30.990Z",
		"size": 2286,
		"path": "../public/assets/account-MLyt_BSv.js"
	},
	"/icons.svg": {
		"type": "image/svg+xml",
		"etag": "\"13a7-+Yl6wl4T3p6mAdLxrF2TU9++/No\"",
		"mtime": "2026-07-16T14:18:31.240Z",
		"size": 5031,
		"path": "../public/icons.svg"
	},
	"/assets/dmca-DN3cZwOZ.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"1059-gEbX59WpYEiJ0TouZpMgmu/+bVU\"",
		"mtime": "2026-07-16T14:18:30.990Z",
		"size": 4185,
		"path": "../public/assets/dmca-DN3cZwOZ.js"
	},
	"/assets/account.settings-DeD1pguN.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"8e2-3jZPNEyTiXGp4OLa1uND8FLcWEU\"",
		"mtime": "2026-07-16T14:18:30.990Z",
		"size": 2274,
		"path": "../public/assets/account.settings-DeD1pguN.js"
	},
	"/assets/index-1JjnZUlF.css": {
		"type": "text/css; charset=utf-8",
		"etag": "\"f4ec-2BBlKbbhYM6H6j0e8hpJ7o5QxcY\"",
		"mtime": "2026-07-16T14:18:30.991Z",
		"size": 62700,
		"path": "../public/assets/index-1JjnZUlF.css"
	},
	"/assets/download-Dqjr33fV.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"6ee6-k3cJgzQ6+nm6HCr7MxJEBjyZyMw\"",
		"mtime": "2026-07-16T14:18:30.990Z",
		"size": 28390,
		"path": "../public/assets/download-Dqjr33fV.js"
	},
	"/assets/iptv-Dg1AsjkY.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"2f38-BDae6ZZalENDArTrKvbALSZnqU0\"",
		"mtime": "2026-07-16T14:18:30.990Z",
		"size": 12088,
		"path": "../public/assets/iptv-Dg1AsjkY.js"
	},
	"/assets/legal-shell-2hsPlh3B.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"764-tHFS3TE16FoFqV5hs9W78XrEJLI\"",
		"mtime": "2026-07-16T14:18:30.990Z",
		"size": 1892,
		"path": "../public/assets/legal-shell-2hsPlh3B.js"
	},
	"/assets/login-Cul_dhbA.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"604-Q6Ej68Hi45clOSVVbvLcVN4ulEQ\"",
		"mtime": "2026-07-16T14:18:30.990Z",
		"size": 1540,
		"path": "../public/assets/login-Cul_dhbA.js"
	},
	"/assets/require-auth-D6XYm3uX.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"1265-09WOSZTpyukLpoK0L+JRvI6z0zI\"",
		"mtime": "2026-07-16T14:18:30.990Z",
		"size": 4709,
		"path": "../public/assets/require-auth-D6XYm3uX.js"
	},
	"/assets/routes-DM6-Dpse.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"7fd2-+4OE5jYHsZhzZhpnmeSQ8TMb6Vw\"",
		"mtime": "2026-07-16T14:18:30.991Z",
		"size": 32722,
		"path": "../public/assets/routes-DM6-Dpse.js"
	},
	"/assets/reveal-CtU4Wx0J.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"764-eC+g6YZQ80gy360WHUSR9Yj/Dwk\"",
		"mtime": "2026-07-16T14:18:30.991Z",
		"size": 1892,
		"path": "../public/assets/reveal-CtU4Wx0J.js"
	},
	"/assets/signup-D1vQhzeL.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"5df-PHAinjRjknMWhqKiRpqWKQdZjCU\"",
		"mtime": "2026-07-16T14:18:30.991Z",
		"size": 1503,
		"path": "../public/assets/signup-D1vQhzeL.js"
	},
	"/assets/terms-drhjUbH4.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"e99-rKxRMCwA47bbNldodzdNpyhuxII\"",
		"mtime": "2026-07-16T14:18:30.991Z",
		"size": 3737,
		"path": "../public/assets/terms-drhjUbH4.js"
	},
	"/brand/forja-home-hero.jpg": {
		"type": "image/jpeg",
		"etag": "\"1d200-L0+Oz9HhdCpAp22rWckVFZgcmF0\"",
		"mtime": "2026-07-16T14:18:31.234Z",
		"size": 119296,
		"path": "../public/brand/forja-home-hero.jpg"
	},
	"/assets/useQuery-WOnjRMyJ.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"2234-bLjSc3OB42Yyk78Vgb8YgXrASrs\"",
		"mtime": "2026-07-16T14:18:30.991Z",
		"size": 8756,
		"path": "../public/assets/useQuery-WOnjRMyJ.js"
	},
	"/brand/forja-iptv-desk.png": {
		"type": "image/png",
		"etag": "\"2ad71-lKx0CIPrlVYcZAlyTwe77UlZPMs\"",
		"mtime": "2026-07-16T14:18:31.234Z",
		"size": 175473,
		"path": "../public/brand/forja-iptv-desk.png"
	},
	"/brand/forja-iptv-player.png": {
		"type": "image/png",
		"etag": "\"329e7-c/HMqC+n4Jp7FG1tZXnfHta3w/w\"",
		"mtime": "2026-07-16T14:18:31.236Z",
		"size": 207335,
		"path": "../public/brand/forja-iptv-player.png"
	},
	"/brand/logo-dark.svg": {
		"type": "image/svg+xml",
		"etag": "\"623-o1Ih6F3W8f02vYigcZnwJkqjztE\"",
		"mtime": "2026-07-16T14:18:31.233Z",
		"size": 1571,
		"path": "../public/brand/logo-dark.svg"
	},
	"/assets/site-header-DPAJg_sx.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"7a52-NmbDBFjY6yacclVIEjUWna0Pn5E\"",
		"mtime": "2026-07-16T14:18:30.991Z",
		"size": 31314,
		"path": "../public/assets/site-header-DPAJg_sx.js"
	},
	"/brand/logo-light.svg": {
		"type": "image/svg+xml",
		"etag": "\"623-UE2GWyGrSadl1OAEPjm5EqQDdm8\"",
		"mtime": "2026-07-16T14:18:31.233Z",
		"size": 1571,
		"path": "../public/brand/logo-light.svg"
	},
	"/brand/help/macos-blocked-dialog.png": {
		"type": "image/png",
		"etag": "\"4234-ETu0ipjh2/XmNE3rGNv6w/dufp8\"",
		"mtime": "2026-07-16T14:18:31.233Z",
		"size": 16948,
		"path": "../public/brand/help/macos-blocked-dialog.png"
	},
	"/brand/forja-iptv-live.jpg": {
		"type": "image/jpeg",
		"etag": "\"242fa-VRunXGeKGlrqDyndnFDdGDB3IqM\"",
		"mtime": "2026-07-16T14:18:31.234Z",
		"size": 148218,
		"path": "../public/brand/forja-iptv-live.jpg"
	},
	"/assets/index-sK2lcmAf.js": {
		"type": "text/javascript; charset=utf-8",
		"etag": "\"8618e-S+lDjPohwaxGcJSRgVc5C2A0TT0\"",
		"mtime": "2026-07-16T14:18:30.989Z",
		"size": 549262,
		"path": "../public/assets/index-sK2lcmAf.js"
	},
	"/brand/help/macos-open-anyway-closeup.png": {
		"type": "image/png",
		"etag": "\"1b4fc-uRjEpWMzSGjW8a6YwWXA/v4+mog\"",
		"mtime": "2026-07-16T14:18:31.237Z",
		"size": 111868,
		"path": "../public/brand/help/macos-open-anyway-closeup.png"
	},
	"/brand/help/macos-privacy-open-anyway.png": {
		"type": "image/png",
		"etag": "\"13580-w52cWA6uCk5Effy9vmN6J6U0smk\"",
		"mtime": "2026-07-16T14:18:31.239Z",
		"size": 79232,
		"path": "../public/brand/help/macos-privacy-open-anyway.png"
	},
	"/brand/help/windows-01-protected.png": {
		"type": "image/png",
		"etag": "\"8e2a-SpbOVK5Mey9lOts+NEEJckGzQ8E\"",
		"mtime": "2026-07-16T14:18:31.237Z",
		"size": 36394,
		"path": "../public/brand/help/windows-01-protected.png"
	},
	"/brand/help/windows-02-more-info.png": {
		"type": "image/png",
		"etag": "\"55b5-5ZeYmjqvpBvc8A+DbeaTs4xTCEM\"",
		"mtime": "2026-07-16T14:18:31.237Z",
		"size": 21941,
		"path": "../public/brand/help/windows-02-more-info.png"
	},
	"/brand/help/macos-privacy-settings-top.png": {
		"type": "image/png",
		"etag": "\"20ade-UMf43poWGfxcQi1um7ppqpucbBY\"",
		"mtime": "2026-07-16T14:18:31.238Z",
		"size": 133854,
		"path": "../public/brand/help/macos-privacy-settings-top.png"
	},
	"/brand/hubs/tv/cnn.svg": {
		"type": "image/svg+xml",
		"etag": "\"5e8-q6GRN+oI8JdOGOGqeNsBRNllCCI\"",
		"mtime": "2026-07-16T14:18:31.239Z",
		"size": 1512,
		"path": "../public/brand/hubs/tv/cnn.svg"
	},
	"/brand/hubs/tv/cbs.svg": {
		"type": "image/svg+xml",
		"etag": "\"1e4-AGhT51/0TlhHxScPHImbHAdUvVE\"",
		"mtime": "2026-07-16T14:18:31.239Z",
		"size": 484,
		"path": "../public/brand/hubs/tv/cbs.svg"
	},
	"/brand/hubs/tv/hbo.svg": {
		"type": "image/svg+xml",
		"etag": "\"309-pqV4IzE3FtqrNYdzbDK+0fot5L0\"",
		"mtime": "2026-07-16T14:18:31.239Z",
		"size": 777,
		"path": "../public/brand/hubs/tv/hbo.svg"
	},
	"/brand/help/windows-03-run-anyway.jpg": {
		"type": "image/jpeg",
		"etag": "\"12091-AALsao5OU43TsYsOoJagkdi8oEU\"",
		"mtime": "2026-07-16T14:18:31.238Z",
		"size": 73873,
		"path": "../public/brand/help/windows-03-run-anyway.jpg"
	},
	"/brand/hubs/tv/fox.svg": {
		"type": "image/svg+xml",
		"etag": "\"1d2-at+SHOWApDfW1BXkm22BV8W+Ioo\"",
		"mtime": "2026-07-16T14:18:31.239Z",
		"size": 466,
		"path": "../public/brand/hubs/tv/fox.svg"
	},
	"/brand/hubs/tv/nbc.svg": {
		"type": "image/svg+xml",
		"etag": "\"425-pAgrUtyFWNid0iUExBTA3aOdGf0\"",
		"mtime": "2026-07-16T14:18:31.239Z",
		"size": 1061,
		"path": "../public/brand/hubs/tv/nbc.svg"
	},
	"/brand/help/windows-04-on-desktop.jpg": {
		"type": "image/jpeg",
		"etag": "\"10063-Z44z7pPn+b6ftqouM1y7QnZasPo\"",
		"mtime": "2026-07-16T14:18:31.237Z",
		"size": 65635,
		"path": "../public/brand/help/windows-04-on-desktop.jpg"
	},
	"/brand/help/windows-05-red-unsafe.png": {
		"type": "image/png",
		"etag": "\"1363e-x3DL0x7BPVf8VDKT/lNw937VqtI\"",
		"mtime": "2026-07-16T14:18:31.238Z",
		"size": 79422,
		"path": "../public/brand/help/windows-05-red-unsafe.png"
	},
	"/brand/hubs/sport/basketball.jpg": {
		"type": "image/jpeg",
		"etag": "\"a963-khkeFZ4+DAwun0r7EB5dyNJh4Lc\"",
		"mtime": "2026-07-16T14:18:31.239Z",
		"size": 43363,
		"path": "../public/brand/hubs/sport/basketball.jpg"
	},
	"/brand/hubs/tv/sky.svg": {
		"type": "image/svg+xml",
		"etag": "\"416-0yi3whBAwbvz05E/VcP+UIj3ES0\"",
		"mtime": "2026-07-16T14:18:31.240Z",
		"size": 1046,
		"path": "../public/brand/hubs/tv/sky.svg"
	},
	"/brand/hubs/sport/racing.jpg": {
		"type": "image/jpeg",
		"etag": "\"13a2f-QqmneUjZh+5YdFrEcm0KQCH8jUs\"",
		"mtime": "2026-07-16T14:18:31.240Z",
		"size": 80431,
		"path": "../public/brand/hubs/sport/racing.jpg"
	},
	"/brand/hubs/sport/football.jpg": {
		"type": "image/jpeg",
		"etag": "\"fd7d-jNk5DatZs4RNlhyG1H/d+qRinCs\"",
		"mtime": "2026-07-16T14:18:31.240Z",
		"size": 64893,
		"path": "../public/brand/hubs/sport/football.jpg"
	},
	"/brand/hubs/sport/tennis.jpg": {
		"type": "image/jpeg",
		"etag": "\"141bc-kIDMETjdQlwHQ/HaXGKtY3vRorE\"",
		"mtime": "2026-07-16T14:18:31.240Z",
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
