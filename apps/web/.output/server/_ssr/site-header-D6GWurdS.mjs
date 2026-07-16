import { r as __toESM } from "../_runtime.mjs";
import { n as require_react } from "../_libs/@radix-ui/react-compose-refs+[...].mjs";
import { a as require_jsx_runtime } from "../_libs/@radix-ui/react-label+[...].mjs";
import { i as useAuth } from "./use-auth-BFtWcVvU.mjs";
import { a as useRouterState, f as Link } from "../_libs/@tanstack/react-router+[...].mjs";
import { n as clsx } from "../_libs/class-variance-authority+clsx.mjs";
import { t as twMerge } from "../_libs/tailwind-merge.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/site-header-D6GWurdS.js
var import_react = /* @__PURE__ */ __toESM(require_react());
var import_jsx_runtime = require_jsx_runtime();
function cn(...inputs) {
	return twMerge(clsx(inputs));
}
/** Full Forja wordmark SVG only — no F-mark asset. */
function BrandLogo({ tone = "brand", className, imgClassName, to = "/" }) {
	const img = /* @__PURE__ */ (0, import_jsx_runtime.jsx)("img", {
		src: tone === "paper" ? "/brand/logo-light.svg" : "/brand/logo-dark.svg",
		alt: "Forja",
		className: cn("h-8 w-auto object-contain object-left", imgClassName)
	});
	if (to) return /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
		to,
		className: cn("inline-flex items-center", className),
		children: img
	});
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
		className: cn("inline-flex items-center", className),
		children: img
	});
}
var idleLink = "text-[15px] font-medium tracking-wide text-[#EDE6DA]/85 transition-[color,font-weight] hover:font-bold hover:text-forja-green sm:text-base";
var activeLink = "text-[15px] font-bold tracking-wide text-forja-green transition-colors sm:text-base";
function NavLink({ to, children, exact = false, onNavigate, className }) {
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
		to,
		activeOptions: { exact },
		onClick: onNavigate,
		className: (state) => cn(state.isActive ? activeLink : idleLink, className),
		children
	});
}
function SiteHeader({ solid = false }) {
	const { user, loading } = useAuth();
	const [open, setOpen] = (0, import_react.useState)(false);
	(0, import_react.useEffect)(() => {
		setOpen(false);
	}, [useRouterState({ select: (s) => s.location.pathname })]);
	(0, import_react.useEffect)(() => {
		if (!open) return;
		const prev = document.body.style.overflow;
		document.body.style.overflow = "hidden";
		const onKey = (e) => {
			if (e.key === "Escape") setOpen(false);
		};
		window.addEventListener("keydown", onKey);
		return () => {
			document.body.style.overflow = prev;
			window.removeEventListener("keydown", onKey);
		};
	}, [open]);
	const close = () => setOpen(false);
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("header", {
		className: cn("fixed inset-x-0 top-0 z-40 border-b border-[rgba(237,230,218,0.1)]", solid ? "bg-[#0B0A0A]/95 backdrop-blur-md" : "bg-[#0B0A0A]/88 backdrop-blur-md"),
		children: [
			/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
				className: "mx-auto flex h-16 max-w-[1400px] items-center justify-between gap-4 px-[5vw] sm:h-[5.5rem]",
				children: [
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)(BrandLogo, { imgClassName: "h-8 w-auto sm:h-12" }),
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("nav", {
						className: "hidden items-center gap-x-8 md:flex",
						children: [
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)(NavLink, {
								to: "/",
								exact: true,
								children: "Home"
							}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)(NavLink, {
								to: "/iptv",
								children: "IPTV Player"
							}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)(NavLink, {
								to: "/download",
								children: "Downloads"
							}),
							!loading && user ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
								to: "/account",
								activeOptions: { exact: false },
								className: (state) => cn("rounded-full px-4 py-2 text-[15px] transition-colors sm:text-base", state.isActive ? "bg-forja-green font-bold text-[#0B0A0A]" : "bg-forja-green/15 font-semibold text-forja-green hover:bg-forja-green/25"),
								children: "Account"
							}) : /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
								to: "/login",
								className: (state) => cn("rounded-full border px-4 py-2 text-[15px] transition-colors sm:text-base", state.isActive ? "border-forja-green bg-forja-green/15 font-bold text-forja-green" : "border-[rgba(237,230,218,0.25)] font-semibold text-[#EDE6DA] hover:border-forja-green hover:font-bold hover:text-forja-green"),
								children: "Log in"
							})
						]
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("button", {
						type: "button",
						className: "relative z-50 flex h-11 w-11 items-center justify-center rounded-full border border-[rgba(237,230,218,0.2)] text-[#EDE6DA] md:hidden",
						"aria-expanded": open,
						"aria-controls": "mobile-nav",
						"aria-label": open ? "Close menu" : "Open menu",
						onClick: () => setOpen((v) => !v),
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
							className: "sr-only",
							children: open ? "Close" : "Menu"
						}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("span", {
							className: "relative block h-3.5 w-5",
							"aria-hidden": true,
							children: [
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", { className: cn("absolute left-0 block h-0.5 w-full bg-current transition-transform duration-200", open ? "top-1.5 rotate-45" : "top-0") }),
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", { className: cn("absolute left-0 top-1.5 block h-0.5 w-full bg-current transition-opacity duration-200", open && "opacity-0") }),
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", { className: cn("absolute left-0 block h-0.5 w-full bg-current transition-transform duration-200", open ? "top-1.5 -rotate-45" : "top-3") })
							]
						})]
					})
				]
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
				id: "mobile-nav",
				className: cn("fixed inset-x-0 top-16 z-40 border-b border-[rgba(237,230,218,0.12)] bg-[#0B0A0A]/98 backdrop-blur-lg transition-[opacity,visibility] duration-200 md:hidden", open ? "visible opacity-100" : "invisible pointer-events-none opacity-0"),
				children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("nav", {
					className: "flex max-h-[calc(100dvh-4rem)] flex-col gap-1 overflow-y-auto px-[5vw] py-4",
					children: [
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)(NavLink, {
							to: "/",
							exact: true,
							onNavigate: close,
							className: "rounded-lg px-3 py-3.5 text-lg",
							children: "Home"
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)(NavLink, {
							to: "/iptv",
							onNavigate: close,
							className: "rounded-lg px-3 py-3.5 text-lg",
							children: "IPTV Player"
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)(NavLink, {
							to: "/download",
							onNavigate: close,
							className: "rounded-lg px-3 py-3.5 text-lg",
							children: "Downloads"
						}),
						!loading && user ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
							to: "/account",
							onClick: close,
							className: "mt-2 rounded-full bg-forja-green px-4 py-3.5 text-center text-base font-bold text-[#0B0A0A]",
							children: "Account"
						}) : /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
							to: "/login",
							onClick: close,
							className: "mt-2 rounded-full border border-forja-green/50 px-4 py-3.5 text-center text-base font-semibold text-forja-green",
							children: "Log in"
						})
					]
				})
			}),
			open ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("button", {
				type: "button",
				"aria-label": "Dismiss menu",
				className: "fixed inset-0 top-16 z-30 bg-black/55 md:hidden",
				onClick: close
			}) : null
		]
	});
}
//#endregion
export { SiteHeader as n, cn as r, BrandLogo as t };
