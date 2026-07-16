import { a as require_jsx_runtime } from "../_libs/@radix-ui/react-label+[...].mjs";
import { f as Link } from "../_libs/@tanstack/react-router+[...].mjs";
import { n as SiteHeader, t as BrandLogo } from "./site-header-D6GWurdS.mjs";
import { n as Reveal, t as CustomCursor } from "./start-download-CpAgqJjI.mjs";
import { t as PlatformDownloadButtons } from "./platform-download-buttons-BHwQV6P1.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/iptv-BYrDlMY7.js
var import_jsx_runtime = require_jsx_runtime();
/** Player capabilities — from live IPTV feature docs (user-facing). */
var PLAYER_POWERS = [
	{
		title: "Channel guide",
		copy: "Flip groups and channels without leaving the picture — the guide lives inside the player.",
		accent: "flame"
	},
	{
		title: "Find anything fast",
		copy: "Search by name or category while you watch. Close it and you’re back in the stream.",
		accent: "brand"
	},
	{
		title: "What’s on now",
		copy: "See what’s playing and what’s next — with progress — when your list provides a guide.",
		accent: "flame"
	},
	{
		title: "Live, films & series",
		copy: "One player for live channels, movie night, and full seasons — switch the mood, keep the screen.",
		accent: "brand"
	},
	{
		title: "Audio & subtitles",
		copy: "Pick the track you need and load captions when the stream supports them.",
		accent: "flame"
	},
	{
		title: "Your list. Your rules.",
		copy: "Bring the channels you already have. Favorites stay on top. Add once — watch every night.",
		accent: "brand"
	}
];
var tmdbPoster = (path) => `https://image.tmdb.org/t/p/w342${path}`;
var MODES = [
	{
		k: "Live",
		v: "Sports, news, and channels that never sleep.",
		accent: "flame",
		posters: [
			"/95BDrWmcfJDEa2WCfjmLgi67jhi.jpg",
			"/dR1Ju50iudrOh3YgfwkAU1g2HZe.jpg",
			"/cvsXj3I9Q2iyyIo95AecSd1tad7.jpg"
		]
	},
	{
		k: "Movies",
		v: "Film night from the same player as the match.",
		accent: "brand",
		posters: [
			"/1pdfLvkbY9ohJlCjQH2CZjjYVvJ.jpg",
			"/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg",
			"/H6vke7zGiuLsz4v4RPeReb9rsv.jpg"
		]
	},
	{
		k: "Series",
		v: "Seasons ready when the live night ends.",
		accent: "flame",
		posters: [
			"/7O4iVfOMQmdCSxhOg1WnzG1AgYT.jpg",
			"/c15BtJxCXMrISLVmysdsnZUPQft.jpg",
			"/dmo6TYuuJgaYinXBPjrgG9mB5od.jpg"
		]
	}
];
var MARQUEE = [
	"Channel guide",
	"Search",
	"What’s on",
	"Live",
	"Movies",
	"Series",
	"Audio",
	"Subtitles",
	"No ads"
];
function IptvPage() {
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
		className: "film-grain relative bg-[#0B0A0A] text-[#EDE6DA]",
		children: [
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)(CustomCursor, {}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)(SiteHeader, {}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("main", {
				className: "relative pt-16 sm:pt-24",
				children: [
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("header", {
						className: "relative overflow-hidden px-[5vw] pb-12 pt-6 sm:pb-16 sm:pt-10 lg:pb-24 lg:pt-14",
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
							"aria-hidden": true,
							className: "pointer-events-none absolute inset-0",
							style: { background: "radial-gradient(ellipse 60% 55% at 80% 35%, rgba(255,77,28,0.2), transparent 55%), radial-gradient(ellipse 45% 50% at 15% 60%, rgba(28,231,131,0.14), transparent 50%)" }
						}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
							className: "relative z-[2] mx-auto grid max-w-[1400px] gap-12 lg:grid-cols-[1fr_1.05fr] lg:items-center",
							children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", { children: [
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
									className: "mb-6 flex flex-wrap items-center gap-3",
									children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
										className: "rounded-full border border-brand/40 bg-brand/10 px-3 py-1 font-mono-ui text-[10px] uppercase tracking-[0.16em] text-brand",
										children: "New IPTV Player"
									})
								}),
								/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("h1", {
									className: "font-disp text-[clamp(40px,7.5vw,96px)] uppercase leading-[0.88] tracking-[-0.04em]",
									children: [
										"The player",
										/* @__PURE__ */ (0, import_jsx_runtime.jsx)("br", {}),
										"built for",
										/* @__PURE__ */ (0, import_jsx_runtime.jsx)("br", {}),
										/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
											className: "font-serif-i normal-case text-flame",
											children: "live."
										})
									]
								}),
								/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
									className: "mt-6 max-w-lg space-y-4 font-disp text-[clamp(18px,2.4vw,28px)] uppercase leading-snug tracking-[-0.02em] text-[rgba(237,230,218,0.55)]",
									children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", { children: "Guide. Search. What’s on now." }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", { children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
										className: "text-[#EDE6DA]",
										children: "Movies & series in the same player — free, no ads."
									}) })]
								}),
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
									className: "mt-9",
									children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(PlatformDownloadButtons, { variant: "pills" })
								})
							] }), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
								className: "relative",
								id: "proof",
								children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("img", {
									src: "/brand/forja-iptv-live.jpg",
									alt: "Forja IPTV Player — live channels and categories",
									width: 1024,
									height: 637,
									className: "h-auto w-full rounded-lg border border-white/10 shadow-[0_40px_100px_-20px_rgba(0,0,0,0.9)]",
									decoding: "async"
								}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
									className: "font-mono-ui mt-4 text-[10px] uppercase tracking-[0.18em] text-[rgba(237,230,218,0.4)]",
									children: "IPTV Player · live · films · series"
								})]
							})]
						})]
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
						className: "overflow-hidden border-y border-[rgba(237,230,218,0.14)] bg-[#0f0e0d] py-5",
						children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
							className: "animate-marquee flex w-max gap-10 whitespace-nowrap px-4",
							children: [...MARQUEE, ...MARQUEE].map((w, i) => /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("span", {
								className: "inline-flex items-center gap-3",
								children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("b", {
									className: "font-serif-i text-[clamp(22px,3.5vw,40px)] text-[#EDE6DA]",
									children: w
								}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: i % 2 === 0 ? "text-brand" : "text-flame",
									children: "✦"
								})]
							}, `${w}-${i}`))
						})
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("section", {
						className: "px-[5vw] py-16 sm:py-28",
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Reveal, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("h2", {
							className: "max-w-[16ch] font-disp text-[clamp(32px,5vw,64px)] uppercase leading-[0.95] tracking-[-0.03em]",
							children: [
								"Why this player",
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("br", {}),
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: "text-flame",
									children: "wins the night."
								})
							]
						}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
							className: "mt-5 max-w-2xl font-disp text-[clamp(18px,2.4vw,28px)] uppercase leading-snug tracking-[-0.02em] text-[rgba(237,230,218,0.5)]",
							children: "Built for live — then ready for the film."
						})] }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
							className: "mt-14 grid gap-5 sm:grid-cols-2 lg:grid-cols-3",
							children: PLAYER_POWERS.map((p, i) => /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Reveal, {
								delayMs: i % 3 * 70,
								children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("article", {
									className: "h-full rounded-2xl border border-[rgba(237,230,218,0.14)] bg-[#121110] p-7 transition-colors hover:border-brand/35",
									children: [
										/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
											className: `font-mono-ui text-[10px] uppercase tracking-[0.2em] ${p.accent === "flame" ? "text-flame" : "text-brand"}`,
											children: "Player"
										}),
										/* @__PURE__ */ (0, import_jsx_runtime.jsx)("h3", {
											className: "font-disp mt-4 text-[clamp(24px,3vw,32px)] uppercase leading-tight",
											children: p.title
										}),
										/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
											className: "mt-3 leading-relaxed text-[rgba(237,230,218,0.48)]",
											children: p.copy
										})
									]
								})
							}, p.title))
						})]
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("section", {
						className: "border-t border-[rgba(237,230,218,0.14)] px-[5vw] py-24",
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Reveal, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("h2", {
							className: "font-disp text-[clamp(28px,4.5vw,52px)] uppercase tracking-[-0.03em]",
							children: [
								"Three shelves.",
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("br", {}),
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: "text-brand",
									children: "One player."
								})
							]
						}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
							className: "mt-4 max-w-xl font-disp text-[clamp(18px,2.2vw,26px)] uppercase leading-snug tracking-tight text-[rgba(237,230,218,0.5)]",
							children: "Live. Movies. Series — open any of them without switching apps."
						})] }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
							className: "mt-14 grid gap-5 md:grid-cols-3",
							children: MODES.map((mode, i) => /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Reveal, {
								delayMs: i * 110,
								children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("article", {
									"data-hover": "",
									className: "group relative h-full overflow-hidden rounded-2xl border border-[rgba(237,230,218,0.14)] bg-[#121110] transition duration-500 hover:-translate-y-1.5 hover:border-brand/40 hover:shadow-[0_28px_60px_-28px_rgba(0,0,0,0.85)]",
									children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
										className: "relative flex h-44 items-end justify-center gap-2 overflow-hidden bg-[#0B0A0A] px-5 pt-8 sm:h-52",
										children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
											"aria-hidden": true,
											className: "pointer-events-none absolute inset-0 opacity-70 transition duration-700 group-hover:opacity-100",
											style: { background: mode.accent === "flame" ? "radial-gradient(ellipse 70% 80% at 50% 100%, rgba(255,77,28,0.28), transparent 60%)" : "radial-gradient(ellipse 70% 80% at 50% 100%, rgba(28,231,131,0.22), transparent 60%)" }
										}), mode.posters.map((path, pi) => /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
											className: "relative w-[30%] max-w-[6.5rem]",
											style: {
												transform: `rotate(${(pi - 1) * 6}deg) translateY(${Math.abs(pi - 1) * 6}px)`,
												zIndex: pi === 1 ? 2 : 1
											},
											children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
												className: "transition duration-500 ease-out group-hover:-translate-y-2.5",
												style: { transitionDelay: `${pi * 45}ms` },
												children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("img", {
													src: tmdbPoster(path),
													alt: "",
													"aria-hidden": true,
													className: "aspect-[2/3] w-full rounded-md object-cover shadow-lg transition duration-500 group-hover:brightness-110",
													loading: "lazy",
													decoding: "async"
												})
											})
										}, path))]
									}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
										className: "border-t border-[rgba(237,230,218,0.1)] p-6",
										children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("h3", {
											className: "font-disp text-[clamp(28px,3vw,40px)] uppercase leading-none",
											children: mode.k
										}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
											className: "mt-3 text-sm leading-relaxed text-[rgba(237,230,218,0.45)]",
											children: mode.v
										})]
									})]
								})
							}, mode.k))
						})]
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)("section", {
						className: "border-t border-[rgba(237,230,218,0.14)] px-[5vw] py-[10vh]",
						children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
							className: "mx-auto grid max-w-[1400px] items-center gap-10 lg:grid-cols-2 lg:gap-14",
							children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Reveal, { children: [
								/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("h2", {
									className: "font-disp text-[clamp(32px,5vw,56px)] uppercase leading-[0.95]",
									children: [
										"Desk or couch.",
										/* @__PURE__ */ (0, import_jsx_runtime.jsx)("br", {}),
										/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
											className: "text-flame",
											children: "Same player."
										})
									]
								}),
								/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
									className: "mt-5 space-y-3 font-disp text-[clamp(18px,2.2vw,26px)] uppercase leading-snug tracking-tight text-[rgba(237,230,218,0.55)]",
									children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", { children: "Windows. Mac. Linux." }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", { children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
										className: "text-[#EDE6DA]",
										children: "Android TV for the living room."
									}) })]
								}),
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)(PlatformDownloadButtons, {
									variant: "row",
									className: "mt-8 max-w-md"
								})
							] }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Reveal, {
								delayMs: 60,
								children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("img", {
									src: "/brand/forja-iptv-live.jpg",
									alt: "Forja IPTV Player on screen",
									width: 1024,
									height: 637,
									className: "h-auto w-full rounded-lg border border-white/10 shadow-[0_32px_80px_-24px_rgba(0,0,0,0.85)]",
									decoding: "async"
								})
							})]
						})
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)("section", {
						className: "px-[5vw] py-28 text-center",
						children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Reveal, { children: [
							/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("h2", {
								className: "font-disp text-[clamp(40px,8vw,96px)] uppercase leading-[0.9] tracking-[-0.04em]",
								children: [
									"Press play",
									/* @__PURE__ */ (0, import_jsx_runtime.jsx)("br", {}),
									/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
										className: "text-flame",
										children: "on live."
									})
								]
							}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", {
								className: "mx-auto mt-6 max-w-lg font-disp text-[clamp(18px,2.4vw,28px)] uppercase leading-snug tracking-tight text-[rgba(237,230,218,0.5)]",
								children: [
									"Download Forja.",
									/* @__PURE__ */ (0, import_jsx_runtime.jsx)("br", {}),
									/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
										className: "text-[#EDE6DA]",
										children: "The IPTV Player is waiting."
									})
								]
							}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
								className: "mt-10 flex flex-col items-center gap-6",
								children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(PlatformDownloadButtons, {
									variant: "pills",
									className: "justify-center"
								}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
									to: "/",
									className: "font-mono-ui inline-flex items-center px-4 py-2 text-[11px] uppercase tracking-[0.16em] text-[rgba(237,230,218,0.4)] transition-colors hover:text-[#EDE6DA]",
									children: "Home"
								})]
							})
						] })
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)("footer", {
						className: "border-t border-[rgba(237,230,218,0.14)] px-[5vw] py-8",
						children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
							className: "font-mono-ui flex flex-wrap items-center justify-between gap-4 text-[11px] uppercase tracking-[0.12em] text-[rgba(237,230,218,0.35)]",
							children: [
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)(BrandLogo, {
									to: "/",
									imgClassName: "h-5 w-auto"
								}),
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", { children: "IPTV Player · Free · No ads" }),
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
									to: "/download",
									className: "hover:text-brand",
									children: "Downloads"
								})
							]
						})
					})
				]
			})
		]
	});
}
var SplitComponent = IptvPage;
//#endregion
export { SplitComponent as component };
