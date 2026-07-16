import { i as require_jsx_runtime } from "../_libs/@radix-ui/react-label+[...].mjs";
import { f as Link } from "../_libs/@tanstack/react-router+[...].mjs";
import { n as SiteHeader } from "./site-header-CQxqjJmj.mjs";
import { r as SiteFooter } from "./legal-shell-CuLzYo6R.mjs";
import { t as Reveal } from "./reveal-C110PiPA.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/iptv-0u-Iak0K.js
var import_jsx_runtime = require_jsx_runtime();
/** One capability per card — independent hooks, not a feature dump. */
var PLAYER_POWERS = [
	{
		title: "Channel guide",
		copy: "Flip groups without leaving the picture. The guide lives inside the stream.",
		accent: "flame"
	},
	{
		title: "Find anything fast",
		copy: "Search by name or category while you watch. Close it — you’re back in.",
		accent: "brand"
	},
	{
		title: "What’s on now",
		copy: "See what’s playing and what’s next — with progress — when your list has a guide.",
		accent: "flame"
	},
	{
		title: "Live, films & series",
		copy: "Kickoff, then a film, then a season. Same screen. Different night.",
		accent: "brand"
	},
	{
		title: "Audio & subtitles",
		copy: "Pick the track you need. Load captions when the stream supports them.",
		accent: "flame"
	},
	{
		title: "Your list. Your rules.",
		copy: "Bring the channels you already have. Favorites stay on top.",
		accent: "brand"
	}
];
/** CC BY Blender Foundation open movies + generic sport stills — no TMDB commercial art. */
var MODES = [
	{
		k: "Live",
		v: "Sports, news, and channels that never sleep.",
		accent: "flame",
		posters: [
			"/brand/hubs/sport/football.jpg",
			"/brand/hubs/sport/basketball.jpg",
			"/brand/hubs/sport/tennis.jpg"
		]
	},
	{
		k: "Movies",
		v: "Film night from the same player as the match.",
		accent: "brand",
		posters: [
			"/brand/open-films/big-buck-bunny.jpg",
			"/brand/open-films/cosmos-laundromat.jpg",
			"/brand/open-films/sprite-fright.jpg"
		]
	},
	{
		k: "Series",
		v: "Seasons ready when the live night ends.",
		accent: "flame",
		posters: [
			"/brand/open-films/sintel.jpg",
			"/brand/open-films/tears-of-steel.jpg",
			"/brand/open-films/cosmos-laundromat.jpg"
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
function DownloadCta({ className, children = "Download Forja" }) {
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
		to: "/download",
		"data-hover": "",
		className: className ?? "btn-magnet inline-flex items-center justify-center rounded-full px-9 py-4 font-mono-ui text-sm font-bold uppercase tracking-[0.08em] shadow-[0_0_32px_rgba(28,231,131,0.35)] will-change-transform sm:px-10 sm:text-[15px]",
		children
	});
}
function IptvPage() {
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
		className: "film-grain relative bg-[#0B0A0A] text-[#EDE6DA]",
		children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(SiteHeader, {}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("main", {
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
								children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(DownloadCta, { className: "btn-magnet inline-flex w-full items-center justify-center rounded-full px-9 py-4 font-mono-ui text-sm font-bold uppercase tracking-[0.08em] shadow-[0_0_32px_rgba(28,231,131,0.35)] sm:w-auto sm:px-10 sm:text-[15px]" })
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
							delayMs: i % 3 * 90,
							variant: "scale",
							children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("article", {
								className: "hover-lift h-full rounded-2xl border border-[rgba(237,230,218,0.14)] bg-[#121110] p-7 transition-colors hover:border-brand/35",
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
					className: "border-t border-[rgba(237,230,218,0.14)] px-[5vw] py-16 sm:py-24",
					children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Reveal, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("h2", {
						className: "font-disp text-[clamp(32px,5vw,56px)] uppercase leading-[0.95] tracking-[-0.03em]",
						children: [
							"Controls that",
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("br", {}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
								className: "text-brand",
								children: "stay out of the way."
							})
						]
					}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", {
						className: "mt-5 max-w-2xl font-disp text-[clamp(18px,2.4vw,28px)] uppercase leading-snug tracking-[-0.02em] text-[rgba(237,230,218,0.5)]",
						children: [
							"Progress. Pause. Volume. Subtitles. Audio.",
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("br", {}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
								className: "text-[#EDE6DA]",
								children: "The desk sits at the bottom — until you need it."
							})
						]
					})] }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Reveal, {
						delayMs: 80,
						children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("figure", {
							className: "mx-auto mt-10 max-w-[1200px] sm:mt-14",
							children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
								className: "hover-zoom rounded-xl",
								children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("img", {
									src: "/brand/forja-iptv-player.png",
									alt: "Forja IPTV player — seek bar and bottom control desk",
									width: 1024,
									height: 636,
									className: "h-auto w-full rounded-xl border border-white/10 shadow-[0_40px_100px_-24px_rgba(0,0,0,0.95)]",
									loading: "lazy",
									decoding: "async"
								})
							}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("figcaption", {
								className: "font-mono-ui mt-4 text-center text-[10px] uppercase tracking-[0.18em] text-[rgba(237,230,218,0.4)]",
								children: "Live player · control desk"
							})]
						})
					})]
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("section", {
					className: "border-t border-[rgba(237,230,218,0.14)] px-[5vw] py-16 sm:py-24",
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
								className: "group hover-lift relative h-full overflow-hidden rounded-2xl border border-[rgba(237,230,218,0.14)] bg-[#121110] transition duration-500 hover:border-brand/40",
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
												src: path,
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
					className: "border-t border-[rgba(237,230,218,0.14)] px-[5vw] py-16 sm:py-24",
					children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
						className: "mx-auto max-w-[1400px]",
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Reveal, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("h2", {
							className: "font-disp text-[clamp(32px,5vw,56px)] uppercase leading-[0.95]",
							children: [
								"Your portals.",
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("br", {}),
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: "text-flame",
									children: "Your night."
								})
							]
						}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", {
							className: "mt-5 max-w-xl font-disp text-[clamp(18px,2.2vw,26px)] uppercase leading-snug tracking-tight text-[rgba(237,230,218,0.55)]",
							children: [
								"Add a list once. Browse Live, Movies, Series.",
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("br", {}),
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: "text-[#EDE6DA]",
									children: "Favorites on top. Categories that actually make sense."
								})
							]
						})] }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Reveal, {
							delayMs: 80,
							children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("figure", {
								className: "mx-auto mt-10 max-w-[720px] sm:mt-14",
								children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
									className: "hover-zoom rounded-xl",
									children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("img", {
										src: "/brand/forja-iptv-desk.png",
										alt: "Forja IPTV desk — Live, Movies, and Series catalog with portals",
										width: 1024,
										height: 638,
										className: "h-auto w-full rounded-xl border border-white/10 shadow-[0_40px_100px_-24px_rgba(0,0,0,0.95)]",
										loading: "lazy",
										decoding: "async"
									})
								}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("figcaption", {
									className: "font-mono-ui mt-4 text-center text-[10px] uppercase tracking-[0.18em] text-[rgba(237,230,218,0.4)]",
									children: "Desk · portals · live · movies · series"
								})]
							})
						})]
					})
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("section", {
					className: "border-t border-[rgba(237,230,218,0.14)] px-[5vw] py-20 text-center sm:py-28",
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
								"Free. No ads.",
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("br", {}),
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: "text-[#EDE6DA]",
									children: "The IPTV Player is waiting."
								})
							]
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
							className: "mt-10 flex flex-col items-center gap-5",
							children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(DownloadCta, {}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
								to: "/",
								className: "font-mono-ui inline-flex items-center px-4 py-2 text-[11px] uppercase tracking-[0.16em] text-[rgba(237,230,218,0.4)] transition-colors hover:text-[#EDE6DA]",
								children: "Home"
							})]
						})
					] })
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)(SiteFooter, {})
			]
		})]
	});
}
var SplitComponent = IptvPage;
//#endregion
export { SplitComponent as component };
