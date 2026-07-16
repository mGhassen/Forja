import { i as require_jsx_runtime } from "../_libs/@radix-ui/react-label+[...].mjs";
import { t as AuthProvider } from "./use-auth-xp43OQr8.mjs";
import { t as QueryClient } from "../_libs/tanstack__query-core.mjs";
import { r as QueryClientProvider } from "../_libs/tanstack__react-query.mjs";
import { t as ProfilesProvider } from "./use-profiles-V2uJTVXk.mjs";
import { c as Outlet, d as createRootRoute, i as HeadContent, l as lazyRouteComponent, r as Scripts, s as createRouter, u as createFileRoute } from "../_libs/@tanstack/react-router+[...].mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/router-ZB5ufU6d.js
var import_jsx_runtime = require_jsx_runtime();
var src_default = "/assets/index-qW47cn68.css";
var queryClient = new QueryClient({ defaultOptions: { queries: {
	retry: 1,
	refetchOnWindowFocus: false
} } });
var Route$14 = createRootRoute({
	head: () => ({
		meta: [
			{ charSet: "utf-8" },
			{
				name: "viewport",
				content: "width=device-width, initial-scale=1.0"
			},
			{
				name: "description",
				content: "Forja — free media player for streaming. Playback, live playlists, and controls on Windows, macOS, Linux, and Android TV."
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
var $$splitComponentImporter$13 = () => import("./terms-B6v7gm3d.mjs");
var Route$13 = createFileRoute("/terms")({
	component: lazyRouteComponent($$splitComponentImporter$13, "component"),
	head: () => ({ meta: [{ title: "Terms of use — Forja" }] })
});
var $$splitComponentImporter$12 = () => import("./signup-DZJn3cg3.mjs");
var Route$12 = createFileRoute("/signup")({ component: lazyRouteComponent($$splitComponentImporter$12, "component") });
var $$splitComponentImporter$11 = () => import("./login-DKlZdMRM.mjs");
var Route$11 = createFileRoute("/login")({ component: lazyRouteComponent($$splitComponentImporter$11, "component") });
var $$splitComponentImporter$10 = () => import("./iptv-0u-Iak0K.mjs");
var Route$10 = createFileRoute("/iptv")({ component: lazyRouteComponent($$splitComponentImporter$10, "component") });
var $$splitComponentImporter$9 = () => import("./download-CEmiYcID.mjs");
var Route$9 = createFileRoute("/download")({ component: lazyRouteComponent($$splitComponentImporter$9, "component") });
var $$splitComponentImporter$8 = () => import("./dmca-CLFmixYb.mjs");
var Route$8 = createFileRoute("/dmca")({
	component: lazyRouteComponent($$splitComponentImporter$8, "component"),
	head: () => ({ meta: [{ title: "DMCA & copyright — Forja" }] })
});
var $$splitComponentImporter$7 = () => import("./account-CLIBLK1h.mjs");
var Route$7 = createFileRoute("/account")({ component: lazyRouteComponent($$splitComponentImporter$7, "component") });
var $$splitComponentImporter$6 = () => import("./routes-gTFsPG5D.mjs");
var Route$6 = createFileRoute("/")({ component: lazyRouteComponent($$splitComponentImporter$6, "component") });
var $$splitComponentImporter$5 = () => import("./account.settings-DKb9BPNb.mjs");
var Route$5 = createFileRoute("/account/settings")({ component: lazyRouteComponent($$splitComponentImporter$5, "component") });
var $$splitComponentImporter$4 = () => import("./account.profiles-B2sya13L.mjs");
var Route$4 = createFileRoute("/account/profiles")({ component: lazyRouteComponent($$splitComponentImporter$4, "component") });
var $$splitComponentImporter$3 = () => import("./account.settings.stremio-BA_sbgXR.mjs");
var Route$3 = createFileRoute("/account/settings/stremio")({ component: lazyRouteComponent($$splitComponentImporter$3, "component") });
var $$splitComponentImporter$2 = () => import("./account.settings.providers-BqXM7gjJ.mjs");
var Route$2 = createFileRoute("/account/settings/providers")({ component: lazyRouteComponent($$splitComponentImporter$2, "component") });
var $$splitComponentImporter$1 = () => import("./account.settings.playback-BVv42BXs.mjs");
var Route$1 = createFileRoute("/account/settings/playback")({ component: lazyRouteComponent($$splitComponentImporter$1, "component") });
var $$splitComponentImporter = () => import("./account.settings.iptv-CMxPA31D.mjs");
var Route = createFileRoute("/account/settings/iptv")({ component: lazyRouteComponent($$splitComponentImporter, "component") });
var TermsRoute = Route$13.update({
	id: "/terms",
	path: "/terms",
	getParentRoute: () => Route$14
});
var SignupRoute = Route$12.update({
	id: "/signup",
	path: "/signup",
	getParentRoute: () => Route$14
});
var LoginRoute = Route$11.update({
	id: "/login",
	path: "/login",
	getParentRoute: () => Route$14
});
var IptvRoute = Route$10.update({
	id: "/iptv",
	path: "/iptv",
	getParentRoute: () => Route$14
});
var DownloadRoute = Route$9.update({
	id: "/download",
	path: "/download",
	getParentRoute: () => Route$14
});
var DmcaRoute = Route$8.update({
	id: "/dmca",
	path: "/dmca",
	getParentRoute: () => Route$14
});
var AccountRoute = Route$7.update({
	id: "/account",
	path: "/account",
	getParentRoute: () => Route$14
});
var IndexRoute = Route$6.update({
	id: "/",
	path: "/",
	getParentRoute: () => Route$14
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
	TermsRoute
};
var routeTree = Route$14._addFileChildren(rootRouteChildren)._addFileTypes();
function getRouter() {
	return createRouter({
		routeTree,
		scrollRestoration: true,
		defaultPreload: "intent"
	});
}
//#endregion
export { getRouter };
