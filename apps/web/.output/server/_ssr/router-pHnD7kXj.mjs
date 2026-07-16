import { i as require_jsx_runtime } from "../_libs/@radix-ui/react-primitive+[...].mjs";
import { t as AuthProvider } from "./use-auth-BFtWcVvU.mjs";
import { c as Outlet, d as createRootRoute, i as HeadContent, l as lazyRouteComponent, r as Scripts, s as createRouter, u as createFileRoute } from "../_libs/@tanstack/react-router+[...].mjs";
import { t as QueryClient } from "../_libs/tanstack__query-core.mjs";
import { n as QueryClientProvider } from "../_libs/tanstack__react-query.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/router-pHnD7kXj.js
var import_jsx_runtime = require_jsx_runtime();
var src_default = "/assets/index-DuVRL5rO.css";
var queryClient = new QueryClient({ defaultOptions: { queries: {
	retry: 1,
	refetchOnWindowFocus: false
} } });
var Route$9 = createRootRoute({
	head: () => ({
		meta: [
			{ charSet: "utf-8" },
			{
				name: "viewport",
				content: "width=device-width, initial-scale=1.0"
			},
			{
				name: "description",
				content: "Forja — free streaming app for movies, series, anime, live sport, and IPTV. No ads. Windows, macOS, Linux, and Android TV."
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
		children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(AuthProvider, { children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Outlet, {}) })
	}) });
}
function RootDocument({ children }) {
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("html", {
		lang: "en",
		children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("head", { children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(HeadContent, {}) }), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("body", { children: [children, /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Scripts, {})] })]
	});
}
var $$splitComponentImporter$8 = () => import("./terms-CwTCbYkK.mjs");
var Route$8 = createFileRoute("/terms")({
	component: lazyRouteComponent($$splitComponentImporter$8, "component"),
	head: () => ({ meta: [{ title: "Terms of use — Forja" }] })
});
var $$splitComponentImporter$7 = () => import("./signup-CbqJdNli.mjs");
var Route$7 = createFileRoute("/signup")({ component: lazyRouteComponent($$splitComponentImporter$7, "component") });
var $$splitComponentImporter$6 = () => import("./login-D1lpvshM.mjs");
var Route$6 = createFileRoute("/login")({ component: lazyRouteComponent($$splitComponentImporter$6, "component") });
var $$splitComponentImporter$5 = () => import("./iptv-BtfN0ng8.mjs");
var Route$5 = createFileRoute("/iptv")({ component: lazyRouteComponent($$splitComponentImporter$5, "component") });
var $$splitComponentImporter$4 = () => import("./download-BhRtSvzh.mjs");
var Route$4 = createFileRoute("/download")({ component: lazyRouteComponent($$splitComponentImporter$4, "component") });
var $$splitComponentImporter$3 = () => import("./dmca-BPczSI9o.mjs");
var Route$3 = createFileRoute("/dmca")({
	component: lazyRouteComponent($$splitComponentImporter$3, "component"),
	head: () => ({ meta: [{ title: "DMCA & copyright — Forja" }] })
});
var $$splitComponentImporter$2 = () => import("./account-BFT02Beh.mjs");
var Route$2 = createFileRoute("/account")({ component: lazyRouteComponent($$splitComponentImporter$2, "component") });
var $$splitComponentImporter$1 = () => import("./routes-cd2Ql6cK.mjs");
var Route$1 = createFileRoute("/")({ component: lazyRouteComponent($$splitComponentImporter$1, "component") });
var $$splitComponentImporter = () => import("./account.settings-CfaE88bX.mjs");
var Route = createFileRoute("/account/settings")({ component: lazyRouteComponent($$splitComponentImporter, "component") });
var TermsRoute = Route$8.update({
	id: "/terms",
	path: "/terms",
	getParentRoute: () => Route$9
});
var SignupRoute = Route$7.update({
	id: "/signup",
	path: "/signup",
	getParentRoute: () => Route$9
});
var LoginRoute = Route$6.update({
	id: "/login",
	path: "/login",
	getParentRoute: () => Route$9
});
var IptvRoute = Route$5.update({
	id: "/iptv",
	path: "/iptv",
	getParentRoute: () => Route$9
});
var DownloadRoute = Route$4.update({
	id: "/download",
	path: "/download",
	getParentRoute: () => Route$9
});
var DmcaRoute = Route$3.update({
	id: "/dmca",
	path: "/dmca",
	getParentRoute: () => Route$9
});
var AccountRoute = Route$2.update({
	id: "/account",
	path: "/account",
	getParentRoute: () => Route$9
});
var IndexRoute = Route$1.update({
	id: "/",
	path: "/",
	getParentRoute: () => Route$9
});
var AccountRouteChildren = { AccountSettingsRoute: Route.update({
	id: "/settings",
	path: "/settings",
	getParentRoute: () => AccountRoute
}) };
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
var routeTree = Route$9._addFileChildren(rootRouteChildren)._addFileTypes();
function getRouter() {
	return createRouter({
		routeTree,
		scrollRestoration: true,
		defaultPreload: "intent"
	});
}
//#endregion
export { getRouter };
