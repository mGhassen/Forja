import { r as __toESM } from "../_runtime.mjs";
import { n as require_react } from "../_libs/@radix-ui/react-compose-refs+[...].mjs";
import { a as require_jsx_runtime } from "../_libs/@radix-ui/react-label+[...].mjs";
import { i as useAuth } from "./use-auth-xp43OQr8.mjs";
import { a as useRouterState, f as Link } from "../_libs/@tanstack/react-router+[...].mjs";
import { n as clsx } from "../_libs/class-variance-authority+clsx.mjs";
import { t as twMerge } from "../_libs/tailwind-merge.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/site-header-dl4sTjGo.js
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
var LINKS = [{
	to: "/",
	label: "Streaming Player",
	exact: true
}, {
	to: "/iptv",
	label: "Live Player"
}];
function NavLink({ to, children, exact = false, onNavigate, className, variant = "desktop" }) {
	const pathname = useRouterState({ select: (s) => s.location.pathname });
	const isActive = exact ? pathname === to : pathname === to || pathname.startsWith(`${to}/`);
	const mobile = variant === "mobile";
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Link, {
		to,
		activeOptions: { exact },
		onClick: onNavigate,
		"data-hover": "",
		className: cn("group relative inline-flex items-center font-disp font-bold uppercase transition-all duration-200 ease-out will-change-transform", mobile ? cn("min-w-0 justify-start rounded-none border-0 bg-transparent px-0 py-3 text-[clamp(2.4rem,12vw,3.75rem)] leading-[0.95] tracking-[-0.04em] shadow-none", "hover:translate-y-0 hover:border-0 hover:bg-transparent hover:shadow-none", isActive ? "text-forja-green" : "text-[rgba(237,230,218,0.4)] hover:text-forja-green") : cn("min-w-[7.5rem] justify-center rounded-xl border border-transparent px-4 py-2.5 text-[13px] tracking-tight sm:min-w-[9.5rem] sm:px-5 sm:text-base", "hover:-translate-y-0.5 hover:border-forja-green/40 hover:bg-forja-green/15 hover:text-forja-green hover:shadow-[0_10px_28px_-12px_rgba(28,231,131,0.55)]", "active:translate-y-0 active:scale-[0.98]", isActive ? "border-forja-green bg-forja-green text-[#0B0A0A] shadow-[0_0_22px_rgba(28,231,131,0.4)] hover:border-forja-green-dim hover:bg-forja-green-dim hover:text-[#0B0A0A]" : "text-[rgba(237,230,218,0.72)]"), className),
		children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
			className: "relative z-1",
			children
		}), !mobile && !isActive ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
			"aria-hidden": true,
			className: "pointer-events-none absolute bottom-1.5 left-1/2 h-0.5 w-0 -translate-x-1/2 rounded-full bg-forja-green transition-all duration-200 ease-out group-hover:w-6"
		}) : null]
	});
}
function SiteHeader({ solid = false }) {
	const { user, loading } = useAuth();
	const [open, setOpen] = (0, import_react.useState)(false);
	const pathname = useRouterState({ select: (s) => s.location.pathname });
	(0, import_react.useEffect)(() => {
		setOpen(false);
	}, [pathname]);
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
	const accountActive = pathname.startsWith("/account");
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("header", {
		className: "fixed inset-x-0 top-0 z-40",
		children: [
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
				"aria-hidden": true,
				className: cn("pointer-events-none absolute inset-x-0 top-0 h-28 bg-linear-to-b to-transparent", solid ? "from-[#0B0A0A]/90" : "from-[#0B0A0A]/70")
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
				className: "relative mx-auto max-w-[1400px] px-[4vw] pt-3 sm:pt-4",
				children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					className: cn("flex items-center gap-3 rounded-2xl border border-[rgba(237,230,218,0.12)] px-3 py-2.5 shadow-[inset_0_1px_0_rgba(237,230,218,0.08),0_12px_40px_-20px_rgba(0,0,0,0.55)] backdrop-blur-md backdrop-saturate-150 sm:gap-4 sm:px-4 sm:py-3", solid ? "bg-[#0B0A0A]/45" : "bg-[#0B0A0A]/35"),
					children: [
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)(BrandLogo, { imgClassName: "h-7 w-auto sm:h-8" }),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
							"aria-hidden": true,
							className: "hidden h-6 w-px shrink-0 bg-forja-border md:block"
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)("nav", {
							"aria-label": "Primary",
							className: "hidden flex-1 items-center justify-center gap-3 md:flex lg:gap-4",
							children: LINKS.map((link) => /* @__PURE__ */ (0, import_jsx_runtime.jsx)(NavLink, {
								to: link.to,
								exact: link.exact,
								children: link.label
							}, link.to))
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
							className: "ml-auto hidden items-center gap-2 md:flex",
							children: [!loading && user ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
								to: "/account",
								"data-hover": "",
								className: cn("inline-flex items-center justify-center rounded-xl px-3.5 py-2.5 font-mono text-[11px] font-bold uppercase tracking-[0.12em] transition-all duration-200", accountActive ? "text-forja-green" : "text-[rgba(237,230,218,0.55)] hover:bg-forja-green/12 hover:text-forja-green"),
								children: "Account"
							}) : /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
								to: "/login",
								"data-hover": "",
								className: "inline-flex items-center justify-center rounded-xl px-3.5 py-2.5 font-mono text-[11px] font-bold uppercase tracking-[0.12em] text-[rgba(237,230,218,0.55)] transition-all duration-200 hover:bg-forja-green/12 hover:text-forja-green",
								children: "Log in"
							}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
								to: "/download",
								"data-hover": "",
								className: "inline-flex items-center justify-center rounded-full bg-forja-green px-5 py-2.5 font-mono text-[11px] font-bold uppercase tracking-[0.1em] text-[#0B0A0A] shadow-[0_0_24px_rgba(28,231,131,0.28)] transition-all duration-200 hover:-translate-y-0.5 hover:bg-forja-flame hover:shadow-[0_0_28px_rgba(255,77,28,0.35)]",
								children: "Get Forja"
							})]
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("button", {
							type: "button",
							className: cn("ml-auto flex h-10 w-10 shrink-0 items-center justify-center rounded-xl border text-[#EDE6DA] transition-colors md:hidden", open ? "border-forja-green/40 bg-forja-green/10 text-forja-green" : "border-[rgba(237,230,218,0.16)] bg-[rgba(237,230,218,0.04)]"),
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
				})
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
				id: "mobile-nav",
				className: cn("fixed inset-0 z-50 flex flex-col bg-[#0B0A0A] transition-[opacity,visibility] duration-200 md:hidden", open ? "visible opacity-100" : "invisible pointer-events-none opacity-0"),
				children: [
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
						className: "flex items-center justify-between px-[4vw] pt-3 pb-2",
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(BrandLogo, { imgClassName: "h-7 w-auto" }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("button", {
							type: "button",
							className: "flex h-10 w-10 items-center justify-center rounded-xl border border-[rgba(237,230,218,0.16)] text-[#EDE6DA]",
							"aria-label": "Close menu",
							onClick: close,
							children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
								"aria-hidden": true,
								className: "text-xl leading-none",
								children: "×"
							})
						})]
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("nav", {
						"aria-label": "Primary",
						className: "flex flex-1 flex-col justify-center gap-2 px-[6vw] pb-10",
						children: [
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)(NavLink, {
								to: "/",
								exact: true,
								onNavigate: close,
								variant: "mobile",
								children: "Streaming Player"
							}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)(NavLink, {
								to: "/iptv",
								onNavigate: close,
								variant: "mobile",
								children: "Live Player"
							}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)(NavLink, {
								to: "/download",
								onNavigate: close,
								variant: "mobile",
								className: "text-forja-flame hover:text-forja-flame-dim",
								children: "Get Forja"
							}),
							!loading && user ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)(NavLink, {
								to: "/account",
								onNavigate: close,
								variant: "mobile",
								children: "Account"
							}) : /* @__PURE__ */ (0, import_jsx_runtime.jsx)(NavLink, {
								to: "/login",
								onNavigate: close,
								variant: "mobile",
								children: "Log in"
							})
						]
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
						className: "px-[6vw] pb-8 font-mono text-[10px] uppercase tracking-[0.18em] text-[rgba(237,230,218,0.35)]",
						children: "Free · No ads · Desk to TV"
					})
				]
			})
		]
	});
}
//#endregion
export { SiteHeader as n, cn as r, BrandLogo as t };
