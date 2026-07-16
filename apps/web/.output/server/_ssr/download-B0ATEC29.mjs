import { r as __toESM } from "../_runtime.mjs";
import { n as require_react } from "../_libs/@radix-ui/react-compose-refs+[...].mjs";
import { a as require_jsx_runtime } from "../_libs/@radix-ui/react-label+[...].mjs";
import { n as supabase, r as supabaseConfigured } from "./use-auth-xp43OQr8.mjs";
import { n as SiteHeader, r as cn } from "./site-header-dl4sTjGo.mjs";
import { t as useQuery } from "../_libs/tanstack__react-query.mjs";
import { r as SiteFooter } from "./legal-shell-CrLn1IML.mjs";
import { t as Reveal } from "./reveal-DOm7XitX.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/download-B0ATEC29.js
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
		a: "Windows often warns on apps it hasn’t seen a lot. That’s caution, not a verdict. If you got Forja from this page, use More info → Run anyway.",
		guideHref: "#windows-smartscreen",
		guideLabel: "See the photo steps for Windows"
	},
	{
		q: "Windows shows a red “unsafe” / blocked screen",
		a: "That’s Microsoft Defender being stricter than the usual blue SmartScreen. If you downloaded Forja from this page, open More information and continue — or restore the file from Windows Security → Virus & threat protection → Protection history if it was quarantined.",
		guideHref: "#windows-smartscreen",
		guideLabel: "See the photo steps for Windows"
	},
	{
		q: "Mac says Apple could not verify the app",
		a: "Mac does this for apps outside the App Store. Open Forja once, then allow it in System Settings → Privacy & Security → Open Anyway.",
		guideHref: "#macos-gatekeeper",
		guideLabel: "See the photo steps for Mac"
	},
	{
		q: "Antivirus quarantined the download",
		a: "Restore or allow the file, then open it again from this downloads page. Only install Forja from here.",
		guideHref: "#windows-smartscreen",
		guideLabel: "See the Windows photo guide"
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
		title: "Step 1 — Windows stopped the open",
		body: "You may see “Windows protected your PC.” This is common for new apps. It does not mean Forja is bad. Stay on this screen and go to the next step.",
		w: 1098,
		h: 1035
	},
	{
		src: "/brand/help/windows-02-more-info.png",
		alt: "Windows SmartScreen — click More info",
		title: "Step 2 — Click More info",
		body: "Under the warning message, click More info. Windows will show you more choices so you can keep going.",
		w: 538,
		h: 514
	},
	{
		src: "/brand/help/windows-03-run-anyway.jpg",
		alt: "Windows SmartScreen — Run anyway",
		title: "Step 3 — Click Run anyway",
		body: "Now click Run anyway. Forja will start. You only need to do this the first time.",
		w: 1106,
		h: 1046
	},
	{
		src: "/brand/help/windows-04-on-desktop.jpg",
		alt: "Windows SmartScreen dialog on the desktop",
		title: "Step 4 — Same warning on the desktop",
		body: "If the warning appears on your desktop instead, it is the same thing. Click More info, then Run anyway.",
		w: 1280,
		h: 720
	},
	{
		src: "/brand/help/windows-05-red-unsafe.png",
		alt: "Microsoft Defender red screen — reported as unsafe",
		title: "Step 5 — Red “unsafe” screen",
		body: "Sometimes Windows shows a red screen instead of blue. Click More information, then continue — only if you downloaded Forja from this page.",
		w: 1258,
		h: 835
	}
];
var MACOS_SHOTS = [
	{
		src: "/brand/help/macos-blocked-dialog.png",
		alt: "macOS — Apple could not verify this app",
		title: "Step 1 — Mac blocks the first open",
		body: "Mac may say it could not verify the app. That is normal outside the App Store. Click Done. Do not move Forja to the Trash.",
		w: 520,
		h: 464
	},
	{
		src: "/brand/help/macos-privacy-settings-top.png",
		alt: "macOS System Settings — Privacy & Security",
		title: "Step 2 — Open Privacy & Security",
		body: "Open System Settings, then go to Privacy & Security. You will allow Forja here.",
		w: 1200,
		h: 700
	},
	{
		src: "/brand/help/macos-open-anyway-closeup.png",
		alt: "macOS Privacy & Security — Open Anyway",
		title: "Step 3 — Find Open Anyway",
		body: "Scroll down to the Security section. You should see a message about Forja with an Open Anyway button.",
		w: 1200,
		h: 700
	},
	{
		src: "/brand/help/macos-privacy-open-anyway.png",
		alt: "macOS Privacy & Security full panel with Open Anyway",
		title: "Step 4 — Allow Forja once",
		body: "Click Open Anyway, confirm, then type your Mac password (or use Touch ID). After that, Forja opens normally.",
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
			}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("figcaption", {
				className: "mt-4 space-y-2 text-center",
				children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
					className: "font-disp text-lg uppercase tracking-tight text-[#EDE6DA] sm:text-xl",
					children: shot.title
				}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
					className: "mx-auto max-w-2xl text-base leading-relaxed text-[rgba(237,230,218,0.65)] sm:text-lg",
					children: shot.body
				})]
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
				style: { height: 548 },
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
							className: "mt-auto flex min-h-[10.5rem] flex-col justify-between gap-3 border-t border-[rgba(237,230,218,0.1)] px-5 py-4 sm:min-h-[11rem] sm:px-6 sm:py-5",
							children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
								className: "space-y-2",
								children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
									className: "font-disp text-base uppercase leading-tight tracking-tight text-[#EDE6DA] sm:text-lg",
									children: shot.title
								}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
									className: "text-sm leading-relaxed text-[rgba(237,230,218,0.62)] normal-case sm:text-[15px] sm:leading-relaxed",
									children: shot.body
								})]
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
							}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
								className: "mt-3 max-w-3xl space-y-3",
								children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
									className: "text-sm leading-relaxed text-[rgba(237,230,218,0.52)] sm:text-base",
									children: item.a
								}), item.guideHref ? /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("a", {
									href: item.guideHref,
									className: "font-mono-ui inline-flex text-[12px] uppercase tracking-[0.14em] text-brand transition-colors hover:text-flame sm:text-[13px]",
									children: [item.guideLabel ?? "See the photo steps", " →"]
								}) : null]
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
						className: "mt-5 max-w-2xl space-y-3 text-base leading-relaxed text-[rgba(237,230,218,0.55)] sm:text-lg",
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", { children: "Windows sometimes shows a warning the first time you open Forja. That is normal for new apps — it does not mean Forja is unsafe." }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", { children: "Follow the steps below. Use the photos as a guide. Click a photo to make it bigger." })]
					})] }),
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("ol", {
						className: "mt-10 max-w-2xl space-y-5 text-base leading-relaxed text-[rgba(237,230,218,0.62)] sm:text-lg",
						children: [
							/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("li", { children: [
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: "font-semibold text-flame",
									children: "1."
								}),
								" Open the Forja file you downloaded. If Windows shows a warning, click",
								" ",
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: "text-[#EDE6DA]",
									children: "More info"
								}),
								"."
							] }),
							/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("li", { children: [
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: "font-semibold text-flame",
									children: "2."
								}),
								" Click",
								" ",
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: "text-[#EDE6DA]",
									children: "Run anyway"
								}),
								" (or continue on the red screen if that is what you see)."
							] }),
							/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("li", { children: [
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: "font-semibold text-flame",
									children: "3."
								}),
								" Still stuck? Right-click the file → Properties → check ",
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: "text-[#EDE6DA]",
									children: "Unblock"
								}),
								" ",
								"→ Apply → OK, then open it again."
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
						className: "mt-5 max-w-2xl space-y-3 text-base leading-relaxed text-[rgba(237,230,218,0.55)] sm:text-lg",
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", { children: "Mac may say it could not verify the app the first time. That is normal for apps that are not from the App Store." }), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", { children: [
							"Put Forja in Applications, try to open it once, then allow it in",
							" ",
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
								className: "text-[#EDE6DA]",
								children: "System Settings → Privacy & Security"
							}),
							"."
						] })]
					})] }),
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("ol", {
						className: "mt-10 max-w-2xl space-y-5 text-base leading-relaxed text-[rgba(237,230,218,0.62)] sm:text-lg",
						children: [
							/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("li", { children: [
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: "font-semibold text-brand",
									children: "1."
								}),
								" Open Forja. When the block dialog appears, click ",
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: "text-[#EDE6DA]",
									children: "Done"
								}),
								" — not Move to Trash."
							] }),
							/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("li", { children: [
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: "font-semibold text-brand",
									children: "2."
								}),
								" Open",
								" ",
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: "text-[#EDE6DA]",
									children: "System Settings → Privacy & Security"
								}),
								" ",
								"and scroll to Security."
							] }),
							/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("li", { children: [
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: "font-semibold text-brand",
									children: "3."
								}),
								" Click",
								" ",
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: "text-[#EDE6DA]",
									children: "Open Anyway"
								}),
								", confirm, and enter your password if asked. Forja will open after that."
							] })
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
var PREFIX_RE = /^\*\*(Add|Change|Fix|Remove):\*\*\s*/i;
function parseBlocks(markdown) {
	const blocks = [];
	for (const raw of markdown.split(/\r?\n/)) {
		const trimmed = raw.trimEnd().trim();
		if (!trimmed) continue;
		if (trimmed.startsWith("# ")) {
			blocks.push({
				type: "h1",
				text: trimmed.slice(2).trim()
			});
			continue;
		}
		if (trimmed.startsWith("## ")) {
			blocks.push({
				type: "h2",
				text: trimmed.slice(3).trim()
			});
			continue;
		}
		if (trimmed.startsWith("### ")) {
			blocks.push({
				type: "h3",
				text: trimmed.slice(4).trim()
			});
			continue;
		}
		if (trimmed.startsWith("- ") || trimmed.startsWith("* ")) {
			const body = trimmed.slice(2).trim();
			const m = body.match(PREFIX_RE);
			if (m) blocks.push({
				type: "li",
				prefix: m[1],
				text: body.slice(m[0].length).trim().replace(/\*\*/g, "")
			});
			else blocks.push({
				type: "li",
				prefix: null,
				text: body.replace(/\*\*/g, "")
			});
			continue;
		}
		if (trimmed.startsWith("**Status:**") || trimmed.startsWith("**Since release:**")) continue;
		if (trimmed === "---") continue;
		blocks.push({
			type: "p",
			text: trimmed.replace(/\*\*/g, "")
		});
	}
	return blocks;
}
function prefixClass(prefix) {
	switch (prefix.toLowerCase()) {
		case "add": return "text-brand";
		case "fix": return "text-flame";
		case "change": return "text-[rgba(237,230,218,0.85)]";
		case "remove": return "text-red-300";
		default: return "text-brand";
	}
}
/** Renders Forja release-note markdown with styled groups and change prefixes. */
function ReleaseNotes({ markdown, className }) {
	const blocks = parseBlocks(markdown);
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
		className: cn("max-h-80 space-y-4 overflow-auto pr-1 text-sm leading-relaxed", className),
		children: blocks.map((b, i) => {
			if (b.type === "h1") return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("h3", {
				className: "font-disp text-xl uppercase tracking-tight text-[#EDE6DA] sm:text-2xl",
				children: b.text
			}, i);
			if (b.type === "h2") return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("h4", {
				className: "font-disp text-lg uppercase tracking-tight text-[#EDE6DA]",
				children: b.text
			}, i);
			if (b.type === "h3") return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
				className: "font-mono-ui pt-2 text-[11px] uppercase tracking-[0.18em] text-brand first:pt-0",
				children: b.text
			}, i);
			if (b.type === "li") return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
				className: "flex gap-2.5 pl-0.5",
				children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", { className: "mt-2 h-1 w-1 shrink-0 rounded-full bg-[rgba(237,230,218,0.35)]" }), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", {
					className: "text-[rgba(237,230,218,0.62)]",
					children: [b.prefix ? /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(import_jsx_runtime.Fragment, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("span", {
						className: cn("font-semibold", prefixClass(b.prefix)),
						children: [b.prefix, ":"]
					}), " "] }) : null, b.text]
				})]
			}, i);
			return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
				className: "text-[rgba(237,230,218,0.5)]",
				children: b.text
			}, i);
		})
	});
}
/** Platforms Forja ships today. */
var SHOWCASE_PLATFORMS = [
	{
		id: "windows",
		label: "Windows",
		tagline: "Full player on your PC — same Forja as everywhere else.",
		format: "For your PC",
		match: ["windows"]
	},
	{
		id: "macos",
		label: "macOS",
		tagline: "Streaming player for Mac — desk or couch.",
		format: "For your Mac",
		match: ["macos"]
	},
	{
		id: "linux",
		label: "Linux",
		tagline: "Same player controls — no fuss.",
		format: "For Linux",
		match: ["linux"]
	},
	{
		id: "android_tv",
		label: "Android TV",
		tagline: "Living-room player. Remote in hand.",
		format: "For the TV",
		match: ["android_tv", "android"]
	}
];
var GITHUB_LATEST = `https://api.github.com/repos/mGhassen/Forja/releases/latest`;
function detectPlatform(name) {
	const lower = name.toLowerCase();
	if (lower.includes("windows") || lower.endsWith(".exe") || lower.endsWith(".msi")) return "windows";
	if (lower.includes("macos") || lower.includes("darwin") || lower.endsWith(".dmg")) return "macos";
	if (lower.includes("linux") || lower.endsWith(".appimage") || lower.endsWith(".deb") || lower.endsWith(".rpm")) return "linux";
	if (lower.includes("android-tv") || lower.includes("android_tv") || lower.includes("androidtv")) return "android_tv";
	if (lower.endsWith(".apk") || lower.includes("android")) return "android_tv";
	if (lower.includes("ios") || lower.endsWith(".ipa")) return "ios";
	return "other";
}
function fromGitHub(release) {
	const version = release.tag_name.replace(/^v/, "");
	const releaseId = `gh-${release.id}`;
	return {
		id: releaseId,
		tag: release.tag_name,
		version,
		body: release.body,
		published_at: release.published_at,
		html_url: release.html_url,
		source: "github",
		synced_at: (/* @__PURE__ */ new Date()).toISOString(),
		assets: (release.assets ?? []).map((asset) => ({
			id: `gh-asset-${asset.id}`,
			release_id: releaseId,
			platform: detectPlatform(asset.name),
			name: asset.name,
			download_url: asset.browser_download_url,
			size_bytes: asset.size
		}))
	};
}
async function fetchGitHubLatest() {
	const res = await fetch(GITHUB_LATEST, { headers: {
		Accept: "application/vnd.github+json",
		"User-Agent": "forja-web"
	} });
	if (!res.ok) throw new Error(`GitHub releases ${res.status}`);
	return fromGitHub(await res.json());
}
async function fetchSupabaseLatest() {
	if (!supabaseConfigured) return null;
	const { data, error } = await supabase.from("releases").select("*").order("published_at", { ascending: false }).limit(1).maybeSingle();
	if (error) throw error;
	if (!data) return null;
	const release = data;
	const { data: assetsData, error: assetsError } = await supabase.from("release_assets").select("*").eq("release_id", release.id);
	if (assetsError) throw assetsError;
	const assets = assetsData ?? [];
	if (!assets.length) return null;
	return {
		...release,
		assets
	};
}
/**
* Latest release for download buttons.
* Prefer GitHub Releases (always public); use Supabase mirror only if it has assets.
*/
function useLatestRelease() {
	return useQuery({
		queryKey: ["releases", "latest"],
		queryFn: async () => {
			try {
				const mirrored = await fetchSupabaseLatest();
				if (mirrored?.assets.length) return mirrored;
			} catch {}
			return fetchGitHubLatest();
		},
		staleTime: 6e4
	});
}
function assetsForPlatform(assets, platform) {
	if (!assets?.length) return [];
	return assets.filter((a) => platform.match.includes(a.platform));
}
/** Prefer the same installer the app updater would pick for that platform. */
function primaryAssetForPlatform(assets, platform) {
	const list = assetsForPlatform(assets, platform);
	if (!list.length) return null;
	const name = (a) => a.name.toLowerCase();
	const find = (ok) => list.find((a) => ok(name(a)));
	switch (platform.id) {
		case "windows": return find((n) => n.includes("windows") && n.endsWith(".exe")) ?? list[0] ?? null;
		case "macos": return find((n) => n.includes("arm64") && n.endsWith(".dmg")) ?? find((n) => n.endsWith(".dmg")) ?? list[0] ?? null;
		case "linux": return find((n) => n.includes("linux") && (n.endsWith(".appimage") || n.endsWith(".deb"))) ?? list[0] ?? null;
		case "android_tv": return find((n) => n.includes("android-tv") && n.endsWith(".apk")) ?? find((n) => n.endsWith(".apk")) ?? list[0] ?? null;
		default: return list[0] ?? null;
	}
}
/** Latest primary download URL per showcase platform (null when missing). */
function primaryDownloadsByPlatform(assets) {
	const out = {};
	for (const p of SHOWCASE_PLATFORMS) out[p.id] = primaryAssetForPlatform(assets, p);
	return out;
}
/**
* Start a file download without opening a new tab / navigating away.
* Uses a hidden iframe so GitHub’s Content-Disposition: attachment
* is handled in the background (cross-origin `download` attrs are ignored).
*/
function startBackgroundDownload(url) {
	if (typeof document === "undefined") return;
	const iframe = document.createElement("iframe");
	iframe.setAttribute("aria-hidden", "true");
	iframe.tabIndex = -1;
	iframe.style.cssText = "position:fixed;width:0;height:0;border:0;visibility:hidden;pointer-events:none";
	iframe.src = url;
	document.body.appendChild(iframe);
	window.setTimeout(() => {
		iframe.remove();
	}, 12e4);
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
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)(SiteHeader, {}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("main", {
				className: "relative px-[5vw] pb-16 pt-20 sm:pb-24 sm:pt-28",
				children: [
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Reveal, { children: [
						/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("h1", {
							className: "font-disp max-w-[14ch] text-[clamp(40px,11vw,140px)] uppercase leading-[0.84] tracking-[-0.04em]",
							children: [
								"Get the",
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("br", {}),
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: "text-flame",
									children: "player."
								})
							]
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
							className: "mt-6 max-w-2xl space-y-4 text-lg leading-relaxed text-[rgba(237,230,218,0.5)]",
							children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", { children: "Forja is a free media player for streaming — playback, live playlists, and controls on the screen you use." }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", { children: "Windows, Mac, Linux, or Android TV. Same player everywhere." })]
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
					(isLoading || isError || !isLoading && !isError && !data) && /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Reveal, {
						delayMs: 80,
						children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
							className: "mt-12 border-y border-[rgba(237,230,218,0.14)] py-5",
							children: [
								isLoading && /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
									className: "font-mono-ui text-xs uppercase tracking-[0.16em] text-[rgba(237,230,218,0.42)]",
									children: "Checking latest…"
								}),
								isError && /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", {
									className: "font-mono-ui text-xs uppercase tracking-[0.12em] text-red-300",
									children: ["Downloads are taking a break", error instanceof Error ? ` — ${error.message}` : ""]
								}),
								!isLoading && !isError && !data && /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
									className: "font-mono-ui text-xs uppercase tracking-[0.14em] text-[rgba(237,230,218,0.42)]",
									children: supabaseConfigured ? "Nothing to grab yet — check back soon" : "Downloads are not ready on this site yet"
								})
							]
						})
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Reveal, {
						delayMs: 120,
						children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
							id: "platforms",
							className: "mt-14 scroll-mt-28",
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
						children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("section", {
							className: "relative mt-20 overflow-hidden border-t border-[rgba(237,230,218,0.14)] pt-16",
							children: [
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
									className: "font-mono-ui text-[11px] uppercase tracking-[0.2em] text-brand",
									children: "From download to stream"
								}),
								/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("h2", {
									className: "mt-4 max-w-[14ch] font-disp text-[clamp(40px,8vw,88px)] uppercase leading-[0.88] tracking-[-0.04em]",
									children: [
										"Three steps.",
										/* @__PURE__ */ (0, import_jsx_runtime.jsx)("br", {}),
										/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
											className: "font-serif-i normal-case text-flame",
											children: "Zero drama."
										})
									]
								}),
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("ol", {
									className: "mt-14 grid gap-0 border-y border-[rgba(237,230,218,0.14)] md:grid-cols-3",
									children: [
										{
											n: "01",
											title: "Pick your screen",
											body: "Windows, Mac, Linux, or the TV. One click."
										},
										{
											n: "02",
											title: "Install & open",
											body: "First launch takes a minute. Then you're set."
										},
										{
											n: "03",
											title: "Connect & play",
											body: "Add your sources or playlists. Start streaming."
										}
									].map((step, i) => /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("li", {
										className: cn("hover-lift group relative px-0 py-10 md:px-8 md:py-12", i < 2 && "border-b border-[rgba(237,230,218,0.14)] md:border-b-0 md:border-r"),
										children: [
											/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
												className: "font-mono-ui text-xs tracking-[0.18em] text-flame transition-colors group-hover:text-brand",
												children: step.n
											}),
											/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
												className: "mt-4 font-disp text-[clamp(26px,3.5vw,40px)] uppercase leading-[0.95] tracking-[-0.03em]",
												children: step.title
											}),
											/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
												className: "mt-3 max-w-[28ch] text-base leading-relaxed text-[rgba(237,230,218,0.55)]",
												children: step.body
											})
										]
									}, step.n))
								}),
								/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
									className: "mt-14 flex flex-col gap-6 sm:flex-row sm:items-end sm:justify-between",
									children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", {
										className: "max-w-xl font-disp text-[clamp(22px,3.2vw,36px)] uppercase leading-snug tracking-[-0.02em] text-[rgba(237,230,218,0.72)]",
										children: [
											"Desk. Couch.",
											" ",
											/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
												className: "text-[#EDE6DA]",
												children: "Big screen."
											}),
											/* @__PURE__ */ (0, import_jsx_runtime.jsx)("br", {}),
											/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
												className: "text-brand",
												children: "Same player."
											})
										]
									}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("a", {
										href: "#platforms",
										className: "link-draw font-mono-ui shrink-0 text-[11px] uppercase tracking-[0.16em] text-flame transition-colors hover:text-brand",
										children: "Back to downloads ↑"
									})]
								})
							]
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
							}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
								className: "mt-5",
								children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(ReleaseNotes, { markdown: data.body })
							})]
						})
					}) : null
				]
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)(SiteFooter, {})
		]
	});
}
var SplitComponent = DownloadPage;
//#endregion
export { SplitComponent as component };
