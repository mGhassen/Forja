import { i as require_jsx_runtime } from "../_libs/@radix-ui/react-primitive+[...].mjs";
import { f as Link } from "../_libs/@tanstack/react-router+[...].mjs";
import { n as SiteHeader } from "./site-header-CsI2hv08.mjs";
import { r as SiteFooter } from "./legal-shell-DlcQyaIX.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/login-D1lpvshM.js
var import_jsx_runtime = require_jsx_runtime();
function LoginPage() {
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
		className: "min-h-screen bg-[#0B0A0A] text-[#EDE6DA]",
		children: [
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)(SiteHeader, { solid: true }),
			/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("main", {
				className: "mx-auto flex max-w-lg flex-col px-5 pb-16 pt-24 sm:px-6 sm:pt-28",
				children: [
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
						className: "font-mono-ui text-[11px] uppercase tracking-[0.2em] text-forja-green",
						children: "In progress"
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("h1", {
						className: "mt-4 font-disp text-[clamp(36px,8vw,56px)] uppercase leading-[0.92] tracking-[-0.03em]",
						children: [
							"Log in",
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("br", {}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
								className: "font-serif-i normal-case text-flame",
								children: "coming soon."
							})
						]
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
						className: "mt-6 text-base leading-relaxed text-[rgba(237,230,218,0.55)] sm:text-lg",
						children: "Web accounts are still being built. You can download Forja and watch without signing in — an account will be here soon for syncing across devices."
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
						className: "mt-10 flex flex-wrap gap-4",
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
							to: "/download",
							"data-hover": "",
							className: "btn-magnet inline-flex items-center rounded-full px-8 py-3.5 font-mono-ui text-xs font-bold uppercase tracking-[0.1em]",
							children: "Download Forja"
						}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
							to: "/",
							className: "font-mono-ui inline-flex items-center px-2 py-3.5 text-[11px] uppercase tracking-[0.14em] text-[rgba(237,230,218,0.45)] transition-colors hover:text-[#EDE6DA]",
							children: "Home"
						})]
					})
				]
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)(SiteFooter, {})
		]
	});
}
var SplitComponent = LoginPage;
//#endregion
export { SplitComponent as component };
