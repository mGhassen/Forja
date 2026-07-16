import { s as require_jsx_runtime } from "../_libs/@radix-ui/react-arrow+[...].mjs";
import { a as useAuth } from "./utils-BshMKIch.mjs";
import { f as LogOut, n as UserRound, o as Settings } from "../_libs/lucide-react.mjs";
import { o as useProfiles, r as ProfileAvatar } from "./use-profiles-CvQVjB9I.mjs";
import { a as useRouterState, c as Outlet, f as Link, m as useNavigate } from "../_libs/@tanstack/react-router+[...].mjs";
import { t as RequireAuth } from "./require-auth-DcPvmrt3.mjs";
import { n as SiteHeader } from "./site-header-_V616WVj.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/account-CL-hgHNv.js
var import_jsx_runtime = require_jsx_runtime();
function AccountPage() {
	const { user, signOut } = useAuth();
	const { profiles, activeProfile } = useProfiles();
	const navigate = useNavigate();
	const pathname = useRouterState({ select: (state) => state.location.pathname });
	if (pathname !== "/account" && pathname !== "/account/") return /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Outlet, {});
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)(RequireAuth, { children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
		className: "min-h-screen",
		children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(SiteHeader, { solid: true }), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("main", {
			className: "mx-auto max-w-4xl px-5 pb-16 pt-24 sm:px-6 sm:pt-28",
			children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("h1", {
				className: "font-display text-3xl tracking-tight sm:text-4xl",
				children: "Account"
			}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
				className: "mt-8 border-t border-forja-border",
				children: [
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
						className: "flex min-h-20 items-center gap-4 border-b border-forja-border px-0.5 py-4",
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(UserRound, { className: "size-6 text-forja-green" }), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
							className: "font-semibold",
							children: "Forja account"
						}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
							className: "mt-0.5 text-sm text-forja-muted",
							children: user?.email
						})] })]
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Link, {
						to: "/account/profiles",
						className: "flex min-h-20 items-center gap-4 border-b border-forja-border px-0.5 py-4 hover:bg-white/2.5",
						children: [
							activeProfile ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)(ProfileAvatar, {
								avatarKey: activeProfile.avatar_key,
								name: activeProfile.name,
								className: "size-10 shrink-0"
							}) : null,
							/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
								className: "min-w-0 flex-1",
								children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
									className: "font-semibold",
									children: "Profiles"
								}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", {
									className: "mt-0.5 text-sm text-forja-muted",
									children: [
										activeProfile?.name ?? "Loading",
										" · ",
										profiles.length,
										" ",
										profiles.length === 1 ? "profile" : "profiles"
									]
								})]
							}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
								className: "text-forja-green",
								children: "→"
							})
						]
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Link, {
						to: "/account/settings",
						className: "flex min-h-20 items-center gap-4 border-b border-forja-border px-0.5 py-4 hover:bg-white/2.5",
						children: [
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Settings, { className: "size-6 text-forja-muted" }),
							/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
								className: "min-w-0 flex-1",
								children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
									className: "font-semibold",
									children: "Remote settings"
								}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
									className: "mt-0.5 text-sm text-forja-muted",
									children: "IPTV, playback, providers, and Stremio addons"
								})]
							}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
								className: "text-forja-green",
								children: "→"
							})
						]
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("button", {
						type: "button",
						className: "flex min-h-20 w-full items-center gap-4 border-b border-forja-border px-0.5 py-4 text-left hover:bg-white/2.5",
						onClick: async () => {
							await signOut();
							navigate({ to: "/" });
						},
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(LogOut, { className: "size-6 text-forja-muted" }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
							className: "font-semibold",
							children: "Log out"
						})]
					})
				]
			})]
		})]
	}) });
}
var SplitComponent = AccountPage;
//#endregion
export { SplitComponent as component };
