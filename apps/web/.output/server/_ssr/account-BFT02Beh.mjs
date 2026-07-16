import { i as require_jsx_runtime } from "../_libs/@radix-ui/react-primitive+[...].mjs";
import { i as useAuth } from "./use-auth-BFtWcVvU.mjs";
import { f as Link, m as useNavigate } from "../_libs/@tanstack/react-router+[...].mjs";
import { n as SiteHeader, r as cn } from "./site-header-CsI2hv08.mjs";
import { a as CardHeader, i as CardDescription, n as Card, o as CardTitle, r as CardContent, s as RequireAuth, t as Button } from "./require-auth-PRL8PnzQ.mjs";
import { t as Root } from "../_libs/radix-ui__react-separator.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/account-BFT02Beh.js
var import_jsx_runtime = require_jsx_runtime();
function Separator({ className, orientation = "horizontal", ...props }) {
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Root, {
		decorative: true,
		orientation,
		className: cn("shrink-0 bg-forja-border", orientation === "horizontal" ? "h-px w-full" : "h-full w-px", className),
		...props
	});
}
function AccountPage() {
	const { user, signOut } = useAuth();
	const navigate = useNavigate();
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)(RequireAuth, { children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
		className: "min-h-screen",
		children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(SiteHeader, { solid: true }), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("main", {
			className: "mx-auto max-w-2xl px-5 pb-16 pt-24 sm:px-6 sm:pt-28",
			children: [
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
					className: "font-display text-sm uppercase tracking-[0.3em] text-forja-green",
					children: "Account"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("h1", {
					className: "mt-3 font-display text-3xl tracking-tight sm:text-4xl",
					children: "Forja account"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Card, {
					className: "mt-10",
					children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(CardHeader, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(CardTitle, { children: "Logged in" }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(CardDescription, { children: user?.email })] }), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(CardContent, {
						className: "space-y-4",
						children: [
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
								className: "text-sm text-forja-muted",
								children: "Cloud settings sync uses the same project as the Forja app. Domains are managed in the app; this page shows status."
							}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Separator, {}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
								className: "flex flex-wrap gap-3",
								children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Button, {
									asChild: true,
									children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
										to: "/account/settings",
										children: "Settings sync"
									})
								}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Button, {
									variant: "secondary",
									onClick: async () => {
										await signOut();
										navigate({ to: "/" });
									},
									children: "Log out"
								})]
							})
						]
					})]
				})
			]
		})]
	}) });
}
var SplitComponent = AccountPage;
//#endregion
export { SplitComponent as component };
