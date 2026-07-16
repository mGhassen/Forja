import { s as require_jsx_runtime } from "../_libs/@radix-ui/react-arrow+[...].mjs";
import { t as AuthProvider } from "./utils-BshMKIch.mjs";
import { t as QueryClient } from "../_libs/tanstack__query-core.mjs";
import { r as QueryClientProvider } from "../_libs/tanstack__react-query.mjs";
import { i as ProfilesProvider } from "./use-profiles-CvQVjB9I.mjs";
import { c as Outlet, d as createRootRoute, i as HeadContent, l as lazyRouteComponent, r as Scripts, s as createRouter, u as createFileRoute } from "../_libs/@tanstack/react-router+[...].mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/router-Bafq--_G.js
var import_jsx_runtime = require_jsx_runtime();
var src_default = "/assets/index-amMFXwNO.css";
var queryClient = new QueryClient({ defaultOptions: { queries: {
	retry: 1,
	refetchOnWindowFocus: false
} } });
var Route$15 = createRootRoute({
	head: () => ({
		meta: [
			{ charSet: "utf-8" },
			{
				name: "viewport",
				content: "width=device-width, initial-scale=1.0"
			},
			{
				name: "description",
				content: "Forja - free media player for streaming. Playback, live playlists, and controls on Windows, macOS, Linux, and Android TV."
			},
			{ title: "Forja" }
		],
		links: [
			{
				rel: "icon",
				type: "image/svg+xml",
				href: "/brand/logo-dark.svg"
			},
			{
				rel: "stylesheet",
				href: src_default
			},
			{
				rel: "preconnect",
				href: "https://fonts.googleapis.com"
			},
			{
				rel: "preconnect",
				href: "https://fonts.gstatic.com",
				crossOrigin: "anonymous"
			},
			{
				rel: "stylesheet",
				href: "https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:opsz,wght@12..96,600;12..96,700;12..96,800&family=Fraunces:ital,opsz,wght@0,9..144,500;1,9..144,400;1,9..144,500&family=Space+Mono:wght@400;700&family=Instrument+Sans:wght@400;500;600;700&display=swap"
			}
		]
	}),
	component: RootComponent
});
function RootComponent() {
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)(RootDocument, { children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(QueryClientProvider, {
		client: queryClient,
		children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(AuthProvider, { children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(ProfilesProvider, { children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Outlet, {}) }) })
	}) });
}
function RootDocument({ children }) {
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("html", {
		lang: "en",
		children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("head", { children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(HeadContent, {}) }), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("body", { children: [children, /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Scripts, {})] })]
	});
}
var $$splitComponentImporter$13 = () => import("./terms-BJc80eHy.mjs");
var Route$14 = createFileRoute("/terms")({
	component: lazyRouteComponent($$splitComponentImporter$13, "component"),
	head: () => ({ meta: [{ title: "Terms of use - Forja" }] })
});
var $$splitComponentImporter$12 = () => import("./signup-BLCGrpxg.mjs");
var Route$13 = createFileRoute("/signup")({ component: lazyRouteComponent($$splitComponentImporter$12, "component") });
var $$splitComponentImporter$11 = () => import("./login-0SKSPAaL.mjs");
var Route$12 = createFileRoute("/login")({ component: lazyRouteComponent($$splitComponentImporter$11, "component") });
var $$splitComponentImporter$10 = () => import("./iptv-D7UBzS1q.mjs");
var Route$11 = createFileRoute("/iptv")({ component: lazyRouteComponent($$splitComponentImporter$10, "component") });
var $$splitComponentImporter$9 = () => import("./download-BQdsfZ2Z.mjs");
var Route$10 = createFileRoute("/download")({ component: lazyRouteComponent($$splitComponentImporter$9, "component") });
var $$splitComponentImporter$8 = () => import("./dmca-ri1Z3jSm.mjs");
var Route$9 = createFileRoute("/dmca")({
	component: lazyRouteComponent($$splitComponentImporter$8, "component"),
	head: () => ({ meta: [{ title: "DMCA & copyright - Forja" }] })
});
var $$splitComponentImporter$7 = () => import("./account-CL-hgHNv.mjs");
var Route$8 = createFileRoute("/account")({ component: lazyRouteComponent($$splitComponentImporter$7, "component") });
var $$splitComponentImporter$6 = () => import("./routes-H5ThKCK9.mjs");
var Route$7 = createFileRoute("/")({ component: lazyRouteComponent($$splitComponentImporter$6, "component") });
var RENTRY_BASE = "https://rentry.co";
var RENTRY_EDIT_CODE = "ForjaIptvShare1";
var UA = "Forja/1.2 (https://github.com/forja-forja/forja)";
function extractCookie(setCookie) {
	if (!setCookie) return null;
	const semi = setCookie.indexOf(";");
	return semi >= 0 ? setCookie.slice(0, semi) : setCookie;
}
async function rentrySession() {
	const resp = await fetch(`${RENTRY_BASE}/`, { headers: { "User-Agent": UA } });
	if (!resp.ok) throw new Error(`Share service unavailable (${resp.status})`);
	const csrf = (await resp.text()).match(/csrfmiddlewaretoken" value="([^"]+)"/)?.[1];
	if (!csrf) throw new Error("Share service unavailable (missing CSRF token)");
	return {
		csrf,
		cookie: extractCookie(resp.headers.get("set-cookie"))
	};
}
async function rentryCreate(code, text) {
	const session = await rentrySession();
	const body = new URLSearchParams({
		csrfmiddlewaretoken: session.csrf,
		url: code,
		edit_code: RENTRY_EDIT_CODE,
		text
	});
	const resp = await fetch(`${RENTRY_BASE}/api/new`, {
		method: "POST",
		headers: {
			"User-Agent": UA,
			"Content-Type": "application/x-www-form-urlencoded",
			...session.cookie ? { Cookie: session.cookie } : {}
		},
		body
	});
	if (!resp.ok) throw new Error(`Share upload failed (${resp.status})`);
	const decoded = await resp.json();
	const status = `${decoded.status ?? ""}`;
	if (status === "400") {
		if (`${decoded.errors ?? ""}`.toLowerCase().includes("already in use")) throw new Error("already in use");
	}
	if (status !== "200") throw new Error(`Share upload failed (${status})`);
}
async function rentryFetch(code) {
	const session = await rentrySession();
	const body = new URLSearchParams({
		csrfmiddlewaretoken: session.csrf,
		edit_code: RENTRY_EDIT_CODE
	});
	const resp = await fetch(`${RENTRY_BASE}/api/fetch/${code.toLowerCase()}`, {
		method: "POST",
		headers: {
			"User-Agent": UA,
			"Content-Type": "application/x-www-form-urlencoded",
			...session.cookie ? { Cookie: session.cookie } : {}
		},
		body
	});
	if (!resp.ok) return null;
	const decoded = await resp.json();
	if (`${decoded.status}` !== "200") return null;
	return decoded.content?.text ?? null;
}
function json(data, status = 200) {
	return Response.json(data, { status });
}
var Route$6 = createFileRoute("/api/iptv-share")({ server: { handlers: { POST: async ({ request }) => {
	try {
		const body = await request.json();
		const action = body.action;
		const code = (body.code ?? "").trim().toUpperCase().replace(/[^A-Z0-9]/g, "");
		if (action === "create") {
			const text = body.text?.trim() ?? "";
			if (code.length !== 8 || !text) return json({ error: "Invalid share payload" }, 400);
			await rentryCreate(code, text);
			return json({
				ok: true,
				code
			});
		}
		if (action === "fetch") {
			if (code.length !== 8) return json({ error: "Invalid share code" }, 400);
			const text = await rentryFetch(code);
			if (!text) return json({ error: "Share code not found" }, 404);
			return json({
				ok: true,
				text
			});
		}
		return json({ error: "Unknown action" }, 400);
	} catch (error) {
		const message = error instanceof Error ? error.message : "Share service failed";
		const status = message.toLowerCase().includes("already in use") ? 409 : 502;
		return json({ error: message }, status);
	}
} } } });
var $$splitComponentImporter$5 = () => import("./account.settings-DKb9BPNb.mjs");
var Route$5 = createFileRoute("/account/settings")({ component: lazyRouteComponent($$splitComponentImporter$5, "component") });
var $$splitComponentImporter$4 = () => import("./account.profiles-SAiCQ09o.mjs");
var Route$4 = createFileRoute("/account/profiles")({ component: lazyRouteComponent($$splitComponentImporter$4, "component") });
var $$splitComponentImporter$3 = () => import("./account.settings.stremio-CGNy3fFh.mjs");
var Route$3 = createFileRoute("/account/settings/stremio")({ component: lazyRouteComponent($$splitComponentImporter$3, "component") });
var $$splitComponentImporter$2 = () => import("./account.settings.providers-BM0m6S_V.mjs");
var Route$2 = createFileRoute("/account/settings/providers")({ component: lazyRouteComponent($$splitComponentImporter$2, "component") });
var $$splitComponentImporter$1 = () => import("./account.settings.playback-Dn3A80af.mjs");
var Route$1 = createFileRoute("/account/settings/playback")({ component: lazyRouteComponent($$splitComponentImporter$1, "component") });
var $$splitComponentImporter = () => import("./account.settings.iptv-B4xQIXzy.mjs");
var Route = createFileRoute("/account/settings/iptv")({ component: lazyRouteComponent($$splitComponentImporter, "component") });
var TermsRoute = Route$14.update({
	id: "/terms",
	path: "/terms",
	getParentRoute: () => Route$15
});
var SignupRoute = Route$13.update({
	id: "/signup",
	path: "/signup",
	getParentRoute: () => Route$15
});
var LoginRoute = Route$12.update({
	id: "/login",
	path: "/login",
	getParentRoute: () => Route$15
});
var IptvRoute = Route$11.update({
	id: "/iptv",
	path: "/iptv",
	getParentRoute: () => Route$15
});
var DownloadRoute = Route$10.update({
	id: "/download",
	path: "/download",
	getParentRoute: () => Route$15
});
var DmcaRoute = Route$9.update({
	id: "/dmca",
	path: "/dmca",
	getParentRoute: () => Route$15
});
var AccountRoute = Route$8.update({
	id: "/account",
	path: "/account",
	getParentRoute: () => Route$15
});
var IndexRoute = Route$7.update({
	id: "/",
	path: "/",
	getParentRoute: () => Route$15
});
var ApiIptvShareRoute = Route$6.update({
	id: "/api/iptv-share",
	path: "/api/iptv-share",
	getParentRoute: () => Route$15
});
var AccountSettingsRoute = Route$5.update({
	id: "/settings",
	path: "/settings",
	getParentRoute: () => AccountRoute
});
var AccountProfilesRoute = Route$4.update({
	id: "/profiles",
	path: "/profiles",
	getParentRoute: () => AccountRoute
});
var AccountSettingsStremioRoute = Route$3.update({
	id: "/stremio",
	path: "/stremio",
	getParentRoute: () => AccountSettingsRoute
});
var AccountSettingsProvidersRoute = Route$2.update({
	id: "/providers",
	path: "/providers",
	getParentRoute: () => AccountSettingsRoute
});
var AccountSettingsPlaybackRoute = Route$1.update({
	id: "/playback",
	path: "/playback",
	getParentRoute: () => AccountSettingsRoute
});
var AccountSettingsRouteChildren = {
	AccountSettingsIptvRoute: Route.update({
		id: "/iptv",
		path: "/iptv",
		getParentRoute: () => AccountSettingsRoute
	}),
	AccountSettingsPlaybackRoute,
	AccountSettingsProvidersRoute,
	AccountSettingsStremioRoute
};
var AccountRouteChildren = {
	AccountProfilesRoute,
	AccountSettingsRoute: AccountSettingsRoute._addFileChildren(AccountSettingsRouteChildren)
};
var rootRouteChildren = {
	IndexRoute,
	AccountRoute: AccountRoute._addFileChildren(AccountRouteChildren),
	DmcaRoute,
	DownloadRoute,
	IptvRoute,
	LoginRoute,
	SignupRoute,
	TermsRoute,
	ApiIptvShareRoute
};
var routeTree = Route$15._addFileChildren(rootRouteChildren)._addFileTypes();
function getRouter() {
	return createRouter({
		routeTree,
		scrollRestoration: true,
		defaultPreload: "intent"
	});
}
//#endregion
export { getRouter };
