import { r as __toESM } from "../_runtime.mjs";
import { n as require_react } from "../_libs/@radix-ui/react-compose-refs+[...].mjs";
import { i as require_jsx_runtime } from "../_libs/@radix-ui/react-primitive+[...].mjs";
import { f as Link } from "../_libs/@tanstack/react-router+[...].mjs";
import { n as SiteHeader, r as cn } from "./site-header-CsI2hv08.mjs";
import { r as SiteFooter } from "./legal-shell-DlcQyaIX.mjs";
import { n as Reveal, t as CustomCursor } from "./reveal-DOvxdxVG.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/routes-cd2Ql6cK.js
var import_react = /* @__PURE__ */ __toESM(require_react());
var import_jsx_runtime = require_jsx_runtime();
var tmdb$1 = (path, size = "w342") => `https://image.tmdb.org/t/p/${size}${path}`;
/** Verified TMDB paths (API-checked) */
var CATALOG = [
	{
		id: "dune2",
		title: "Dune: Part Two",
		year: 2024,
		kind: "film",
		rating: 8.5,
		genres: [
			"Sci-Fi",
			"Adventure",
			"Drama"
		],
		overview: "Paul Atreides unites with Chani and the Fremen while seeking revenge against the conspirators who destroyed his family.",
		poster: "/1pdfLvkbY9ohJlCjQH2CZjjYVvJ.jpg",
		backdrop: "/eZ239CUp1d6OryZEBPnO2n87gMG.jpg"
	},
	{
		id: "shogun",
		title: "Shōgun",
		year: 2024,
		kind: "series",
		rating: 8.7,
		genres: ["Drama", "History"],
		overview: "An English navigator becomes shipwrecked in Japan and ends up serving a powerful feudal lord.",
		poster: "/7O4iVfOMQmdCSxhOg1WnzG1AgYT.jpg",
		backdrop: "/6Tb87q9Tog30F5AAHh1gyDT2Vve.jpg"
	},
	{
		id: "oppenheimer",
		title: "Oppenheimer",
		year: 2023,
		kind: "film",
		rating: 8.3,
		genres: ["Drama", "History"],
		overview: "The story of J. Robert Oppenheimer and the development of the atomic bomb during World War II.",
		poster: "/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg",
		backdrop: "/neeNHeXjMF5fXoCJRsOmkNGC7q.jpg"
	},
	{
		id: "fallout",
		title: "Fallout",
		year: 2024,
		kind: "series",
		rating: 8.4,
		genres: ["Sci-Fi", "Adventure"],
		overview: "In a future decades after a nuclear war, a young woman leaves her vault home for the irradiated wasteland.",
		poster: "/c15BtJxCXMrISLVmysdsnZUPQft.jpg",
		backdrop: "/coaPCIqQBPUZsOnJcWZxhaORcDT.jpg"
	},
	{
		id: "challengers",
		title: "Challengers",
		year: 2024,
		kind: "film",
		rating: 7.1,
		genres: ["Drama", "Romance"],
		overview: "Tashi, a former tennis prodigy turned coach, turns a tournament into a high-stakes match of exes.",
		poster: "/H6vke7zGiuLsz4v4RPeReb9rsv.jpg",
		backdrop: "/tq8COKsI99Bivjd4CZIYVGoKcIx.jpg"
	},
	{
		id: "the-bear",
		title: "The Bear",
		year: 2022,
		kind: "series",
		rating: 8.6,
		genres: ["Comedy", "Drama"],
		overview: "A young chef from the fine-dining world returns to Chicago to run his family’s sandwich shop.",
		poster: "/eKfVzzEazSIjJMrw9ADa2x8ksLz.jpg",
		backdrop: "/aJtG4txtmiRHwAAqENQHZvBs6kY.jpg"
	}
];
/** SettingsService.defaultVisibleNavIds — exact labels from nav_config.dart */
var NAV = [
	{
		id: "home",
		label: "Home",
		icon: "home"
	},
	{
		id: "search",
		label: "Search",
		icon: "search"
	},
	{
		id: "asian_drama",
		label: "Asian Drama",
		icon: "asian"
	},
	{
		id: "anime",
		label: "Anime",
		icon: "anime"
	},
	{
		id: "iptv",
		label: "IPTV",
		icon: "iptv"
	},
	{
		id: "live_matches",
		label: "Live Matches",
		icon: "sport"
	},
	{
		id: "mylist",
		label: "My List",
		icon: "list"
	}
];
function Icon({ name, className, ...rest }) {
	const props = {
		viewBox: "0 0 24 24",
		fill: "currentColor",
		className: cn("h-[15px] w-[15px]", className),
		"aria-hidden": true,
		...rest
	};
	switch (name) {
		case "home": return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("svg", {
			...props,
			children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("path", { d: "M12 5.69l5 4.5V18h-2v-6H9v6H7v-7.81l5-4.5M12 3 2 12h3v8h6v-6h2v6h6v-8h3L12 3z" })
		});
		case "search": return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("svg", {
			...props,
			children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("path", { d: "M15.5 14h-.79l-.28-.27A6.47 6.47 0 0 0 16 9.5 6.5 6.5 0 1 0 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z" })
		});
		case "asian": return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("svg", {
			...props,
			children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("path", { d: "M2.5 10.5c0 3.04 2.46 5.5 5.5 5.5.95 0 1.84-.24 2.62-.67L9.5 14.2c-.45.2-.95.32-1.5.32-2.21 0-4-1.79-4-4s1.79-4 4-4c.55 0 1.05.12 1.5.32l1.12-1.13A5.47 5.47 0 0 0 8 5c-3.04 0-5.5 2.46-5.5 5.5zm7.5.5c-.55 0-1 .45-1 1s.45 1 1 1 1-.45 1-1-.45-1-1-1zm10.5-.5c0-3.04-2.46-5.5-5.5-5.5-.95 0-1.84.24-2.62.67l1.12 1.13c.45-.2.95-.32 1.5-.32 2.21 0 4 1.79 4 4s-1.79 4-4 4c-.55 0-1.05-.12-1.5-.32l-1.12 1.13c.78.43 1.67.67 2.62.67 3.04 0 5.5-2.46 5.5-5.5zM14 11c-.55 0-1 .45-1 1s.45 1 1 1 1-.45 1-1-.45-1-1-1zM12 17.5c-1.93 0-3.6-1.07-4.47-2.64h8.94C15.6 16.43 13.93 17.5 12 17.5z" })
		});
		case "anime": return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("svg", {
			...props,
			children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("path", { d: "M11.88 3.47 12 3l.12.47C13.07 7.21 16.79 10.93 20.53 12L21 12.12l-.47.12c-3.74 1.07-7.46 4.79-8.53 8.53L12 21l-.12-.47C10.93 16.79 7.21 13.07 3.47 12L3 11.88l.47-.12C7.21 10.93 10.93 7.21 11.88 3.47zM12 6.24C10.64 8.66 8.66 10.64 6.24 12 8.66 13.36 10.64 15.34 12 17.76c1.36-2.42 3.34-4.4 5.76-5.76C15.34 10.64 13.36 8.66 12 6.24z" })
		});
		case "iptv": return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("svg", {
			...props,
			children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("path", { d: "M21 6h-7.59l3.29-3.29L16 2l-4 4-4-4-.71.71L10.59 6H3c-1.1 0-2 .89-2 2v12c0 1.1.9 2 2 2h18c1.1 0 2-.9 2-2V8c0-1.11-.9-2-2-2zm0 14H3V8h18v12zM9 10v8l7-4z" })
		});
		case "sport": return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("svg", {
			...props,
			children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("path", { d: "M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 3.3 3.12 2.26-.48 1.47-1.96-.4L12 11.1l-1.68-2.47-1.96.4-.48-1.47L11 5.3V4.01c.33-.01.66-.01 1 0V5.3zM7.24 7.76l.48 1.47-1.18 1.73H4.1C4.74 9.3 5.84 8.26 7.24 7.76zM4.01 13c.01-.33.01-.66 0-1h2.45l.68 2.1-1.68 1.68C4.77 14.98 4.27 14.04 4.01 13zm3.23 4.94 1.96-.4L11 14.1v2.72l-2.26 1.64c-.58-.36-1.1-.8-1.5-1.32v-.2zm5.52 1.52L11 17.18v-3.08l1.68 2.47 1.96.4c-.4.52-.92.96-1.5 1.32l.12.07zm3.68-2.76-1.68-1.68.68-2.1h2.45c-.01.33-.01.66 0 1-.26 1.04-.76 1.98-1.45 2.78zm1.63-5.04h-2.44L16.28 9.23l.48-1.47c1.4.5 2.5 1.54 3.14 2.9z" })
		});
		case "list": return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("svg", {
			...props,
			children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("path", { d: "M17 3H7c-1.1 0-2 .9-2 2v16l7-3 7 3V5c0-1.1-.9-2-2-2zm0 15-5-2.18L7 18V5h10v13z" })
		});
		case "settings": return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("svg", {
			...props,
			children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("path", { d: "M19.14 12.94c.04-.31.06-.63.06-.94 0-.31-.02-.63-.06-.94l2.03-1.58a.49.49 0 0 0 .12-.61l-1.92-3.32a.49.49 0 0 0-.59-.22l-2.39.96c-.5-.38-1.03-.7-1.62-.94l-.36-2.54a.484.484 0 0 0-.48-.41h-3.84c-.24 0-.43.17-.47.41l-.36 2.54c-.59.24-1.13.57-1.62.94l-2.39-.96c-.22-.08-.47 0-.59.22L2.74 8.87c-.12.21-.08.47.12.61l2.03 1.58c-.04.31-.06.63-.06.94s.02.63.06.94l-2.03 1.58a.49.49 0 0 0-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.47-.41l.36-2.54c.59-.24 1.13-.56 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32c.12-.22.07-.47-.12-.61l-2.01-1.58zM12 15.6A3.6 3.6 0 1 1 12 8.4a3.6 3.6 0 0 1 0 7.2z" })
		});
		case "play": return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("svg", {
			...props,
			children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("path", { d: "M8 5v14l11-7z" })
		});
		case "info": return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("svg", {
			...props,
			children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("path", { d: "M11 7h2v2h-2V7zm0 4h2v6h-2v-6zm1-9C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8z" })
		});
	}
}
function ShellScreen() {
	const [filter, setFilter] = (0, import_react.useState)("all");
	const [heroId, setHeroId] = (0, import_react.useState)(CATALOG[0].id);
	const [dragX, setDragX] = (0, import_react.useState)(0);
	const [dragging, setDragging] = (0, import_react.useState)(false);
	const startX = (0, import_react.useRef)(0);
	const startY = (0, import_react.useRef)(0);
	const dragRef = (0, import_react.useRef)(0);
	const axis = (0, import_react.useRef)(null);
	const paused = (0, import_react.useRef)(false);
	const pool = (0, import_react.useMemo)(() => {
		if (filter === "films") return CATALOG.filter((t) => t.kind === "film");
		if (filter === "tv") return CATALOG.filter((t) => t.kind === "series");
		return CATALOG;
	}, [filter]);
	const hero = pool.find((t) => t.id === heroId) ?? pool[0] ?? CATALOG[0];
	const featured = pool.slice(0, 5);
	const heroIndex = Math.max(0, pool.findIndex((t) => t.id === hero.id));
	function setFilterAndHero(next) {
		setFilter(next);
		const nextPool = next === "films" ? CATALOG.filter((t) => t.kind === "film") : next === "tv" ? CATALOG.filter((t) => t.kind === "series") : CATALOG;
		if (!nextPool.some((t) => t.id === heroId)) setHeroId(nextPool[0]?.id ?? CATALOG[0].id);
	}
	function goHero(delta) {
		if (pool.length === 0) return;
		const next = (heroIndex + delta + pool.length) % pool.length;
		setHeroId(pool[next].id);
	}
	(0, import_react.useEffect)(() => {
		if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
		const id = window.setInterval(() => {
			if (paused.current || dragging) return;
			setHeroId((current) => {
				const i = pool.findIndex((t) => t.id === current);
				const next = ((i >= 0 ? i : 0) + 1) % pool.length;
				return pool[next]?.id ?? current;
			});
		}, 5e3);
		return () => window.clearInterval(id);
	}, [dragging, pool]);
	function onPointerDown(e) {
		if (e.button !== 0) return;
		if (e.target.closest("button, a")) return;
		paused.current = true;
		setDragging(true);
		startX.current = e.clientX;
		startY.current = e.clientY;
		axis.current = null;
		dragRef.current = 0;
		setDragX(0);
		e.currentTarget.setPointerCapture(e.pointerId);
	}
	function onPointerMove(e) {
		if (!dragging) return;
		const dx = e.clientX - startX.current;
		const dy = e.clientY - startY.current;
		if (axis.current === null && (Math.abs(dx) > 6 || Math.abs(dy) > 6)) axis.current = Math.abs(dx) > Math.abs(dy) ? "x" : "y";
		if (axis.current === "x") {
			dragRef.current = dx;
			setDragX(dx);
		}
	}
	function onPointerUp(e) {
		if (!dragging) return;
		try {
			e.currentTarget.releasePointerCapture(e.pointerId);
		} catch {}
		setDragging(false);
		const dx = dragRef.current;
		if (axis.current === "x") {
			if (dx <= -40) goHero(1);
			else if (dx >= 40) goHero(-1);
		}
		dragRef.current = 0;
		setDragX(0);
		axis.current = null;
		window.setTimeout(() => {
			paused.current = false;
		}, 5e3);
	}
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
		className: "flex h-full min-h-0 bg-[#0B0A0A] text-[#EDE6DA]",
		children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("aside", {
			className: "flex w-9 shrink-0 flex-col items-center border-r border-white/[0.06] py-2 sm:w-10",
			children: [
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("img", {
					src: "/brand/logo-dark.svg",
					alt: "",
					className: "mb-2 h-3.5 w-auto max-w-[36px] object-contain sm:h-4 sm:max-w-[42px]"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("nav", {
					className: "flex flex-1 flex-col items-center gap-0.5",
					"aria-label": "Forja navigation",
					children: NAV.map((item) => {
						const selected = item.id === "home";
						return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
							title: item.label,
							"aria-current": selected ? "page" : void 0,
							className: cn("flex h-7 w-7 items-center justify-center rounded-md transition-colors sm:h-8 sm:w-8", selected ? "bg-white/[0.08] text-[#1CE783]" : "cursor-default text-white/35 hover:bg-white/[0.06] hover:text-white/80"),
							children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Icon, { name: item.icon })
						}, item.id);
					})
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
					title: "Settings",
					className: "mb-0.5 flex h-7 w-7 cursor-default items-center justify-center rounded-md text-white/35 transition-colors hover:bg-white/[0.06] hover:text-white/80 sm:h-8 sm:w-8",
					children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Icon, { name: "settings" })
				})
			]
		}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
			className: "relative min-w-0 flex-1 overflow-hidden",
			children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
				className: "relative h-full touch-pan-y select-none",
				onPointerDown,
				onPointerMove,
				onPointerUp,
				onPointerCancel: onPointerUp,
				style: {
					transform: dragging ? `translateX(${dragX * .08}px)` : void 0,
					transition: dragging ? "none" : "transform 0.3s ease-out"
				},
				children: [
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)("img", {
						src: tmdb$1(hero.backdrop, "w780"),
						alt: "",
						draggable: false,
						className: "absolute inset-0 h-full w-full object-cover object-[center_20%]"
					}, hero.id),
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
						"aria-hidden": true,
						className: "absolute inset-0",
						style: { background: "linear-gradient(90deg, #0B0A0A 0%, rgba(11,10,10,0.9) 32%, rgba(11,10,10,0.4) 58%, transparent 100%), linear-gradient(0deg, #0B0A0A 0%, transparent 38%), linear-gradient(180deg, rgba(11,10,10,0.55) 0%, transparent 28%)" }
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
						className: "absolute inset-x-0 top-0 z-20 flex items-center gap-3 px-2.5 py-2 sm:gap-5 sm:px-3.5 sm:py-2.5",
						children: [
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("button", {
								type: "button",
								onClick: () => setFilterAndHero(filter === "films" ? "all" : "films"),
								className: cn("text-[9px] font-semibold tracking-wide sm:text-[10px]", filter === "films" ? "text-white" : "text-white/55 hover:text-white/85"),
								children: "Films"
							}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("button", {
								type: "button",
								onClick: () => setFilterAndHero(filter === "tv" ? "all" : "tv"),
								className: cn("text-[9px] font-semibold tracking-wide sm:text-[10px]", filter === "tv" ? "text-white" : "text-white/55 hover:text-white/85"),
								children: "TV Shows"
							}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
								className: "text-[9px] font-semibold tracking-wide text-white/55 sm:text-[10px]",
								children: "Categories"
							}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
								className: "ml-auto text-white/45",
								children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Icon, {
									name: "search",
									className: "h-3.5 w-3.5"
								})
							})
						]
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
						className: "relative z-[1] flex h-full max-w-[58%] flex-col justify-end px-2.5 pb-[4.75rem] pt-10 sm:max-w-[55%] sm:px-3.5 sm:pb-[5.5rem]",
						children: [
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("h3", {
								className: "font-disp text-[clamp(14px,2.4vw,22px)] uppercase leading-[0.95] tracking-tight",
								children: hero.title
							}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", {
								className: "mt-1 flex flex-wrap items-center gap-x-1.5 gap-y-0.5 text-[8px] text-white/65 sm:text-[9px]",
								children: [
									/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("span", {
										className: "text-amber-300",
										children: ["★ ", hero.rating.toFixed(1)]
									}),
									/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", { children: "·" }),
									/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", { children: hero.year }),
									/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", { children: "·" }),
									/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
										className: "rounded border border-white/25 px-1 py-px text-[7px] uppercase tracking-wider sm:text-[8px]",
										children: hero.kind === "film" ? "Film" : "Series"
									}),
									/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
										className: "hidden text-white/40 sm:inline",
										children: hero.genres.slice(0, 2).join(" · ")
									})
								]
							}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
								className: "mt-1.5 line-clamp-2 text-[8px] leading-relaxed text-white/50 sm:text-[9px]",
								children: hero.overview
							}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
								className: "mt-2 flex items-center gap-1.5",
								children: [
									/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("span", {
										className: "inline-flex items-center gap-1 rounded-full bg-[#1CE783] px-2.5 py-1 text-[8px] font-bold text-[#0B0A0A] sm:text-[9px]",
										children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Icon, {
											name: "play",
											className: "h-2.5 w-2.5"
										}), "Play"]
									}),
									/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
										className: "flex h-5 w-5 items-center justify-center rounded-full border border-white/20 bg-black/35 text-white/75 sm:h-6 sm:w-6",
										children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Icon, {
											name: "info",
											className: "h-3 w-3"
										})
									}),
									/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
										className: "flex h-5 w-5 items-center justify-center rounded-full border border-white/20 bg-black/35 text-white/75 sm:h-6 sm:w-6",
										children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Icon, {
											name: "list",
											className: "h-3 w-3"
										})
									})
								]
							}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
								className: "mt-2.5 flex gap-1",
								children: pool.slice(0, 6).map((item) => /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", { className: cn("h-0.5 rounded-full transition-all", item.id === hero.id ? "w-4 bg-[#1CE783]" : "w-1 bg-white/25") }, item.id))
							})
						]
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
						className: "absolute inset-x-0 bottom-0 z-[1] px-2 pb-2 sm:px-3 sm:pb-2.5",
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
							className: "mb-1 text-[8px] font-semibold text-[#EDE6DA] sm:text-[9px]",
							children: "Featured This Month"
						}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
							className: "flex gap-1.5 overflow-hidden",
							children: featured.map((item) => /* @__PURE__ */ (0, import_jsx_runtime.jsx)("button", {
								type: "button",
								onClick: () => setHeroId(item.id),
								className: cn("relative w-[2.65rem] shrink-0 overflow-hidden rounded sm:w-12", item.id === hero.id && "ring-1 ring-[#1CE783]"),
								children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("img", {
									src: tmdb$1(item.poster, "w185"),
									alt: item.title,
									className: "aspect-[2/3] w-full object-cover",
									loading: "lazy",
									draggable: false
								})
							}, item.id))
						})]
					})
				]
			})
		})]
	});
}
function TvBezel({ children }) {
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
		className: "mx-auto w-full max-w-[560px] sm:max-w-[640px] lg:max-w-[720px] xl:max-w-[800px]",
		children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
			className: "rounded-[1.25rem] border border-white/12 bg-[#161412] p-[0.65rem] shadow-[0_50px_110px_-30px_rgba(0,0,0,0.95)] sm:rounded-[1.4rem] sm:p-3",
			children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
				className: "overflow-hidden rounded-[0.8rem] border border-white/[0.08] bg-black sm:rounded-[1rem]",
				children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
					className: "aspect-[16/10] w-full",
					children
				})
			})
		}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
			className: "mx-auto mt-0 flex w-[38%] flex-col items-center",
			children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", { className: "h-3.5 w-[16%] bg-gradient-to-b from-[#2a2724] to-[#1a1816]" }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", { className: "h-2 w-full rounded-full bg-[#2a2724]" })]
		})]
	});
}
/** TV mock of Forja Home for the landing hero. */
function HeroTvMock({ className }) {
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
		className: cn(className),
		children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(TvBezel, { children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(ShellScreen, {}) })
	});
}
/**
* Marketing hero — headline, one line, Download CTA, product mock.
*/
function LandingHero() {
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("header", {
		className: "relative overflow-hidden pt-16 sm:pt-24",
		children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
			"aria-hidden": true,
			className: "pointer-events-none absolute inset-0",
			style: { background: "radial-gradient(ellipse 55% 50% at 85% 40%, rgba(28,231,131,0.12), transparent 55%), radial-gradient(ellipse 45% 45% at 10% 70%, rgba(255,77,28,0.1), transparent 50%)" }
		}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
			className: "relative z-[2] mx-auto grid w-full max-w-[1500px] items-center gap-8 px-[5vw] pb-10 pt-5 sm:pb-12 sm:pt-6 lg:grid-cols-[0.9fr_1.2fr] lg:gap-10 lg:pb-16 lg:pt-8",
			children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
				className: "max-w-xl",
				children: [
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("h1", {
						className: "font-disp text-[clamp(34px,9vw,72px)] uppercase leading-[0.9] tracking-[-0.04em]",
						children: [
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
								className: "inline sm:whitespace-nowrap",
								children: "Tonight starts"
							}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("br", {}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
								className: "font-serif-i normal-case text-flame",
								children: "here."
							})
						]
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", {
						className: "mt-4 max-w-lg font-disp text-[clamp(16px,4.2vw,28px)] uppercase leading-snug tracking-[-0.02em] text-[rgba(237,230,218,0.55)] sm:mt-5",
						children: [
							"Blockbusters. Binges.",
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("br", {}),
							"Matches. Late-night TV.",
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("br", {}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
								className: "text-[#EDE6DA]",
								children: "Your escape — free."
							})
						]
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
						to: "/download",
						"data-hover": "",
						className: "btn-magnet mt-7 inline-flex w-full items-center justify-center rounded-full px-8 py-4 font-mono-ui text-sm font-bold uppercase tracking-[0.08em] shadow-[0_0_32px_rgba(28,231,131,0.35)] will-change-transform sm:mt-8 sm:w-auto sm:px-10 sm:text-[15px]",
						children: "Download Forja"
					})
				]
			}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(HeroTvMock, { className: "w-full max-w-[760px] justify-self-center lg:justify-self-end" })]
		})]
	});
}
var tmdbBackdrop = (path) => `https://image.tmdb.org/t/p/w780${path}`;
function mediaSrc(path) {
	if (path.startsWith("/brand/")) return path;
	return tmdbBackdrop(path);
}
/** Six moods — cinematic tiles (TMDB backdrops verified via API). */
var MOODS = [
	{
		id: "movies",
		label: "Movies",
		line: "Blockbusters & more",
		accent: "flame",
		backdrop: "/eZ239CUp1d6OryZEBPnO2n87gMG.jpg"
	},
	{
		id: "series",
		label: "Series",
		line: "Binge-worthy",
		accent: "brand",
		backdrop: "/6Tb87q9Tog30F5AAHh1gyDT2Vve.jpg"
	},
	{
		id: "anime",
		label: "Anime",
		line: "Worlds to explore",
		accent: "flame",
		backdrop: "/3GQKYh6Trm8pxd2AypovoYQf4Ay.jpg"
	},
	{
		id: "asian",
		label: "Asian Drama",
		line: "Stories that hit",
		accent: "brand",
		backdrop: "/2meX1nMdScFOoV4370rqHWKmXhY.jpg"
	},
	{
		id: "iptv",
		label: "Live TV",
		line: "On now",
		accent: "flame",
		backdrop: "/brand/forja-iptv-live.jpg",
		logos: [
			{
				src: "/brand/hubs/tv/cnn.svg",
				alt: "CNN"
			},
			{
				src: "/brand/hubs/tv/hbo.svg",
				alt: "HBO"
			},
			{
				src: "/brand/hubs/tv/fox.svg",
				alt: "FOX"
			},
			{
				src: "/brand/hubs/tv/sky.svg",
				alt: "Sky"
			},
			{
				src: "/brand/hubs/tv/nbc.svg",
				alt: "NBC"
			},
			{
				src: "/brand/hubs/tv/cbs.svg",
				alt: "CBS"
			}
		]
	},
	{
		id: "sport",
		label: "Live Sport",
		line: "Never miss a game",
		accent: "brand",
		backdrop: "/brand/hubs/sport/football.jpg"
	}
];
function MoodTile({ mood, index }) {
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("article", {
		className: cn("group relative isolate aspect-[5/4] overflow-hidden rounded-2xl border border-white/[0.1] bg-[#121110] sm:aspect-[4/3] lg:aspect-[5/4]", "shadow-[0_28px_70px_-28px_rgba(0,0,0,0.9)] transition duration-500", "hover:border-white/20 hover:shadow-[0_36px_90px_-24px_rgba(0,0,0,0.95)]"),
		children: [
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("img", {
				src: mediaSrc(mood.backdrop),
				alt: "",
				"aria-hidden": true,
				className: "absolute inset-0 h-full w-full object-cover transition duration-700 group-hover:scale-105",
				loading: index < 2 ? "eager" : "lazy",
				decoding: "async"
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
				"aria-hidden": true,
				className: "absolute inset-0",
				style: { background: "linear-gradient(180deg, rgba(11,10,10,0.15) 0%, rgba(11,10,10,0.35) 40%, rgba(11,10,10,0.92) 100%), linear-gradient(90deg, rgba(11,10,10,0.55) 0%, transparent 55%)" }
			}),
			mood.logos ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
				className: "absolute inset-x-0 top-0 z-[1] flex flex-wrap justify-end gap-2 p-4 sm:p-5",
				children: mood.logos.map((logo) => /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
					className: "flex h-8 w-8 items-center justify-center rounded-full bg-black/45 ring-1 ring-white/15 backdrop-blur-sm sm:h-9 sm:w-9",
					children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("img", {
						src: logo.src,
						alt: logo.alt,
						className: "h-[55%] w-[55%] object-contain brightness-0 invert",
						loading: "lazy"
					})
				}, logo.alt))
			}) : null,
			/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
				className: "absolute inset-x-0 bottom-0 z-[1] p-5 sm:p-6",
				children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
					className: cn("font-mono-ui text-[10px] uppercase tracking-[0.2em]", mood.accent === "flame" ? "text-flame" : "text-brand"),
					children: mood.line
				}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("h3", {
					className: "font-disp mt-2 text-[clamp(28px,3.5vw,42px)] uppercase leading-[0.92] tracking-tight text-[#EDE6DA]",
					children: mood.label
				})]
			})
		]
	});
}
function LibraryHubs() {
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("section", {
		id: "library",
		className: "px-[5vw] py-[12vh]",
		children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Reveal, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("h2", {
			className: "max-w-[14ch] font-disp text-[clamp(36px,6vw,72px)] uppercase leading-[0.92] tracking-[-0.03em]",
			children: [
				"Pick a world.",
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("br", {}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
					className: "text-flame",
					children: "Disappear."
				})
			]
		}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", {
			className: "mt-6 font-disp text-[clamp(20px,2.8vw,32px)] uppercase leading-snug tracking-[-0.02em] text-[rgba(237,230,218,0.55)]",
			children: [
				"Six doors.",
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("br", {}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
					className: "text-[#EDE6DA]",
					children: "Which one tonight?"
				})
			]
		})] }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
			className: "mx-auto mt-12 grid max-w-[1400px] grid-cols-1 gap-4 sm:grid-cols-2 sm:gap-5 lg:grid-cols-3 lg:gap-6",
			children: MOODS.map((mood, i) => /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Reveal, {
				delayMs: i % 3 * 60,
				children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(MoodTile, {
					mood,
					index: i
				})
			}, mood.id))
		})]
	});
}
var tmdb = (path, size = "w342") => `https://image.tmdb.org/t/p/${size}${path}`;
/** Verified TMDB paths — same set as the hero TV mock */
var REEL = [
	{
		id: "dune2",
		title: "Dune: Part Two",
		tag: "Film",
		poster: "/1pdfLvkbY9ohJlCjQH2CZjjYVvJ.jpg",
		backdrop: "/eZ239CUp1d6OryZEBPnO2n87gMG.jpg"
	},
	{
		id: "shogun",
		title: "Shōgun",
		tag: "Series",
		poster: "/7O4iVfOMQmdCSxhOg1WnzG1AgYT.jpg",
		backdrop: "/6Tb87q9Tog30F5AAHh1gyDT2Vve.jpg"
	},
	{
		id: "fallout",
		title: "Fallout",
		tag: "Series",
		poster: "/c15BtJxCXMrISLVmysdsnZUPQft.jpg",
		backdrop: "/coaPCIqQBPUZsOnJcWZxhaORcDT.jpg"
	},
	{
		id: "challengers",
		title: "Challengers",
		tag: "Film",
		poster: "/H6vke7zGiuLsz4v4RPeReb9rsv.jpg",
		backdrop: "/tq8COKsI99Bivjd4CZIYVGoKcIx.jpg"
	}
];
var CYCLE_MS = 4200;
/** Animated “now playing” stack — replaces dry CTA stats. */
function NowPlayingPanel({ className }) {
	const [index, setIndex] = (0, import_react.useState)(0);
	const [reduced, setReduced] = (0, import_react.useState)(false);
	(0, import_react.useEffect)(() => {
		const mq = window.matchMedia("(prefers-reduced-motion: reduce)");
		setReduced(mq.matches);
		const onChange = () => setReduced(mq.matches);
		mq.addEventListener("change", onChange);
		return () => mq.removeEventListener("change", onChange);
	}, []);
	(0, import_react.useEffect)(() => {
		if (reduced) return;
		const id = window.setInterval(() => {
			setIndex((i) => (i + 1) % REEL.length);
		}, CYCLE_MS);
		return () => window.clearInterval(id);
	}, [reduced]);
	const current = REEL[index];
	const prev = REEL[(index - 1 + REEL.length) % REEL.length];
	const next = REEL[(index + 1) % REEL.length];
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
		className: cn("w-full", className),
		children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
			className: "relative overflow-hidden rounded-2xl border border-[rgba(237,230,218,0.14)] bg-[#121110]",
			children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
				className: "pointer-events-none absolute inset-0",
				children: [REEL.map((item, i) => /* @__PURE__ */ (0, import_jsx_runtime.jsx)("img", {
					src: tmdb(item.backdrop, "w780"),
					alt: "",
					"aria-hidden": true,
					className: cn("absolute inset-0 h-full w-full object-cover transition-opacity duration-700", i === index ? "opacity-40" : "opacity-0")
				}, item.id)), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", { className: "absolute inset-0 bg-gradient-to-t from-[#0B0A0A] via-[#0B0A0A]/85 to-[#0B0A0A]/40" })]
			}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
				className: "relative flex flex-col gap-5 p-5 sm:flex-row sm:gap-7 sm:p-8 lg:gap-8 lg:p-10",
				children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					className: "relative mx-auto h-[220px] w-[128px] shrink-0 sm:mx-0 sm:h-[320px] sm:w-[188px] lg:h-[360px] lg:w-[210px]",
					children: [
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)("img", {
							src: tmdb(prev.poster),
							alt: "",
							"aria-hidden": true,
							className: "absolute top-4 left-0 hidden h-[85%] w-[85%] -rotate-6 rounded-xl object-cover opacity-35 shadow-lg sm:block"
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)("img", {
							src: tmdb(next.poster),
							alt: "",
							"aria-hidden": true,
							className: "absolute top-4 right-0 hidden h-[85%] w-[85%] rotate-6 rounded-xl object-cover opacity-35 shadow-lg sm:block"
						}),
						REEL.map((item, i) => /* @__PURE__ */ (0, import_jsx_runtime.jsx)("img", {
							src: tmdb(item.poster),
							alt: item.title,
							className: cn("absolute inset-0 h-full w-full rounded-xl object-cover shadow-2xl ring-1 ring-white/10 transition-all duration-500", i === index ? "z-10 scale-100 opacity-100" : "z-0 scale-95 opacity-0")
						}, item.id)),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
							className: "pointer-events-none absolute inset-0 z-20 flex items-center justify-center",
							"aria-hidden": true,
							children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
								className: "animate-play-pulse flex h-12 w-12 items-center justify-center rounded-full bg-brand text-[#0B0A0A] shadow-[0_0_32px_rgba(28,231,131,0.5)] sm:h-16 sm:w-16",
								children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("svg", {
									viewBox: "0 0 24 24",
									className: "h-5 w-5 fill-current sm:h-7 sm:w-7",
									children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("path", { d: "M8 5v14l11-7z" })
								})
							})
						})
					]
				}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					className: "flex min-w-0 flex-1 flex-col justify-between py-1 text-center sm:py-2 sm:text-left",
					children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", { children: [
						/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", {
							className: "font-mono-ui flex items-center justify-center gap-2 text-[11px] uppercase tracking-[0.22em] text-brand sm:justify-start sm:text-xs",
							children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", { className: "animate-live-dot inline-block h-2 w-2 rounded-full bg-brand" }), "Now playing"]
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
							className: "font-disp animate-now-title mt-3 text-[clamp(26px,7vw,48px)] uppercase leading-[0.95] tracking-tight text-[#EDE6DA] sm:mt-4",
							children: current.title
						}, current.id),
						/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", {
							className: "mt-2 font-disp text-base uppercase tracking-wide text-[rgba(237,230,218,0.45)] sm:mt-3 sm:text-lg",
							children: [
								current.tag,
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: "mx-2 text-[rgba(237,230,218,0.25)]",
									children: "·"
								}),
								"Watch now"
							]
						})
					] }), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
						className: "mt-6 sm:mt-10",
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
							className: "h-1.5 overflow-hidden rounded-full bg-[rgba(237,230,218,0.12)]",
							children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", { className: cn("h-full rounded-full bg-flame", reduced ? "w-[66%]" : "animate-stream-progress") }, current.id)
						}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
							className: "font-mono-ui mt-3 flex justify-between text-[11px] uppercase tracking-[0.16em] text-[rgba(237,230,218,0.38)] sm:text-xs",
							children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", { children: "Free" }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", { children: "No ads" })]
						})]
					})]
				})]
			})]
		}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
			to: "/download",
			"data-hover": "",
			className: "font-mono-ui mt-5 inline-block text-[11px] uppercase tracking-[0.16em] text-brand transition-colors hover:text-flame",
			children: "Download Forja"
		})]
	});
}
/** Four different nights — not four ways to say “watch everywhere”. */
var NIGHTS = [
	{
		k: "The premiere",
		v: "Lights down. Big screen energy. A film that owns the room."
	},
	{
		k: "The binge",
		v: "One more episode turns into three. You don’t fight it."
	},
	{
		k: "The roar",
		v: "Kickoff. Overtime. The whole house on the edge of the seat."
	},
	{
		k: "The after-hours",
		v: "Channels still humming when the city goes quiet."
	}
];
var MARQUEE = [
	"Drama",
	"Action",
	"Anime",
	"Romance",
	"Thriller",
	"Comedy",
	"Football",
	"Basketball",
	"News",
	"Documentaries"
];
function LandingPage() {
	const magnetRef = (0, import_react.useRef)(null);
	function onMagnetMove(e) {
		const mag = magnetRef.current;
		if (!mag) return;
		const fine = window.matchMedia("(hover: hover) and (pointer: fine)").matches;
		const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
		if (!fine || reduced) return;
		const r = mag.getBoundingClientRect();
		const x = e.clientX - (r.left + r.width / 2);
		const y = e.clientY - (r.top + r.height / 2);
		mag.style.transform = `translate(${x * .3}px, ${y * .4}px)`;
	}
	function onMagnetLeave() {
		if (magnetRef.current) magnetRef.current.style.transform = "";
	}
	const marqueeItems = [...MARQUEE, ...MARQUEE];
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
		className: "film-grain relative bg-[#0B0A0A] text-[#EDE6DA]",
		children: [
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)(CustomCursor, {}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)(SiteHeader, {}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)(LandingHero, {}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("section", {
				id: "why",
				className: "border-y border-[rgba(237,230,218,0.14)] bg-[#0f0e0d]",
				children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
					className: "mx-auto max-w-[1400px] px-[5vw] pt-14 pb-4 lg:pt-16",
					children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Reveal, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("h2", {
						className: "max-w-[16ch] font-disp text-[clamp(36px,6vw,64px)] uppercase leading-[0.92] tracking-[-0.03em]",
						children: [
							"Four kinds of",
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("br", {}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
								className: "text-flame",
								children: "night."
							})
						]
					}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", {
						className: "mt-6 font-disp text-[clamp(20px,2.8vw,32px)] uppercase leading-snug tracking-[-0.02em] text-[rgba(237,230,218,0.55)]",
						children: [
							"Forja follows the mood —",
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("br", {}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
								className: "text-[#EDE6DA]",
								children: "not the other way around."
							})
						]
					})] })
				}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
					className: "mx-auto grid max-w-[1400px] lg:grid-cols-2 xl:grid-cols-4",
					children: NIGHTS.map((d, i) => /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Reveal, {
						delayMs: i * 70,
						children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
							className: `h-full border-[rgba(237,230,218,0.14)] px-[5vw] py-10 lg:border-r lg:px-8 lg:py-12 ${i === NIGHTS.length - 1 ? "lg:border-r-0" : ""} ${i >= 2 ? "xl:border-t-0" : ""}`,
							children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("h3", {
								className: "font-disp text-[clamp(22px,2.8vw,32px)] uppercase leading-tight tracking-tight",
								children: d.k
							}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
								className: "mt-3 font-disp text-lg uppercase leading-snug tracking-tight text-[rgba(237,230,218,0.5)] sm:text-xl",
								children: d.v
							})]
						})
					}, d.k))
				})]
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
				className: "overflow-hidden whitespace-nowrap border-b border-[rgba(237,230,218,0.14)] py-5",
				children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
					className: "animate-marquee inline-flex w-max",
					children: marqueeItems.map((w, i) => /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("span", {
						className: "inline-flex items-center",
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("b", {
							className: "font-serif-i px-[22px] text-[clamp(22px,3.8vw,44px)] text-[#EDE6DA]",
							children: w
						}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
							className: "font-disp self-center px-1.5 text-[clamp(18px,2.5vw,32px)] text-flame",
							children: "✦"
						})]
					}, `${w}-${i}`))
				})
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("section", {
				className: "border-t border-[rgba(237,230,218,0.14)] px-[5vw] py-[10vh]",
				children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					className: "mx-auto grid max-w-[1200px] items-center gap-10 lg:grid-cols-2 lg:gap-14",
					children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Reveal, { children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("img", {
						src: "/brand/forja-home-hero.jpg",
						alt: "Forja home — cinematic hero and featured shelves",
						width: 1024,
						height: 643,
						className: "h-auto w-full rounded-lg border border-white/10 shadow-[0_32px_80px_-24px_rgba(0,0,0,0.85)]",
						decoding: "async"
					}) }), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Reveal, {
						delayMs: 60,
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("h2", {
							className: "font-disp text-[clamp(36px,5.5vw,64px)] uppercase leading-[0.9] tracking-[-0.04em]",
							children: [
								"Sit down.",
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("br", {}),
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: "text-flame",
									children: "Something's waiting."
								})
							]
						}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("ul", {
							className: "mt-8 space-y-3 font-disp text-[clamp(18px,2.4vw,28px)] uppercase leading-[1.05] tracking-[-0.02em] text-[rgba(237,230,218,0.72)]",
							children: [
								/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("li", { children: ["A hero that ", /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: "text-brand",
									children: "pulls you in"
								})] }),
								/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("li", { children: ["Shelves that feel ", /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: "text-flame",
									children: "personal"
								})] }),
								/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("li", { children: ["New titles. ", /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: "text-[#EDE6DA]",
									children: "Old favorites."
								})] }),
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("li", { children: "No hunting. Just the night ahead." })
							]
						})]
					})]
				})
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("section", {
				className: "border-t border-[rgba(237,230,218,0.14)] px-[5vw] py-[10vh]",
				children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					className: "mx-auto grid max-w-[1200px] items-center gap-10 lg:grid-cols-2 lg:gap-14",
					children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Reveal, {
						delayMs: 60,
						className: "lg:order-1",
						children: [
							/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("h2", {
								className: "font-disp text-[clamp(36px,5.5vw,64px)] uppercase leading-[0.9] tracking-[-0.04em]",
								children: [
									"When the world",
									/* @__PURE__ */ (0, import_jsx_runtime.jsx)("br", {}),
									/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
										className: "text-brand",
										children: "watches together."
									})
								]
							}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("ul", {
								className: "mt-8 space-y-3 font-disp text-[clamp(18px,2.4vw,28px)] uppercase leading-[1.05] tracking-[-0.02em] text-[rgba(237,230,218,0.72)]",
								children: [
									/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("li", { children: ["Kickoff. ", /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
										className: "text-flame",
										children: "Overtime."
									})] }),
									/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("li", { children: ["Channels that never ", /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
										className: "text-[#EDE6DA]",
										children: "sleep"
									})] }),
									/* @__PURE__ */ (0, import_jsx_runtime.jsx)("li", { children: "News. Sport. The night still live." }),
									/* @__PURE__ */ (0, import_jsx_runtime.jsx)("li", { children: "Feel the moment — not a commercial break." })
								]
							}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
								to: "/iptv",
								className: "font-mono-ui mt-10 inline-block text-[11px] uppercase tracking-[0.16em] text-brand transition-colors hover:text-flame",
								children: "Explore IPTV Player"
							})
						]
					}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Reveal, {
						className: "lg:order-2",
						children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("img", {
							src: "/brand/forja-iptv-live.jpg",
							alt: "Forja IPTV — live channels and categories",
							width: 1024,
							height: 637,
							className: "h-auto w-full rounded-lg border border-white/10 shadow-[0_32px_80px_-24px_rgba(0,0,0,0.85)]",
							decoding: "async"
						})
					})]
				})
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)(LibraryHubs, {}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("section", {
				className: "border-t border-[rgba(237,230,218,0.14)] px-[5vw] py-[12vh]",
				children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					className: "mx-auto flex max-w-[1100px] flex-col gap-12",
					children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Reveal, { children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("h2", {
						className: "font-disp text-[clamp(40px,7vw,84px)] uppercase leading-[0.9] tracking-[-0.03em]",
						children: [
							"Nights that",
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("br", {}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
								className: "font-serif-i normal-case text-flame",
								children: "belong to you."
							})
						]
					}) }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Reveal, {
						delayMs: 80,
						children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("ul", {
							className: "space-y-8",
							children: [
								/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("li", { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
									className: "font-disp text-[clamp(28px,4vw,44px)] uppercase leading-none text-[#EDE6DA]",
									children: "No interruptions"
								}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
									className: "mt-2 font-disp text-xl uppercase tracking-tight text-[rgba(237,230,218,0.45)] sm:text-2xl",
									children: "The story stays on the screen — not behind an ad."
								})] }),
								/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("li", { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
									className: "font-disp text-[clamp(28px,4vw,44px)] uppercase leading-none text-[#EDE6DA]",
									children: "No decision fatigue"
								}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
									className: "mt-2 font-disp text-xl uppercase tracking-tight text-[rgba(237,230,218,0.45)] sm:text-2xl",
									children: "Open Forja. The night finds you."
								})] }),
								/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("li", { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
									className: "font-disp text-[clamp(28px,4vw,44px)] uppercase leading-none text-[#EDE6DA]",
									children: "No small print"
								}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
									className: "mt-2 font-disp text-xl uppercase tracking-tight text-[rgba(237,230,218,0.45)] sm:text-2xl",
									children: "Free means free. Stay as long as you want."
								})] })
							]
						})
					})]
				})
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("section", {
				className: "relative overflow-hidden border-t border-[rgba(237,230,218,0.14)] px-[5vw] py-[12vh] text-center",
				children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Reveal, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
					className: "font-disp text-[clamp(48px,12vw,140px)] uppercase leading-[0.9] tracking-[-0.04em]",
					children: "Your screens."
				}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", {
					className: "mx-auto mt-8 max-w-3xl font-disp text-[clamp(22px,3.5vw,40px)] uppercase leading-snug tracking-[-0.02em] text-[rgba(237,230,218,0.55)]",
					children: [
						"Desk. Living room.",
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)("br", {}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
							className: "text-[#EDE6DA]",
							children: "Same night. Same Forja."
						})
					]
				})] })
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("section", {
				id: "drop",
				className: "grid grid-cols-1 items-center gap-10 border-t border-[rgba(237,230,218,0.14)] px-[5vw] py-[10vh] md:grid-cols-[0.95fr_1.15fr] md:gap-14 lg:gap-16",
				children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Reveal, { children: [
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("h2", {
						className: "font-disp text-[clamp(40px,10vw,110px)] uppercase leading-[0.85] tracking-[-0.04em]",
						children: [
							"Don't wait",
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("br", {}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
								className: "text-brand",
								children: "for the night."
							})
						]
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", {
						className: "mt-6 max-w-lg font-disp text-[clamp(18px,3vw,36px)] uppercase leading-snug tracking-[-0.02em] text-[rgba(237,230,218,0.55)] sm:mt-8",
						children: [
							"Download Forja.",
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("br", {}),
							"Press play.",
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("br", {}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
								className: "text-[#EDE6DA]",
								children: "It's already free."
							})
						]
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
						ref: magnetRef,
						to: "/download",
						"data-hover": "",
						onMouseMove: onMagnetMove,
						onMouseLeave: onMagnetLeave,
						className: "btn-magnet mt-7 inline-flex w-full items-center justify-center rounded-full px-8 py-4 font-mono-ui text-sm font-bold uppercase tracking-[0.08em] will-change-transform sm:mt-8 sm:w-auto sm:px-[34px] sm:py-5 sm:text-[15px]",
						children: "Get Forja"
					})
				] }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Reveal, {
					delayMs: 100,
					className: "w-full min-w-0",
					children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(NowPlayingPanel, { className: "w-full max-w-none" })
				})]
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)(SiteFooter, {})
		]
	});
}
var SplitComponent = LandingPage;
//#endregion
export { SplitComponent as component };
