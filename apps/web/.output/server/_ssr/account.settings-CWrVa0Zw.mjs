import { a as require_jsx_runtime } from "../_libs/@radix-ui/react-label+[...].mjs";
import { i as useAuth, n as supabase, r as supabaseConfigured } from "./use-auth-xp43OQr8.mjs";
import { f as Link } from "../_libs/@tanstack/react-router+[...].mjs";
import { n as SiteHeader } from "./site-header-dl4sTjGo.mjs";
import { a as CardHeader, i as CardDescription, n as Card, o as CardTitle, r as CardContent, t as Button } from "./card-7SsD7bDu.mjs";
import { t as RequireAuth } from "./require-auth-DtXzK_my.mjs";
import { t as useQuery } from "../_libs/tanstack__react-query.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/account.settings-CWrVa0Zw.js
var import_jsx_runtime = require_jsx_runtime();
function AccountSettingsPage() {
	const { user } = useAuth();
	const settingsQuery = useQuery({
		queryKey: ["user_settings", user?.id],
		enabled: Boolean(user?.id && supabaseConfigured),
		queryFn: async () => {
			const { data, error } = await supabase.from("user_settings").select("*").eq("user_id", user.id).order("domain");
			if (error) throw error;
			return data ?? [];
		}
	});
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)(RequireAuth, { children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
		className: "min-h-screen",
		children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(SiteHeader, { solid: true }), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("main", {
			className: "mx-auto max-w-2xl px-5 pb-16 pt-24 sm:px-6 sm:pt-28",
			children: [
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Button, {
					asChild: true,
					variant: "ghost",
					size: "sm",
					className: "-ml-2 mb-6",
					children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
						to: "/account",
						children: "← Account"
					})
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
					className: "font-display text-sm uppercase tracking-[0.3em] text-forja-green",
					children: "Settings sync"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("h1", {
					className: "mt-3 font-display text-3xl tracking-tight sm:text-4xl",
					children: "Cloud domains"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
					className: "mt-4 text-forja-muted",
					children: "Domains synced from the Forja app appear here. Sync choices live in the app — this view is status only."
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Card, {
					className: "mt-10",
					children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(CardHeader, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(CardTitle, { children: "Synced domains" }), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(CardDescription, { children: [
						"Latest ",
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)("code", { children: "updated_at" }),
						" per domain."
					] })] }), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(CardContent, { children: [
						settingsQuery.isLoading && /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
							className: "text-sm text-forja-muted",
							children: "Loading…"
						}),
						settingsQuery.isError && /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
							className: "text-sm text-red-300",
							children: settingsQuery.error instanceof Error ? settingsQuery.error.message : "Failed to load settings"
						}),
						settingsQuery.data && settingsQuery.data.length === 0 && /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
							className: "text-sm text-forja-muted",
							children: "No domains synced yet. When domains are enabled in Forja, they show up here."
						}),
						settingsQuery.data && settingsQuery.data.length > 0 && /* @__PURE__ */ (0, import_jsx_runtime.jsx)("ul", {
							className: "divide-y divide-forja-border",
							children: settingsQuery.data.map((row) => /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("li", {
								className: "flex items-center justify-between gap-4 py-3 first:pt-0 last:pb-0",
								children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: "font-medium",
									children: row.domain
								}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: "text-sm text-forja-muted",
									children: new Date(row.updated_at).toLocaleString()
								})]
							}, row.domain))
						})
					] })]
				})
			]
		})]
	}) });
}
var SplitComponent = AccountSettingsPage;
//#endregion
export { SplitComponent as component };
