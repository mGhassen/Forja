import { a as require_jsx_runtime } from "../_libs/@radix-ui/react-label+[...].mjs";
import { f as Link } from "../_libs/@tanstack/react-router+[...].mjs";
import { a as CardHeader, i as CardDescription, n as Card, o as CardTitle, r as CardContent } from "./card-BLl6aleQ.mjs";
import { f as useUserSettings, i as REMOTE_SETTING_SECTIONS, n as AccountSettingsShell } from "./sync-domains-C0TgAES7.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/account.settings-B4ngRG74.js
var import_jsx_runtime = require_jsx_runtime();
function AccountSettingsPage() {
	const settingsQuery = useUserSettings();
	const updatedByDomain = new Map((settingsQuery.data ?? []).map((row) => [row.domain, row.updated_at]));
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(AccountSettingsShell, {
		title: "Remote settings",
		description: "Manage settings that travel with your account. Device-only options like cache, navigation, and torrent tuning stay in the app.",
		backTo: "/account",
		backLabel: "← Account",
		children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Card, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(CardHeader, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(CardTitle, { children: "Synced from the web or app" }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(CardDescription, { children: "Changes save to your Forja account and apply on the next sign-in or sync in the app." })] }), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(CardContent, {
			className: "space-y-3",
			children: [
				settingsQuery.isLoading && /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
					className: "text-sm text-forja-muted",
					children: "Loading…"
				}),
				settingsQuery.isError && /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
					className: "text-sm text-red-300",
					children: settingsQuery.error instanceof Error ? settingsQuery.error.message : "Failed to load settings"
				}),
				REMOTE_SETTING_SECTIONS.map((section) => {
					const updatedAt = updatedByDomain.get(section.domain);
					return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Link, {
						to: section.href,
						className: "block rounded-lg border border-forja-border bg-forja-surface/40 px-4 py-4 transition hover:border-forja-green/40 hover:bg-forja-surface/70",
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
							className: "flex items-start justify-between gap-4",
							children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
								className: "font-medium",
								children: section.title
							}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
								className: "mt-1 text-sm text-forja-muted",
								children: section.description
							})] }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
								className: "shrink-0 text-sm text-forja-green",
								children: "Open →"
							})]
						}), updatedAt ? /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", {
							className: "mt-2 text-xs text-forja-muted",
							children: ["Last saved ", new Date(updatedAt).toLocaleString()]
						}) : /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
							className: "mt-2 text-xs text-forja-muted",
							children: "Not configured yet"
						})]
					}, section.domain);
				})
			]
		})] }), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Card, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(CardHeader, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(CardTitle, { children: "Stays on your device" }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(CardDescription, { children: "These are intentionally not synced — they depend on hardware, LAN services, or one-time cache." })] }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(CardContent, { children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("ul", {
			className: "list-inside list-disc space-y-1 text-sm text-forja-muted",
			children: [
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("li", { children: "Shell navigation layout and default tab" }),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("li", { children: "Torrent cache size, connections, and provider scores" }),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("li", { children: "Debrid and indexer API keys (for now)" }),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("li", { children: "Cache clears, downloaded updates, and WebView data" }),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("li", { children: "Trakt / Simkl / MDBlist account linking" })
			]
		}) })] })]
	});
}
var SplitComponent = AccountSettingsPage;
//#endregion
export { SplitComponent as component };
