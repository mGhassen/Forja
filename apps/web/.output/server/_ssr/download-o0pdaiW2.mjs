import { r as __toESM } from "../_runtime.mjs";
import { n as require_react } from "../_libs/@radix-ui/react-compose-refs+[...].mjs";
import { a as require_jsx_runtime } from "../_libs/@radix-ui/react-label+[...].mjs";
import { r as supabaseConfigured } from "./use-auth-BFtWcVvU.mjs";
import { f as Link } from "../_libs/@tanstack/react-router+[...].mjs";
import { n as SiteHeader, r as cn } from "./site-header-D6GWurdS.mjs";
import { a as primaryDownloadsByPlatform, i as assetsForPlatform, n as Reveal, o as startBackgroundDownload, r as SHOWCASE_PLATFORMS, s as useLatestRelease, t as CustomCursor } from "./start-download-CpAgqJjI.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/download-o0pdaiW2.js
var import_react = /* @__PURE__ */ __toESM(require_react());
var import_jsx_runtime = require_jsx_runtime();
var FAQ = [
	{
		q: "What is Forja?",
		a: "Forja is a free app for movies, series, anime, live sport, and live TV — everything in one place so you can relax and watch. Download it for your computer or living-room TV. This site is for getting the app and your account."
	},
	{
		q: "Which download should I pick?",
		a: "Choose the screen you watch on: Windows for PC, macOS for Mac, Linux if that’s your computer, Android TV for the living room. Forja picks a good default when it can — then you just download and open."
	},
	{
		q: "Will it run on my machine?",
		a: "Yes on everyday Windows and Mac computers, most Linux desktops, and Android / Google TV boxes that let you install apps. You’ll need a normal internet connection to browse and watch."
	},
	{
		q: "Do I need an account?",
		a: "No. Download and watch. An account is optional if you want preferences across devices later."
	},
	{
		q: "Windows says the app is unrecognized / blocked",
		a: "Windows often warns on apps it hasn’t seen a lot. That’s caution, not a verdict. If you got Forja from this page, use More info → Run anyway (steps below)."
	},
	{
		q: "Windows shows a red “unsafe” / blocked screen",
		a: "That’s Microsoft Defender being stricter than the usual blue SmartScreen. If you downloaded Forja from this page, open More information and continue — or restore the file from Windows Security → Virus & threat protection → Protection history if it was quarantined."
	},
	{
		q: "Mac says Apple could not verify the app",
		a: "Mac does this for apps outside the App Store. Open Forja once, then allow it in System Settings → Privacy & Security → Open Anyway. Steps are below."
	},
	{
		q: "Antivirus quarantined the download",
		a: "Restore or allow the file, then open it again from this downloads page. Only install Forja from here."
	},
	{
		q: "Anything I should know?",
		a: "Some networks are picky about streams. Live TV needs your own channel list. On Android TV you may need to allow installing apps. Forja still works great without an account."
	}
];
var WINDOWS_SHOTS = [
	{
		src: "/brand/help/windows-01-protected.png",
		alt: "Windows SmartScreen — Windows protected your PC",
		caption: "01 — Windows shows “protected your PC”.",
		w: 1098,
		h: 1035
	},
	{
		src: "/brand/help/windows-02-more-info.png",
		alt: "Windows SmartScreen — click More info",
		caption: "02 — Click More info under the message.",
		w: 538,
		h: 514
	},
	{
		src: "/brand/help/windows-03-run-anyway.jpg",
		alt: "Windows SmartScreen — Run anyway",
		caption: "03 — Click Run anyway to continue.",
		w: 1106,
		h: 1046
	},
	{
		src: "/brand/help/windows-04-on-desktop.jpg",
		alt: "Windows SmartScreen dialog on the desktop",
		caption: "04 — Same warning on the desktop — More info is there.",
		w: 1280,
		h: 720
	},
	{
		src: "/brand/help/windows-05-red-unsafe.png",
		alt: "Microsoft Defender red screen — reported as unsafe",
		caption: "05 — Red “unsafe” screen? Open More information, then continue only if you got Forja from this page.",
		w: 1258,
		h: 835
	}
];
var MACOS_SHOTS = [
	{
		src: "/brand/help/macos-blocked-dialog.png",
		alt: "macOS — Apple could not verify this app",
		caption: "01 — Choose Done (not Move to Trash).",
		w: 520,
		h: 464
	},
	{
		src: "/brand/help/macos-privacy-settings-top.png",
		alt: "macOS System Settings — Privacy & Security",
		caption: "02 — Open System Settings → Privacy & Security.",
		w: 1200,
		h: 700
	},
	{
		src: "/brand/help/macos-open-anyway-closeup.png",
		alt: "macOS Privacy & Security — Open Anyway",
		caption: "03 — Scroll to Security → Open Anyway.",
		w: 1200,
		h: 700
	},
	{
		src: "/brand/help/macos-privacy-open-anyway.png",
		alt: "macOS Privacy & Security full panel with Open Anyway",
		caption: "04 — Confirm Open Anyway, then enter your password.",
		w: 1430,
		h: 1226
	}
];
/** Shared media height for all help cards (px). Width scales with image aspect. */
var SHOT_MEDIA_H = 380;
var SHOT_PAD_X = 40;
var SHOT_MIN_W = 280;
var SHOT_MAX_W = 820;
function shotCardWidth(shot) {
	const mediaW = SHOT_MEDIA_H * shot.w / shot.h;
	return Math.round(Math.min(SHOT_MAX_W, Math.max(SHOT_MIN_W, mediaW + SHOT_PAD_X * 2)));
}
function ShotLightbox({ shot, onClose }) {
	(0, import_react.useEffect)(() => {
		const onKey = (e) => {
			if (e.key === "Escape") onClose();
		};
		document.addEventListener("keydown", onKey);
		const prev = document.body.style.overflow;
		document.body.style.overflow = "hidden";
		return () => {
			document.removeEventListener("keydown", onKey);
			document.body.style.overflow = prev;
		};
	}, [onClose]);
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
		role: "dialog",
		"aria-modal": "true",
		"aria-label": shot.alt,
		className: "fixed inset-0 z-[100] flex items-center justify-center bg-black/88 p-4 sm:p-8",
		onClick: onClose,
		children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("button", {
			type: "button",
			onClick: onClose,
			className: "font-mono-ui absolute top-5 right-5 z-[2] rounded-full border border-white/20 bg-black/50 px-4 py-2 text-[11px] uppercase tracking-[0.14em] text-[#EDE6DA] transition-colors hover:border-brand hover:text-brand",
			children: "Close"
		}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("figure", {
			className: "relative flex max-h-[min(92vh,900px)] w-full max-w-5xl flex-col",
			onClick: (e) => e.stopPropagation(),
			children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
				className: "flex min-h-0 flex-1 items-center justify-center overflow-hidden rounded-2xl border border-[rgba(237,230,218,0.2)] bg-[#0a0a0a] p-3 sm:p-6",
				children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("img", {
					src: shot.src,
					alt: shot.alt,
					className: "max-h-[min(78vh,760px)] w-auto max-w-full object-contain"
				})
			}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("figcaption", {
				className: "mt-4 text-center font-mono-ui text-xs uppercase tracking-[0.12em] text-[rgba(237,230,218,0.65)] sm:text-sm",
				children: shot.caption
			})]
		})]
	});
}
/** One big card at a time — slide between steps; click to enlarge. */
function ShotSlider({ shots, accent = "flame" }) {
	const trackRef = (0, import_react.useRef)(null);
	const [index, setIndex] = (0, import_react.useState)(0);
	const [lightbox, setLightbox] = (0, import_react.useState)(null);
	const labelId = (0, import_react.useId)();
	const goTo = (0, import_react.useCallback)((i) => {
		const el = trackRef.current;
		if (!el) return;
		const clamped = Math.max(0, Math.min(shots.length - 1, i));
		el.children[clamped]?.scrollIntoView({
			behavior: "smooth",
			inline: "start",
			block: "nearest"
		});
		setIndex(clamped);
	}, [shots.length]);
	(0, import_react.useEffect)(() => {
		const el = trackRef.current;
		if (!el) return;
		const onScroll = () => {
			const kids = Array.from(el.children);
			if (!kids.length) return;
			const mid = el.scrollLeft + el.clientWidth * .35;
			let best = 0;
			let bestDist = Infinity;
			kids.forEach((kid, i) => {
				const d = Math.abs(kid.offsetLeft - mid + kid.clientWidth * .35);
				if (d < bestDist) {
					bestDist = d;
					best = i;
				}
			});
			setIndex(best);
		};
		el.addEventListener("scroll", onScroll, { passive: true });
		return () => el.removeEventListener("scroll", onScroll);
	}, []);
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
		className: "mt-10",
		children: [
			/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
				className: "mb-5 flex flex-wrap items-center justify-between gap-4",
				children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", {
					id: labelId,
					className: cn("font-mono-ui text-[11px] uppercase tracking-[0.16em]", accent === "flame" ? "text-flame" : "text-brand"),
					children: [
						"Step ",
						String(index + 1).padStart(2, "0"),
						" / ",
						String(shots.length).padStart(2, "0"),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
							className: "ml-3 hidden text-[rgba(237,230,218,0.35)] sm:inline",
							children: "· click shot to enlarge"
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
							className: "ml-3 text-[rgba(237,230,218,0.35)] sm:hidden",
							children: "· tap to enlarge"
						})
					]
				}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					className: "flex items-center gap-2",
					children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("button", {
						type: "button",
						"data-hover": "",
						"aria-label": "Previous step",
						disabled: index <= 0,
						onClick: () => goTo(index - 1),
						className: "rounded-full border border-[rgba(237,230,218,0.2)] px-4 py-2 font-mono-ui text-[11px] uppercase tracking-[0.12em] text-[#EDE6DA] transition-colors hover:border-brand hover:text-brand disabled:cursor-not-allowed disabled:opacity-30",
						children: "Prev"
					}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("button", {
						type: "button",
						"data-hover": "",
						"aria-label": "Next step",
						disabled: index >= shots.length - 1,
						onClick: () => goTo(index + 1),
						className: "rounded-full border border-[rgba(237,230,218,0.2)] px-4 py-2 font-mono-ui text-[11px] uppercase tracking-[0.12em] text-[#EDE6DA] transition-colors hover:border-brand hover:text-brand disabled:cursor-not-allowed disabled:opacity-30",
						children: "Next"
					})]
				})]
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
				ref: trackRef,
				role: "region",
				"aria-labelledby": labelId,
				className: "flex snap-x snap-mandatory items-stretch gap-5 overflow-x-auto pb-3 [-ms-overflow-style:none] [scrollbar-width:none] [&::-webkit-scrollbar]:hidden",
				style: { height: 452 },
				children: shots.map((shot, i) => {
					return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("button", {
						type: "button",
						"data-hover": "",
						onClick: () => setLightbox(shot),
						style: { width: `min(92vw, ${shotCardWidth(shot)}px)` },
						className: cn("group relative flex h-full shrink-0 snap-start flex-col overflow-hidden rounded-2xl border bg-[#121110] text-left transition-colors", i === index ? "border-[rgba(237,230,218,0.35)]" : "border-[rgba(237,230,218,0.14)] opacity-80"),
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
							className: "flex shrink-0 items-center justify-center bg-[#0a0a0a] px-5 sm:px-8",
							style: { height: SHOT_MEDIA_H },
							children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("img", {
								src: shot.src,
								alt: shot.alt,
								width: shot.w,
								height: shot.h,
								className: "h-full w-auto max-w-full object-contain object-center transition duration-500 group-hover:scale-[1.02]",
								loading: "lazy",
								decoding: "async",
								draggable: false
							})
						}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
							className: "mt-auto flex h-[4.5rem] items-center justify-between gap-4 border-t border-[rgba(237,230,218,0.1)] px-5 sm:px-6",
							children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
								className: "font-mono-ui text-[11px] uppercase leading-snug tracking-[0.1em] text-[rgba(237,230,218,0.55)] sm:text-xs",
								children: shot.caption
							}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
								className: cn("shrink-0 font-mono-ui text-[10px] uppercase tracking-[0.14em]", accent === "flame" ? "text-flame" : "text-brand"),
								children: "Enlarge"
							})]
						})]
					}, shot.src);
				})
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
				className: "mt-5 flex justify-center gap-2",
				children: shots.map((shot, i) => /* @__PURE__ */ (0, import_jsx_runtime.jsx)("button", {
					type: "button",
					"aria-label": `Go to step ${i + 1}`,
					"aria-current": i === index,
					onClick: () => goTo(i),
					className: cn("h-1.5 rounded-full transition-all", i === index ? cn("w-8", accent === "flame" ? "bg-flame" : "bg-brand") : "w-1.5 bg-[rgba(237,230,218,0.25)] hover:bg-[rgba(237,230,218,0.45)]")
				}, shot.src))
			}),
			lightbox ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)(ShotLightbox, {
				shot: lightbox,
				onClose: () => setLightbox(null)
			}) : null
		]
	});
}
function DownloadHelp() {
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
		className: "mt-20 space-y-20 border-t border-[rgba(237,230,218,0.14)] pt-16",
		children: [
			/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("section", {
				id: "faq",
				children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Reveal, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("h2", {
					className: "font-disp text-[clamp(32px,5vw,52px)] uppercase leading-[0.95] tracking-[-0.03em]",
					children: "Quick answers"
				}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
					className: "mt-4 max-w-2xl leading-relaxed text-[rgba(237,230,218,0.5)]",
					children: "What Forja is, which download to grab, and what to do if Windows or Mac hesitates the first time."
				})] }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
					className: "mt-10 divide-y divide-[rgba(237,230,218,0.12)] border-y border-[rgba(237,230,218,0.12)]",
					children: FAQ.map((item, i) => /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Reveal, {
						delayMs: i % 4 * 40,
						children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("details", {
							className: "group py-5",
							children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("summary", {
								className: "flex cursor-pointer list-none items-start justify-between gap-4 [&::-webkit-details-marker]:hidden",
								children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: "font-disp text-lg uppercase tracking-tight text-[#EDE6DA] sm:text-xl",
									children: item.q
								}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("span", {
									className: "font-mono-ui mt-1 shrink-0 text-[11px] uppercase tracking-[0.14em] text-brand transition group-open:text-flame",
									children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
										className: "group-open:hidden",
										children: "Open"
									}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
										className: "hidden group-open:inline",
										children: "Close"
									})]
								})]
							}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
								className: "mt-3 max-w-3xl text-sm leading-relaxed text-[rgba(237,230,218,0.52)] sm:text-base",
								children: item.a
							})]
						})
					}, item.q))
				})]
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("section", {
				id: "windows-smartscreen",
				children: [
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Reveal, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("h2", {
						className: "font-disp max-w-[18ch] text-[clamp(28px,4.5vw,48px)] uppercase leading-[0.95] tracking-[-0.03em]",
						children: "When Windows blocks the download"
					}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
						className: "mt-5 max-w-2xl space-y-3 leading-relaxed text-[rgba(237,230,218,0.5)]",
						children: [
							/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", { children: [
								"Windows sometimes shows ",
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("em", {
									className: "text-[#EDE6DA] not-italic",
									children: "Windows protected your PC"
								}),
								" (blue) for apps it hasn’t seen much yet. That doesn’t mean Forja is unsafe — Windows is just being careful."
							] }),
							/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", { children: [
								"Occasionally you’ll get a ",
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("em", {
									className: "text-[#EDE6DA] not-italic",
									children: "red"
								}),
								" ",
								"Defender screen instead. Same idea — if you downloaded from this page, open",
								" ",
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: "text-[#EDE6DA]",
									children: "More information"
								}),
								" and continue."
							] }),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", { children: "Slide through the shots below and you’re in." })
						]
					})] }),
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("ol", {
						className: "mt-10 space-y-4 font-mono-ui text-[11px] uppercase tracking-[0.12em] text-[rgba(237,230,218,0.55)]",
						children: [
							/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("li", { children: [
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: "text-flame",
									children: "01"
								}),
								" — Open the Forja download. If Windows warns you (blue or red), click ",
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: "text-brand",
									children: "More info"
								}),
								" /",
								" ",
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: "text-brand",
									children: "More information"
								}),
								"."
							] }),
							/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("li", { children: [
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: "text-flame",
									children: "02"
								}),
								" — Then click",
								" ",
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: "text-brand",
									children: "Run anyway"
								}),
								" (or continue past the red screen)."
							] }),
							/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("li", { children: [
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: "text-flame",
									children: "03"
								}),
								" — Still stuck? Right-click the file → Properties → check ",
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: "text-brand",
									children: "Unblock"
								}),
								" → Apply → OK, then open it again. If Defender quarantined it, restore it from Protection history."
							] })
						]
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)(ShotSlider, {
						shots: WINDOWS_SHOTS,
						accent: "flame"
					})
				]
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("section", {
				id: "macos-gatekeeper",
				children: [
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Reveal, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("h2", {
						className: "font-disp max-w-[18ch] text-[clamp(28px,4.5vw,48px)] uppercase leading-[0.95] tracking-[-0.03em]",
						children: "When Mac won’t open Forja"
					}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
						className: "mt-5 max-w-2xl space-y-3 leading-relaxed text-[rgba(237,230,218,0.5)]",
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", { children: [
							"Mac may say ",
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("em", {
								className: "text-[#EDE6DA] not-italic",
								children: "Apple could not verify this app"
							}),
							" the first time. That’s normal for apps outside the App Store. Open the download, put Forja in Applications, then allow it once."
						] }), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", { children: [
							"On recent Macs, go to",
							" ",
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
								className: "text-[#EDE6DA]",
								children: "System Settings → Privacy & Security"
							}),
							"— ",
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
								className: "text-[#EDE6DA]",
								children: "Open Anyway"
							}),
							" shows up after you try once."
						] })]
					})] }),
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("ol", {
						className: "mt-10 space-y-4 font-mono-ui text-[11px] uppercase tracking-[0.12em] text-[rgba(237,230,218,0.55)]",
						children: [
							/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("li", { children: [
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: "text-brand",
									children: "01"
								}),
								" — Open Forja from Applications. When the block dialog appears, choose ",
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: "text-flame",
									children: "Done"
								}),
								" ",
								"(do not Move to Trash)."
							] }),
							/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("li", { children: [
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: "text-brand",
									children: "02"
								}),
								" — Open",
								" ",
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: "text-flame",
									children: "System Settings → Privacy & Security"
								}),
								". Scroll to Security."
							] }),
							/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("li", { children: [
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: "text-brand",
									children: "03"
								}),
								" — Click",
								" ",
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: "text-flame",
									children: "Open Anyway"
								}),
								" next to the Forja message, confirm, and enter your Mac password or use Touch ID if asked."
							] }),
							/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("li", { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
								className: "text-brand",
								children: "04"
							}), " — Optional shortcut: in Finder, Control-click Forja → Open → Open (works on many macOS versions)."] })
						]
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)(ShotSlider, {
						shots: MACOS_SHOTS,
						accent: "brand"
					})
				]
			})
		]
	});
}
function formatBytes(n) {
	if (n == null || n <= 0) return null;
	const mb = n / (1024 * 1024);
	if (mb >= 1) return `${mb.toFixed(1)} MB`;
	return `${Math.round(n / 1024)} KB`;
}
function guessPlatform() {
	if (typeof navigator === "undefined") return "windows";
	const ua = navigator.userAgent.toLowerCase();
	const plat = navigator.platform?.toLowerCase() ?? "";
	if (plat.includes("mac") || ua.includes("mac")) return "macos";
	if (plat.includes("linux") || ua.includes("linux")) return "linux";
	return "windows";
}
function MagnetDownload({ href, label }) {
	const magnetRef = (0, import_react.useRef)(null);
	function onMove(e) {
		const el = magnetRef.current;
		if (!el) return;
		if (!window.matchMedia("(hover: hover) and (pointer: fine)").matches) return;
		if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
		const r = el.getBoundingClientRect();
		const x = e.clientX - (r.left + r.width / 2);
		const y = e.clientY - (r.top + r.height / 2);
		el.style.transform = `translate(${x * .12}px, ${y * .18}px)`;
	}
	function onLeave() {
		if (magnetRef.current) magnetRef.current.style.transform = "";
	}
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("a", {
		ref: magnetRef,
		href,
		"data-hover": "",
		onMouseMove: onMove,
		onMouseLeave: onLeave,
		onClick: (e) => {
			e.preventDefault();
			startBackgroundDownload(href);
		},
		className: "btn-magnet inline-flex max-w-full items-center justify-center gap-3 rounded-full px-6 py-3.5 text-center font-mono-ui text-[11px] font-bold uppercase tracking-[0.1em] will-change-transform sm:px-8 sm:py-4 sm:text-xs",
		children: label
	});
}
function PlatformPicker({ platforms, selectedId, onSelect, assetsById, primaryById }) {
	const selected = platforms.find((p) => p.id === selectedId) ?? platforms[0];
	const assets = assetsById[selected.id] ?? [];
	const primary = primaryById[selected.id] ?? assets[0] ?? null;
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
		className: "grid gap-10 lg:grid-cols-[minmax(0,0.9fr)_minmax(0,1.1fr)] lg:gap-16 lg:items-start",
		children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("nav", {
			"aria-label": "Platforms",
			className: "flex flex-col",
			children: platforms.map((platform, i) => {
				const active = platform.id === selected.id;
				const file = primaryById[platform.id];
				return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					className: cn("group flex items-center gap-3 border-b border-[rgba(237,230,218,0.12)] sm:gap-4", active ? "border-[rgba(237,230,218,0.35)]" : "hover:border-[rgba(237,230,218,0.22)]"),
					children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("button", {
						type: "button",
						"data-hover": "",
						onClick: () => onSelect(platform.id),
						className: "flex min-w-0 flex-1 items-baseline gap-3 py-4 text-left sm:gap-6 sm:py-6",
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("span", {
							className: cn("font-mono-ui w-6 shrink-0 text-[11px] tracking-[0.18em] transition-colors", active ? i % 2 === 0 ? "text-flame" : "text-brand" : "text-[rgba(237,230,218,0.28)] group-hover:text-[rgba(237,230,218,0.5)]"),
							children: ["0", i + 1]
						}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
							className: cn("font-disp text-[clamp(28px,4.5vw,52px)] uppercase leading-none tracking-[-0.03em] transition-all duration-300", active ? "translate-x-1 text-[#EDE6DA] sm:translate-x-2" : "text-[rgba(237,230,218,0.28)] group-hover:text-[rgba(237,230,218,0.55)]"),
							children: platform.label
						})]
					}), file ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("a", {
						href: file.download_url,
						"data-hover": "",
						onClick: (e) => {
							e.preventDefault();
							startBackgroundDownload(file.download_url);
						},
						className: cn("shrink-0 rounded-full px-4 py-2.5 font-mono-ui text-[10px] font-bold uppercase tracking-[0.12em] transition-colors sm:px-5", active ? "btn-magnet" : "border border-[rgba(237,230,218,0.2)] text-[rgba(237,230,218,0.7)] hover:border-brand hover:text-brand"),
						children: "Download"
					}) : /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
						className: "shrink-0 rounded-full border border-white/10 px-4 py-2.5 font-mono-ui text-[10px] font-bold uppercase tracking-[0.12em] text-white/25 sm:px-5",
						children: "Soon"
					})]
				}, platform.id);
			})
		}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
			className: "reveal is-visible relative min-h-[280px] border-t border-[rgba(237,230,218,0.14)] pt-8 lg:border-t-0 lg:border-l lg:pl-12 lg:pt-2",
			children: [
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
					className: cn("font-mono-ui text-[11px] uppercase tracking-[0.2em]", selected.id === "macos" || selected.id === "linux" ? "text-brand" : "text-flame"),
					children: selected.format
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("h2", {
					className: "font-disp mt-4 text-[clamp(40px,6vw,72px)] uppercase leading-[0.88] tracking-[-0.03em]",
					children: selected.label
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
					className: "font-serif-i mt-3 max-w-md text-xl text-[rgba(237,230,218,0.72)] sm:text-2xl",
					children: selected.tagline
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					className: "mt-10 space-y-5",
					children: [primary ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)(MagnetDownload, {
						href: primary.download_url,
						label: `Get Forja · ${selected.label}`
					}) : /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
						className: "inline-flex items-center rounded-full border border-white/15 px-8 py-4 font-mono-ui text-xs font-bold uppercase tracking-[0.1em] text-white/35",
						children: "Coming soon"
					}), assets.length > 0 && /* @__PURE__ */ (0, import_jsx_runtime.jsx)("ul", {
						className: "space-y-2.5 border-t border-[rgba(237,230,218,0.1)] pt-5",
						children: assets.map((a) => /* @__PURE__ */ (0, import_jsx_runtime.jsx)("li", { children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("a", {
							href: a.download_url,
							onClick: (e) => {
								e.preventDefault();
								startBackgroundDownload(a.download_url);
							},
							className: "group/file flex flex-wrap items-baseline gap-x-3 gap-y-1 font-mono-ui text-[11px] uppercase tracking-[0.08em] text-[rgba(237,230,218,0.48)] transition-colors hover:text-brand",
							children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
								className: "text-[rgba(237,230,218,0.72)] group-hover/file:text-brand",
								children: a.name
							}), formatBytes(a.size_bytes) ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
								className: "text-[rgba(237,230,218,0.32)]",
								children: formatBytes(a.size_bytes)
							}) : null]
						}) }, a.id))
					})]
				})
			]
		}, selected.id)]
	});
}
function DownloadPage() {
	const { data, isLoading, isError, error } = useLatestRelease();
	const [selectedId, setSelectedId] = (0, import_react.useState)("windows");
	(0, import_react.useEffect)(() => {
		setSelectedId(guessPlatform());
	}, []);
	const assetsById = (0, import_react.useMemo)(() => {
		const map = {};
		for (const p of SHOWCASE_PLATFORMS) map[p.id] = assetsForPlatform(data?.assets, p);
		return map;
	}, [data?.assets]);
	const primaryById = (0, import_react.useMemo)(() => primaryDownloadsByPlatform(data?.assets), [data?.assets]);
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
		className: "film-grain relative min-h-screen bg-[#0B0A0A] text-[#EDE6DA]",
		children: [
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)(CustomCursor, {}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)(SiteHeader, {}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("main", {
				className: "relative px-[5vw] pb-16 pt-20 sm:pb-24 sm:pt-28",
				children: [
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Reveal, { children: [
						/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("h1", {
							className: "font-disp max-w-[14ch] text-[clamp(40px,11vw,140px)] uppercase leading-[0.84] tracking-[-0.04em]",
							children: [
								"Ready to",
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("br", {}),
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: "text-flame",
									children: "watch?"
								})
							]
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
							className: "mt-6 max-w-2xl space-y-4 text-lg leading-relaxed text-[rgba(237,230,218,0.5)]",
							children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", { children: "Unlimited movies, series, anime, live sport, and TV — free, with no ads. Download Forja for your screen and start watching." }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", { children: "Windows, Mac, Linux, or Android TV. Same Forja everywhere." })]
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
							className: "mt-8 flex flex-wrap gap-4 font-mono-ui text-[11px] uppercase tracking-[0.14em]",
							children: [
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("a", {
									href: "#faq",
									className: "text-[rgba(237,230,218,0.45)] transition-colors hover:text-brand",
									children: "FAQ"
								}),
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("a", {
									href: "#windows-smartscreen",
									className: "text-[rgba(237,230,218,0.45)] transition-colors hover:text-brand",
									children: "Windows blocked the download?"
								}),
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("a", {
									href: "#macos-gatekeeper",
									className: "text-[rgba(237,230,218,0.45)] transition-colors hover:text-flame",
									children: "Mac won't open it?"
								})
							]
						})
					] }),
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Reveal, {
						delayMs: 80,
						children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
							className: "mt-12 flex flex-wrap items-end justify-between gap-4 border-y border-[rgba(237,230,218,0.14)] py-5",
							children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", { children: [
								isLoading && /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
									className: "font-mono-ui text-xs uppercase tracking-[0.16em] text-[rgba(237,230,218,0.42)]",
									children: "Checking latest…"
								}),
								isError && /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", {
									className: "font-mono-ui text-xs uppercase tracking-[0.12em] text-red-300",
									children: ["Downloads are taking a break", error instanceof Error ? ` — ${error.message}` : ""]
								}),
								!isLoading && !isError && data && /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(import_jsx_runtime.Fragment, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", {
									className: "font-disp text-3xl uppercase tracking-tight sm:text-4xl",
									children: ["v", data.version]
								}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", {
									className: "font-mono-ui mt-1 text-[11px] uppercase tracking-[0.14em] text-[rgba(237,230,218,0.42)]",
									children: [
										"Fresh as of",
										" ",
										new Date(data.published_at).toLocaleDateString(void 0, {
											year: "numeric",
											month: "short",
											day: "numeric"
										})
									]
								})] }),
								!isLoading && !isError && !data && /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
									className: "font-mono-ui text-xs uppercase tracking-[0.14em] text-[rgba(237,230,218,0.42)]",
									children: supabaseConfigured ? "Nothing to grab yet — check back soon" : "Downloads are not ready on this site yet"
								})
							] })
						})
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Reveal, {
						delayMs: 120,
						children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
							className: "mt-14",
							children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(PlatformPicker, {
								platforms: SHOWCASE_PLATFORMS,
								selectedId,
								onSelect: setSelectedId,
								assetsById,
								primaryById
							})
						})
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Reveal, {
						delayMs: 160,
						children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
							className: "mt-16 grid gap-10 border-t border-[rgba(237,230,218,0.14)] pt-12 lg:grid-cols-2",
							children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", { children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
								className: "space-y-3 text-[rgba(237,230,218,0.5)]",
								children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
									className: "font-serif-i text-xl text-[#EDE6DA] sm:text-2xl",
									children: "Android TV for the big screen and the remote."
								}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
									className: "leading-relaxed",
									children: "Same movies, series, live TV, and sport as on your computer — made for the couch. If two downloads are listed, pick the one for your TV box; either way you're watching Forja."
								})]
							}) }), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
								className: "space-y-3 leading-relaxed text-[rgba(237,230,218,0.5)]",
								children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", { children: "An account is optional. Download Forja and watch — no sign-up wall." }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", { children: "If you want one later for preferences across devices, it's there when you need it." })]
							}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
								className: "mt-5 flex flex-wrap gap-4 font-mono-ui text-xs uppercase tracking-[0.12em]",
								children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
									to: "/signup",
									className: "text-brand hover:text-flame hover:underline",
									children: "Account"
								}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
									to: "/",
									className: "text-[rgba(237,230,218,0.42)] transition-colors hover:text-[#EDE6DA]",
									children: "Home"
								})]
							})] })]
						})
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)(DownloadHelp, {}),
					data?.body ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Reveal, {
						delayMs: 180,
						children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("details", {
							className: "mt-14 group border-t border-[rgba(237,230,218,0.14)] pt-10",
							children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("summary", {
								className: "font-mono-ui cursor-pointer list-none text-xs uppercase tracking-[0.18em] text-[rgba(237,230,218,0.42)] transition-colors hover:text-flame [&::-webkit-details-marker]:hidden",
								children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("span", {
									className: "group-open:text-brand",
									children: ["What's new · v", data.version]
								})
							}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("pre", {
								className: "mt-5 max-h-72 overflow-auto whitespace-pre-wrap font-sans text-sm leading-relaxed text-[rgba(237,230,218,0.55)]",
								children: data.body
							})]
						})
					}) : null
				]
			})
		]
	});
}
var SplitComponent = DownloadPage;
//#endregion
export { SplitComponent as component };
