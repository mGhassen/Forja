import { a as require_jsx_runtime } from "../_libs/@radix-ui/react-label+[...].mjs";
import { f as Link } from "../_libs/@tanstack/react-router+[...].mjs";
import { n as SiteHeader, t as BrandLogo } from "./site-header-dl4sTjGo.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/legal-shell-CrLn1IML.js
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
	const year = (/* @__PURE__ */ new Date()).getFullYear();
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("footer", {
		className: "relative overflow-hidden border-t border-[rgba(237,230,218,0.12)]",
		children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
			"aria-hidden": true,
			className: "pointer-events-none absolute inset-0",
			style: { background: "radial-gradient(ellipse 50% 60% at 0% 100%, rgba(28,231,131,0.1), transparent 55%), radial-gradient(ellipse 40% 50% at 100% 0%, rgba(255,77,28,0.08), transparent 50%)" }
		}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
			className: "relative mx-auto max-w-[1400px] px-[5vw] pt-16 pb-10 sm:pt-20 sm:pb-12",
			children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
				className: "flex flex-col gap-12 lg:flex-row lg:items-end lg:justify-between lg:gap-16",
				children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					className: "max-w-xl",
					children: [
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)(BrandLogo, {
							to: "/",
							imgClassName: "h-8 w-auto sm:h-10"
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", {
							className: "mt-6 font-disp text-[clamp(28px,5vw,48px)] uppercase leading-[0.92] tracking-[-0.03em]",
							children: [
								"A player built",
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("br", {}),
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: "font-serif-i normal-case text-flame",
									children: "to stream."
								})
							]
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
							className: "mt-4 max-w-md text-base leading-relaxed text-[rgba(237,230,218,0.5)]",
							children: "Free media player for streaming playback — on your desk, couch, or big screen. Forja does not host media files."
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
							to: "/download",
							"data-hover": "",
							className: "btn-magnet mt-8 inline-flex items-center justify-center rounded-full px-7 py-3.5 font-mono-ui text-[11px] font-bold uppercase tracking-[0.12em] shadow-[0_0_28px_rgba(28,231,131,0.28)]",
							children: "Get the app"
						})
					]
				}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					className: "grid grid-cols-2 gap-10 sm:gap-16",
					children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
						className: "font-mono-ui text-[10px] uppercase tracking-[0.2em] text-brand",
						children: "Explore"
					}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("ul", {
						className: "mt-4 space-y-3 font-mono-ui text-[12px] uppercase tracking-[0.12em] text-[rgba(237,230,218,0.55)]",
						children: [
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("li", { children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
								to: "/",
								className: "transition-colors hover:text-[#EDE6DA]",
								children: "Streaming Player"
							}) }),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("li", { children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
								to: "/iptv",
								className: "transition-colors hover:text-[#EDE6DA]",
								children: "Live Player"
							}) }),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("li", { children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
								to: "/download",
								className: "transition-colors hover:text-[#EDE6DA]",
								children: "Download"
							}) })
						]
					})] }), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
						className: "font-mono-ui text-[10px] uppercase tracking-[0.2em] text-flame",
						children: "Legal"
					}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("ul", {
						className: "mt-4 space-y-3 font-mono-ui text-[12px] uppercase tracking-[0.12em] text-[rgba(237,230,218,0.55)]",
						children: [
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("li", { children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
								to: "/terms",
								className: "transition-colors hover:text-[#EDE6DA]",
								children: "Terms"
							}) }),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("li", { children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
								to: "/dmca",
								className: "transition-colors hover:text-[#EDE6DA]",
								children: "DMCA"
							}) }),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("li", { children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
								to: "/login",
								className: "transition-colors hover:text-[#EDE6DA]",
								children: "Log in"
							}) })
						]
					})] })]
				})]
			}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
				className: "mt-14 space-y-5 border-t border-[rgba(237,230,218,0.1)] pt-6",
				children: [
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", {
						className: "max-w-3xl text-sm leading-relaxed text-[rgba(237,230,218,0.48)] sm:text-[15px]",
						children: [
							"Forja does not host, upload, or store media files. It is a player app that helps you open streams and playlists you connect — we are not the owners of third-party content.",
							" ",
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
								to: "/dmca",
								className: "text-[rgba(237,230,218,0.72)] underline decoration-[rgba(237,230,218,0.25)] underline-offset-4 transition-colors hover:text-brand hover:decoration-brand",
								children: "DMCA / copyright notice"
							}),
							"."
						]
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
						className: "max-w-3xl text-[11px] leading-relaxed text-[rgba(237,230,218,0.32)] sm:text-xs",
						children: "Marketing stills from Blender Foundation open movies (Big Buck Bunny, Sintel, Tears of Steel, Sprite Fright, Cosmos Laundromat) — used under Creative Commons Attribution."
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
						className: "flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between",
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", {
							className: "font-mono-ui text-[10px] uppercase tracking-[0.16em] text-[rgba(237,230,218,0.35)]",
							children: [
								"© ",
								year,
								" Forja · Streaming player"
							]
						}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
							className: "font-mono-ui text-[10px] uppercase tracking-[0.16em] text-[rgba(237,230,218,0.28)]",
							children: "Desk · Couch · TV"
						})]
					})
				]
			})]
		})]
	});
}
//#endregion
export { LegalSection as n, SiteFooter as r, LegalPage as t };
