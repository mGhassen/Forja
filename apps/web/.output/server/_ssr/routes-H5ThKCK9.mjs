import { r as __toESM } from "../_runtime.mjs";
import { u as require_react } from "../_libs/@floating-ui/react-dom+[...].mjs";
import { s as require_jsx_runtime } from "../_libs/@radix-ui/react-arrow+[...].mjs";
import { n as cn } from "./utils-BshMKIch.mjs";
import { f as Link } from "../_libs/@tanstack/react-router+[...].mjs";
import { n as SiteHeader } from "./site-header-_V616WVj.mjs";
import { r as SiteFooter } from "./legal-shell-YAoAtDsR.mjs";
import { t as Reveal } from "./reveal-BWuY42y3.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/routes-H5ThKCK9.js
var import_react = /* @__PURE__ */ __toESM(require_react());
var import_jsx_runtime = require_jsx_runtime();
/** Freely licensed Blender Foundation open movies (CC BY). See /brand/open-films/ATTRIBUTION.txt */
var OPEN_FILMS = [
	{
		poster: "/brand/open-films/big-buck-bunny.jpg",
		hero: "/brand/open-films/heroes/big-buck-bunny-hero.jpg",
		label: "Big Buck Bunny"
	},
	{
		poster: "/brand/open-films/sintel.jpg",
		hero: "/brand/open-films/heroes/sintel-hero.jpg",
		label: "Sintel"
	},
	{
		poster: "/brand/open-films/tears-of-steel.jpg",
		hero: "/brand/open-films/heroes/tears-of-steel-hero.jpg",
		label: "Tears of Steel"
	},
	{
		poster: "/brand/open-films/sprite-fright.jpg",
		hero: "/brand/open-films/heroes/sprite-fright-hero.jpg",
		label: "Sprite Fright"
	},
	{
		poster: "/brand/open-films/cosmos-laundromat.jpg",
		hero: "/brand/open-films/heroes/cosmos-laundromat-hero.jpg",
		label: "Cosmos Laundromat"
	}
];
var HERO_CYCLE_MS = 4500;
function Icon({ name, className }) {
	const common = {
		className: cn("h-[15px] w-[15px]", className),
		fill: "currentColor"
	};
	switch (name) {
		case "home": return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("svg", {
			viewBox: "0 0 24 24",
			...common,
			children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("path", { d: "M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z" })
		});
		case "search": return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("svg", {
			viewBox: "0 0 24 24",
			...common,
			children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("path", { d: "M15.5 14h-.79l-.28-.27A6.47 6.47 0 0 0 16 9.5 6.5 6.5 0 1 0 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z" })
		});
		case "iptv": return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("svg", {
			viewBox: "0 0 24 24",
			...common,
			children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("path", { d: "M21 3H3c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h5v2h8v-2h5c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm0 14H3V5h18v12z" })
		});
		case "settings": return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("svg", {
			viewBox: "0 0 24 24",
			...common,
			children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("path", { d: "M19.14 12.94c.04-.31.06-.63.06-.94 0-.31-.02-.63-.06-.94l2.03-1.58a.49.49 0 0 0 .12-.61l-1.92-3.32a.49.49 0 0 0-.59-.22l-2.39.96c-.5-.38-1.03-.7-1.62-.94l-.36-2.54a.48.48 0 0 0-.48-.41h-3.84a.48.48 0 0 0-.48.41l-.36 2.54c-.59.24-1.13.57-1.62.94l-2.39-.96a.49.49 0 0 0-.59.22L2.74 8.87a.48.48 0 0 0 .12.61l2.03 1.58c-.04.31-.06.63-.06.94s.02.63.06.94l-2.03 1.58a.49.49 0 0 0-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.48-.41l.36-2.54c.59-.24 1.13-.56 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32a.49.49 0 0 0-.12-.61l-2.03-1.58zM12 15.6A3.6 3.6 0 1 1 12 8.4a3.6 3.6 0 0 1 0 7.2z" })
		});
	}
}
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
		id: "iptv",
		label: "Live",
		icon: "iptv"
	}
];
function ShellScreen() {
	const [activeIndex, setActiveIndex] = (0, import_react.useState)(0);
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
			setActiveIndex((i) => (i + 1) % OPEN_FILMS.length);
		}, HERO_CYCLE_MS);
		return () => window.clearInterval(id);
	}, [reduced]);
	const hero = OPEN_FILMS[activeIndex];
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
							className: cn("flex h-7 w-7 items-center justify-center rounded-md transition-colors sm:h-8 sm:w-8", selected ? "bg-white/[0.08] text-[#1CE783]" : "cursor-default text-white/35"),
							children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Icon, { name: item.icon })
						}, item.id);
					})
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
					title: "Settings",
					className: "mb-0.5 flex h-7 w-7 cursor-default items-center justify-center rounded-md text-white/35 sm:h-8 sm:w-8",
					children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Icon, { name: "settings" })
				})
			]
		}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
			className: "relative min-w-0 flex-1 overflow-hidden",
			children: [
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
					className: "absolute inset-0 overflow-hidden",
					children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
						className: cn("flex h-full", reduced ? "" : "transition-transform duration-700 ease-[cubic-bezier(0.4,0,0.2,1)]"),
						style: { transform: `translateX(-${activeIndex * 100}%)` },
						children: OPEN_FILMS.map((film) => /* @__PURE__ */ (0, import_jsx_runtime.jsx)("img", {
							src: film.hero,
							alt: "",
							className: "h-full min-w-full shrink-0 object-cover object-center"
						}, film.hero))
					})
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
					"aria-hidden": true,
					className: "absolute inset-0 z-[1]",
					style: { background: "linear-gradient(90deg, #0B0A0A 0%, rgba(11,10,10,0.9) 32%, rgba(11,10,10,0.4) 58%, transparent 100%), linear-gradient(0deg, #0B0A0A 0%, transparent 38%), linear-gradient(180deg, rgba(11,10,10,0.55) 0%, transparent 28%)" }
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					className: "absolute inset-x-0 top-0 z-20 flex items-center gap-3 px-2.5 py-2 sm:gap-5 sm:px-3.5 sm:py-2.5",
					children: [
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
							className: "text-[9px] font-semibold tracking-wide text-white sm:text-[10px]",
							children: "Home"
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
							className: "text-[9px] font-semibold tracking-wide text-white/55 sm:text-[10px]",
							children: "Live"
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
							className: "text-[9px] font-semibold tracking-wide text-white/55 sm:text-[10px]",
							children: "Library"
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
					className: "relative z-[2] flex h-full max-w-[58%] flex-col justify-end px-2.5 pb-[4.75rem] pt-10 sm:max-w-[55%] sm:px-3.5 sm:pb-[5.5rem]",
					children: [
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)("h3", {
							className: cn("font-disp text-[clamp(14px,2.4vw,22px)] uppercase leading-[0.95] tracking-tight", !reduced && "animate-now-title"),
							children: hero.label
						}, hero.hero),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
							className: "mt-1 text-[8px] text-white/65 sm:text-[9px]",
							children: "Open movie · Blender Foundation"
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
							className: "mt-2 line-clamp-2 text-[8px] leading-snug text-white/50 sm:text-[9px]",
							children: "A calm shell for streaming - connect playlists and press play."
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
							className: "mt-3 flex gap-2",
							children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
								className: "rounded-full bg-[#1CE783] px-2.5 py-1 text-[8px] font-bold uppercase tracking-wider text-[#0B0A0A]",
								children: "Play"
							}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
								className: "rounded-full border border-white/20 px-2.5 py-1 text-[8px] font-semibold uppercase tracking-wider text-white/70",
								children: "Details"
							})]
						})
					]
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					className: "absolute inset-x-0 bottom-0 z-[2] px-2 pb-2 sm:px-3 sm:pb-2.5",
					children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
						className: "mb-1.5 text-[8px] font-semibold uppercase tracking-[0.14em] text-white/45",
						children: "Featured"
					}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
						className: "flex gap-1.5 overflow-hidden",
						children: OPEN_FILMS.map((item, i) => {
							const selected = i === activeIndex;
							return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("button", {
								type: "button",
								"aria-label": `Show ${item.label}`,
								"aria-current": selected ? "true" : void 0,
								onClick: () => setActiveIndex(i),
								className: cn("relative aspect-[2/3] w-[18%] min-w-[2.4rem] overflow-hidden rounded-md ring-1 transition duration-300", selected ? "z-[1] scale-[1.06] ring-[#1CE783]/80" : "ring-white/10 opacity-75 hover:opacity-100"),
								children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("img", {
									src: item.poster,
									alt: "",
									className: "absolute inset-0 h-full w-full object-cover"
								}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: "absolute inset-x-0 bottom-0 bg-black/55 px-0.5 py-0.5 text-center text-[5px] font-semibold uppercase leading-tight tracking-wide text-white/85 sm:text-[6px]",
									children: item.label
								})]
							}, item.poster);
						})
					})]
				})
			]
		})]
	});
}
function TvBezel({ children }) {
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
		className: "relative mx-auto w-full max-w-[760px]",
		children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
			className: "rounded-[1.1rem] border border-white/15 bg-[#1a1816] p-[0.55rem] shadow-[0_40px_100px_-24px_rgba(0,0,0,0.95)] sm:rounded-[1.35rem] sm:p-[0.7rem]",
			children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
				className: "overflow-hidden rounded-[0.75rem] border border-white/8 bg-black sm:rounded-[0.95rem]",
				children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
					className: "aspect-[16/10] w-full",
					children
				})
			})
		})
	});
}
/** TV mock of Forja Home for the landing hero - CC BY open-film posters. */
function HeroTvMock({ className }) {
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
		className: cn(className),
		children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(TvBezel, { children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(ShellScreen, {}) })
	});
}
/**
* Marketing hero - player app pitch, Download CTA, product mock.
*/
function LandingHero() {
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("header", {
		className: "relative overflow-hidden pt-16 sm:pt-24",
		children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
			"aria-hidden": true,
			className: "pointer-events-none absolute inset-0",
			style: { background: "radial-gradient(ellipse 55% 50% at 85% 40%, rgba(28,231,131,0.12), transparent 55%), radial-gradient(ellipse 45% 45% at 10% 70%, rgba(255,77,28,0.1), transparent 50%)" }
		}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
			className: "relative z-[2] mx-auto grid w-full max-w-[1500px] items-center gap-8 px-[5vw] pb-12 pt-6 sm:pb-16 sm:pt-10 lg:grid-cols-[0.9fr_1.2fr] lg:gap-10 lg:pb-24 lg:pt-14",
			children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
				className: "hero-enter max-w-xl",
				children: [
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("h1", {
						className: "font-disp text-[clamp(34px,9vw,72px)] uppercase leading-[0.9] tracking-[-0.04em]",
						children: [
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
								className: "inline sm:whitespace-nowrap",
								children: "A player built"
							}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("br", {}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
								className: "font-serif-i normal-case text-flame",
								children: "to stream."
							})
						]
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", {
						className: "mt-4 max-w-lg font-disp text-[clamp(16px,4.2vw,28px)] uppercase leading-snug tracking-[-0.02em] text-[rgba(237,230,218,0.55)] sm:mt-5",
						children: [
							"Playback. Guides. Live lists.",
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("br", {}),
							"Sources you connect.",
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("br", {}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
								className: "text-[#EDE6DA]",
								children: "One app. Your screens."
							})
						]
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
						to: "/download",
						"data-hover": "",
						className: "btn-magnet mt-7 inline-flex w-full items-center justify-center rounded-full px-8 py-4 font-mono-ui text-sm font-bold uppercase tracking-[0.08em] shadow-[0_0_32px_rgba(28,231,131,0.35)] will-change-transform sm:mt-8 sm:w-auto sm:px-10 sm:text-[15px]",
						children: "Get the app"
					})
				]
			}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Reveal, {
				variant: "right",
				delayMs: 120,
				className: "w-full max-w-[760px] justify-self-center lg:justify-self-end",
				children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
					className: "animate-float",
					children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(HeroTvMock, { className: "w-full" })
				})
			})]
		})]
	});
}
/** Six moods - open-film art + app/sport stills (CC BY Blender Foundation where noted). */
var MOODS = [
	{
		id: "movies",
		label: "Movies",
		line: "Open films & more",
		accent: "flame",
		backdrop: "/brand/open-films/big-buck-bunny.jpg"
	},
	{
		id: "series",
		label: "Series",
		line: "Episodes & arcs",
		accent: "brand",
		backdrop: "/brand/open-films/sintel.jpg"
	},
	{
		id: "anime",
		label: "Anime",
		line: "Animated worlds",
		accent: "flame",
		backdrop: "/brand/open-films/sprite-fright.jpg"
	},
	{
		id: "asian",
		label: "Asian Drama",
		line: "Stories that hit",
		accent: "brand",
		backdrop: "/brand/open-films/tears-of-steel.jpg"
	},
	{
		id: "iptv",
		label: "Live TV",
		line: "On now",
		accent: "flame",
		backdrop: "/brand/forja-iptv-live.jpg",
		logos: [
			{
				src: "/brand/hubs/tv/fox.svg",
				alt: "FOX"
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
		className: cn("group relative isolate aspect-[5/4] overflow-hidden rounded-2xl border border-white/[0.1] bg-[#121110] sm:aspect-[4/3] lg:aspect-[5/4]", "hover-lift hover-zoom shadow-[0_28px_70px_-28px_rgba(0,0,0,0.9)]", "hover:border-white/20"),
		children: [
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("img", {
				src: mood.backdrop,
				alt: "",
				"aria-hidden": true,
				className: "absolute inset-0 h-full w-full object-cover",
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
/** CC BY Blender Foundation open movies - no TMDB commercial art. */
var REEL = [
	{
		id: "sintel",
		title: "Sintel",
		tag: "Open film",
		poster: "/brand/open-films/sintel.jpg",
		backdrop: "/brand/open-films/sintel.jpg"
	},
	{
		id: "bbb",
		title: "Big Buck Bunny",
		tag: "Open film",
		poster: "/brand/open-films/big-buck-bunny.jpg",
		backdrop: "/brand/open-films/big-buck-bunny.jpg"
	},
	{
		id: "tos",
		title: "Tears of Steel",
		tag: "Open film",
		poster: "/brand/open-films/tears-of-steel.jpg",
		backdrop: "/brand/open-films/tears-of-steel.jpg"
	},
	{
		id: "cosmos",
		title: "Cosmos Laundromat",
		tag: "Open film",
		poster: "/brand/open-films/cosmos-laundromat.jpg",
		backdrop: "/brand/open-films/cosmos-laundromat.jpg"
	}
];
var CYCLE_MS = 4200;
/** Animated “now playing” stack - replaces dry CTA stats. */
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
					src: item.backdrop,
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
							src: prev.poster,
							alt: "",
							"aria-hidden": true,
							className: "absolute top-4 left-0 hidden h-[85%] w-[85%] -rotate-6 rounded-xl object-cover opacity-35 shadow-lg sm:block"
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)("img", {
							src: next.poster,
							alt: "",
							"aria-hidden": true,
							className: "absolute top-4 right-0 hidden h-[85%] w-[85%] rotate-6 rounded-xl object-cover opacity-35 shadow-lg sm:block"
						}),
						REEL.map((item, i) => /* @__PURE__ */ (0, import_jsx_runtime.jsx)("img", {
							src: item.poster,
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
							children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", { children: "Free" }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", { children: "Desk to TV" })]
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
/** Four clear use cases - plain language. */
var NIGHTS = [
	{
		k: "Movies",
		v: "Pick a film. Watch it full screen."
	},
	{
		k: "Series",
		v: "Start a series. Keep the episodes rolling."
	},
	{
		k: "Live sport",
		v: "Pick a match. Watch it as it happens."
	},
	{
		k: "Live TV",
		v: "Add your list. Tune in to any channel."
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
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)(SiteHeader, {}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)(LandingHero, {}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("section", {
				id: "why",
				className: "border-y border-[rgba(237,230,218,0.14)] bg-[#0f0e0d]",
				children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
					className: "mx-auto max-w-[1400px] px-[5vw] pt-14 pb-4 lg:pt-16",
					children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Reveal, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("h2", {
						className: "max-w-[18ch] font-disp text-[clamp(36px,6vw,64px)] uppercase leading-[0.92] tracking-[-0.03em]",
						children: [
							"What you can",
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("br", {}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
								className: "text-flame",
								children: "watch."
							})
						]
					}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
						className: "mt-6 max-w-xl text-base leading-relaxed text-[rgba(237,230,218,0.55)] sm:text-lg",
						children: "Forja is one free app for movies, series, live sport, and live TV."
					})] })
				}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
					className: "mx-auto grid max-w-[1400px] lg:grid-cols-2 xl:grid-cols-4",
					children: NIGHTS.map((d, i) => /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Reveal, {
						delayMs: i * 80,
						variant: i % 2 === 0 ? "left" : "right",
						children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
							className: `hover-lift h-full border-[rgba(237,230,218,0.14)] px-[5vw] py-10 lg:border-r lg:px-8 lg:py-12 ${i === NIGHTS.length - 1 ? "lg:border-r-0" : ""} ${i >= 2 ? "xl:border-t-0" : ""}`,
							children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("h3", {
								className: "font-disp text-[clamp(22px,2.8vw,32px)] uppercase leading-tight tracking-tight",
								children: d.k
							}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
								className: "mt-3 text-base leading-relaxed text-[rgba(237,230,218,0.62)] sm:text-lg",
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
					children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Reveal, {
						variant: "left",
						children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
							className: "hover-zoom rounded-lg",
							children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("img", {
								src: "/brand/forja-home-hero.jpg",
								alt: "Forja home - cinematic hero and featured shelves",
								width: 1024,
								height: 643,
								className: "h-auto w-full rounded-lg border border-white/10 shadow-[0_32px_80px_-24px_rgba(0,0,0,0.85)]",
								decoding: "async"
							})
						})
					}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Reveal, {
						delayMs: 80,
						variant: "right",
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
						variant: "left",
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
									/* @__PURE__ */ (0, import_jsx_runtime.jsx)("li", { children: "Feel the moment as it happens." })
								]
							}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
								to: "/iptv",
								className: "link-draw font-mono-ui mt-10 inline-block text-[11px] uppercase tracking-[0.16em] text-brand transition-colors hover:text-flame",
								children: "Explore IPTV Player"
							})
						]
					}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Reveal, {
						variant: "right",
						className: "lg:order-2",
						children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
							className: "hover-zoom rounded-lg",
							children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("img", {
								src: "/brand/forja-iptv-live.jpg",
								alt: "Forja IPTV - live channels and categories",
								width: 1024,
								height: 637,
								className: "h-auto w-full rounded-lg border border-white/10 shadow-[0_32px_80px_-24px_rgba(0,0,0,0.85)]",
								decoding: "async"
							})
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
									children: "One player"
								}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
									className: "mt-2 font-disp text-xl uppercase tracking-tight text-[rgba(237,230,218,0.45)] sm:text-2xl",
									children: "Movies, series, sport, and live TV in one place."
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
