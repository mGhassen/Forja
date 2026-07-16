import { r as __toESM } from "../_runtime.mjs";
import { n as require_react } from "../_libs/@radix-ui/react-compose-refs+[...].mjs";
import { a as require_jsx_runtime } from "../_libs/@radix-ui/react-label+[...].mjs";
import { i as useAuth } from "./use-auth-xp43OQr8.mjs";
import { f as Link, m as useNavigate } from "../_libs/@tanstack/react-router+[...].mjs";
import { n as SiteHeader, r as cn } from "./site-header-CQxqjJmj.mjs";
import { a as CardHeader, i as CardDescription, n as Card, o as CardTitle, r as CardContent, t as Button } from "./card-BLl6aleQ.mjs";
import { t as Input } from "./input-tsNMiz--.mjs";
import { t as Label } from "./label-D3h4O29f.mjs";
import { t as Reveal } from "./reveal-C110PiPA.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/login-D2yS9Hqp.js
var import_react = /* @__PURE__ */ __toESM(require_react());
var import_jsx_runtime = require_jsx_runtime();
var WORDS = [
	"stream",
	"sync",
	"live",
	"play"
];
var BEATS = [
	{
		n: "01",
		title: "One player",
		line: "Movies, series, anime, live TV — same controls, same calm.",
		accent: "brand"
	},
	{
		n: "02",
		title: "Your sources",
		line: "Playlists you connect. Guides inside the player. Nothing hosted here.",
		accent: "flame"
	},
	{
		n: "03",
		title: "Every screen",
		line: "Desk, couch, TV — pick up where you left off when you sign in.",
		accent: "brand"
	}
];
var MARQUEE = [
	"Playback",
	"Guides",
	"Live lists",
	"Subtitles",
	"Desk to TV",
	"No ads"
];
var CYCLE_MS = 3200;
function LoginStoryPanel() {
	const [wordIndex, setWordIndex] = (0, import_react.useState)(0);
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
			setWordIndex((i) => (i + 1) % WORDS.length);
		}, CYCLE_MS);
		return () => window.clearInterval(id);
	}, [reduced]);
	const word = WORDS[wordIndex];
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("section", {
		className: "relative flex min-h-[min(52vh,520px)] flex-col justify-center overflow-hidden border-b border-[rgba(237,230,218,0.1)] px-[5vw] py-14 lg:min-h-0 lg:border-b-0 lg:border-r lg:py-20",
		children: [
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
				"aria-hidden": true,
				className: "pointer-events-none absolute inset-0",
				style: { background: "radial-gradient(ellipse 70% 60% at 20% 40%, rgba(28,231,131,0.14), transparent 55%), radial-gradient(ellipse 55% 50% at 85% 75%, rgba(255,77,28,0.12), transparent 50%)" }
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
				"aria-hidden": true,
				className: "animate-login-glow pointer-events-none absolute -top-24 right-[-10%] h-64 w-64 rounded-full bg-forja-green/20 blur-3xl"
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
				className: "hero-enter relative z-[1] max-w-xl",
				children: [
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", {
						className: "font-mono-ui text-[11px] uppercase tracking-[0.22em] text-forja-green",
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", { className: "animate-live-dot mr-2 inline-block h-1.5 w-1.5 rounded-full bg-forja-green align-middle" }), "Creative player platform"]
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("h1", {
						className: "mt-5 font-disp text-[clamp(36px,7vw,72px)] uppercase leading-[0.9] tracking-[-0.04em]",
						children: [
							"Built to",
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("br", {}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("span", {
								className: "animate-word-in font-serif-i inline-block normal-case text-flame",
								children: [word, "."]
							}, word)
						]
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", {
						className: "mt-6 max-w-md font-disp text-[clamp(17px,2.4vw,26px)] uppercase leading-snug tracking-[-0.02em] text-[rgba(237,230,218,0.55)]",
						children: [
							"Forja is a player — not a catalog pitch.",
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("br", {}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
								className: "text-[#EDE6DA]",
								children: "Sign in to sync settings across your screens."
							})
						]
					})
				]
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("ul", {
				className: "relative z-[1] mt-10 space-y-4",
				children: BEATS.map((beat, i) => /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Reveal, {
					delayMs: i * 90,
					variant: "left",
					children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("li", {
						className: "group flex gap-4 border-l-2 border-[rgba(237,230,218,0.12)] py-1 pl-4 transition-colors hover:border-forja-green/50",
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
							className: cn("font-mono-ui shrink-0 text-[11px] tracking-[0.16em]", beat.accent === "flame" ? "text-flame" : "text-brand"),
							children: beat.n
						}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
							className: "font-disp text-lg uppercase tracking-tight text-[#EDE6DA]",
							children: beat.title
						}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
							className: "mt-1 text-sm leading-relaxed text-[rgba(237,230,218,0.48)]",
							children: beat.line
						})] })]
					})
				}, beat.n))
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
				className: "relative z-[1] mt-10 hidden overflow-hidden border border-[rgba(237,230,218,0.12)] bg-[#121110] py-4 sm:block",
				children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
					className: "animate-marquee flex w-max gap-10 whitespace-nowrap px-4",
					children: [...MARQUEE, ...MARQUEE].map((item, i) => /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("span", {
						className: "inline-flex items-center gap-3",
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
							className: "font-serif-i text-xl text-[#EDE6DA]",
							children: item
						}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
							className: i % 2 === 0 ? "text-brand" : "text-flame",
							children: "✦"
						})]
					}, `${item}-${i}`))
				})
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
				className: "login-scanline relative z-[1] mt-8 hidden max-w-sm overflow-hidden rounded-2xl border border-[rgba(237,230,218,0.14)] bg-[#0f0e0d] p-5 lg:block",
				children: [
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
						className: "flex items-center gap-3",
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
							className: "animate-play-pulse flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-forja-green text-[#0B0A0A]",
							children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("svg", {
								viewBox: "0 0 24 24",
								className: "h-5 w-5 fill-current",
								"aria-hidden": true,
								children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("path", { d: "M8 5v14l11-7z" })
							})
						}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
							className: "min-w-0 flex-1",
							children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
								className: "font-mono-ui text-[10px] uppercase tracking-[0.18em] text-forja-green",
								children: "Now playing"
							}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
								className: "font-disp truncate text-lg uppercase tracking-tight",
								children: "Your night"
							})]
						})]
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
						className: "mt-4 h-1 overflow-hidden rounded-full bg-[rgba(237,230,218,0.12)]",
						children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", { className: cn("h-full rounded-full bg-flame", reduced ? "w-2/3" : "animate-stream-progress") })
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
						className: "font-mono-ui mt-3 text-[10px] uppercase tracking-[0.14em] text-[rgba(237,230,218,0.38)]",
						children: "Free · No ads · Player first"
					})
				]
			})
		]
	});
}
function LoginForm() {
	const navigate = useNavigate();
	const { signIn, user, loading, configured } = useAuth();
	const [email, setEmail] = (0, import_react.useState)("");
	const [password, setPassword] = (0, import_react.useState)("");
	const [error, setError] = (0, import_react.useState)(null);
	const [submitting, setSubmitting] = (0, import_react.useState)(false);
	(0, import_react.useEffect)(() => {
		if (!loading && user) navigate({ to: "/account" });
	}, [
		loading,
		user,
		navigate
	]);
	async function onSubmit(e) {
		e.preventDefault();
		setError(null);
		setSubmitting(true);
		const { error: signInError } = await signIn(email.trim(), password);
		setSubmitting(false);
		if (signInError) {
			setError(signInError);
			return;
		}
		navigate({ to: "/account" });
	}
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("section", {
		className: "flex flex-1 items-center justify-center px-[5vw] py-14 lg:py-20",
		children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Reveal, {
			variant: "right",
			className: "w-full max-w-md",
			children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Card, {
				className: "border-[rgba(237,230,218,0.16)] bg-[#121110]/90 shadow-[0_32px_80px_-32px_rgba(0,0,0,0.85)] backdrop-blur-sm",
				children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(CardHeader, {
					className: "space-y-2 pb-2",
					children: [
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
							className: "font-mono-ui text-[10px] uppercase tracking-[0.2em] text-[rgba(237,230,218,0.4)]",
							children: "Welcome back"
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)(CardTitle, {
							className: "font-disp text-3xl font-extrabold uppercase tracking-tight",
							children: "Log in"
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)(CardDescription, {
							className: "text-base leading-relaxed text-[rgba(237,230,218,0.5)]",
							children: "Your player settings, synced. Download stays free — account is optional."
						})
					]
				}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(CardContent, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("form", {
					onSubmit,
					className: "space-y-5",
					children: [
						!configured ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
							className: "text-sm leading-relaxed text-[rgba(237,230,218,0.55)]",
							children: "Web sign-in is not open yet. Download Forja — you can watch without an account."
						}) : null,
						/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
							className: "space-y-2",
							children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Label, {
								htmlFor: "email",
								children: "Email"
							}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Input, {
								id: "email",
								type: "email",
								autoComplete: "email",
								required: configured,
								disabled: !configured,
								value: email,
								onChange: (e) => setEmail(e.target.value),
								placeholder: "you@example.com",
								className: "h-11 border-[rgba(237,230,218,0.16)] bg-[#0B0A0A] disabled:opacity-40"
							})]
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
							className: "space-y-2",
							children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Label, {
								htmlFor: "password",
								children: "Password"
							}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Input, {
								id: "password",
								type: "password",
								autoComplete: "current-password",
								required: configured,
								disabled: !configured,
								value: password,
								onChange: (e) => setPassword(e.target.value),
								className: "h-11 border-[rgba(237,230,218,0.16)] bg-[#0B0A0A] disabled:opacity-40"
							})]
						}),
						error ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
							role: "alert",
							className: "rounded-lg border border-flame/35 bg-flame/10 px-3 py-2.5 text-sm text-[#EDE6DA]",
							children: error === "Sign-in isn't available right now. Download Forja and play without an account." ? "Sign-in is not available right now. Download Forja and play without an account." : error
						}) : null,
						configured ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Button, {
							type: "submit",
							disabled: submitting || loading,
							className: "h-12 w-full rounded-full font-mono-ui text-xs font-bold uppercase tracking-[0.12em]",
							children: submitting ? "Signing in…" : "Sign in"
						}) : /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
							to: "/download",
							"data-hover": "",
							className: "btn-magnet inline-flex h-12 w-full items-center justify-center rounded-full font-mono-ui text-xs font-bold uppercase tracking-[0.12em]",
							children: "Download Forja"
						})
					]
				}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					className: "mt-8 space-y-4 border-t border-[rgba(237,230,218,0.1)] pt-6",
					children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", {
						className: "text-center text-sm text-[rgba(237,230,218,0.45)]",
						children: [
							"No account yet?",
							" ",
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
								to: "/signup",
								className: "text-forja-green hover:text-flame hover:underline",
								children: "Create one"
							})
						]
					}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
						to: "/download",
						className: "font-mono-ui flex items-center justify-center gap-2 text-[11px] uppercase tracking-[0.14em] text-[rgba(237,230,218,0.38)] transition-colors hover:text-[#EDE6DA]",
						children: "Or download and play without signing in →"
					})]
				})] })]
			})
		})
	});
}
function LoginPage() {
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
		className: "film-grain relative min-h-screen bg-[#0B0A0A] text-[#EDE6DA]",
		children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(SiteHeader, { solid: true }), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("main", {
			className: "relative mx-auto grid min-h-screen max-w-[1400px] lg:grid-cols-[1.05fr_0.95fr] lg:pt-[4.5rem]",
			children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(LoginStoryPanel, {}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(LoginForm, {})]
		})]
	});
}
var SplitComponent = LoginPage;
//#endregion
export { SplitComponent as component };
