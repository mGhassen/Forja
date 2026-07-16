import { i as require_jsx_runtime } from "../_libs/@radix-ui/react-primitive+[...].mjs";
import { f as Link } from "../_libs/@tanstack/react-router+[...].mjs";
import { n as SiteHeader, t as BrandLogo } from "./site-header-CsI2hv08.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/legal-shell-DlcQyaIX.js
var import_jsx_runtime = require_jsx_runtime();
function LegalPage({ eyebrow, title, children }) {
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
		className: "min-h-screen bg-[#0B0A0A] text-[#EDE6DA]",
		children: [
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)(SiteHeader, { solid: true }),
			/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("main", {
				className: "mx-auto max-w-3xl px-5 pb-20 pt-24 sm:px-6 sm:pt-28",
				children: [
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
						className: "font-mono-ui text-[11px] uppercase tracking-[0.2em] text-forja-green",
						children: eyebrow
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)("h1", {
						className: "mt-4 font-disp text-[clamp(36px,7vw,56px)] uppercase leading-[0.92] tracking-[-0.03em]",
						children: title
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
						className: "mt-10 space-y-8 text-base leading-relaxed text-[rgba(237,230,218,0.62)] sm:text-lg",
						children
					})
				]
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)(SiteFooter, {})
		]
	});
}
function LegalSection({ title, children }) {
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("section", {
		className: "space-y-3 border-t border-[rgba(237,230,218,0.12)] pt-8",
		children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("h2", {
			className: "font-disp text-xl uppercase tracking-tight text-[#EDE6DA] sm:text-2xl",
			children: title
		}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
			className: "space-y-3",
			children
		})]
	});
}
function SiteFooter() {
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("footer", {
		className: "border-t border-[rgba(237,230,218,0.14)] px-[5vw] py-8",
		children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
			className: "mx-auto flex max-w-[1400px] flex-col gap-6 sm:flex-row sm:items-center sm:justify-between",
			children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(BrandLogo, {
				to: "/",
				imgClassName: "h-6 w-auto"
			}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("nav", {
				className: "font-mono-ui flex flex-wrap gap-x-5 gap-y-2 text-[11px] uppercase tracking-[0.12em] text-[rgba(237,230,218,0.4)]",
				children: [
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
						to: "/download",
						className: "transition-colors hover:text-forja-green",
						children: "Downloads"
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
						to: "/terms",
						className: "transition-colors hover:text-forja-green",
						children: "Terms"
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
						to: "/dmca",
						className: "transition-colors hover:text-forja-green",
						children: "DMCA"
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("span", { children: [
						"© ",
						(/* @__PURE__ */ new Date()).getFullYear(),
						" Forja"
					] })
				]
			})]
		})
	});
}
//#endregion
export { LegalSection as n, SiteFooter as r, LegalPage as t };
