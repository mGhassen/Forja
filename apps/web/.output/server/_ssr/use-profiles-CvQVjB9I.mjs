import { r as __toESM } from "../_runtime.mjs";
import { u as require_react } from "../_libs/@floating-ui/react-dom+[...].mjs";
import { s as require_jsx_runtime } from "../_libs/@radix-ui/react-arrow+[...].mjs";
import { a as useAuth, i as supabaseConfigured, n as cn, r as supabase } from "./utils-BshMKIch.mjs";
import { i as useQueryClient, n as useQuery, t as useMutation } from "../_libs/tanstack__react-query.mjs";
import { d as Pencil } from "../_libs/lucide-react.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/use-profiles-CvQVjB9I.js
var import_react = /* @__PURE__ */ __toESM(require_react());
var import_jsx_runtime = require_jsx_runtime();
var PROFILE_AVATAR_CATEGORIES = [
	{
		key: "characters",
		label: "Characters",
		avatars: [
			{
				key: "forge",
				label: "Forge",
				colors: [
					"#1b1b1b",
					"#1ce783",
					"#0a2d21"
				]
			},
			{
				key: "flame",
				label: "Flame",
				colors: [
					"#ff4d1c",
					"#ffd1a8",
					"#3a130a"
				]
			},
			{
				key: "mint",
				label: "Mint",
				colors: [
					"#1ce783",
					"#f5fff9",
					"#0c3b2a"
				]
			},
			{
				key: "captain",
				label: "Captain",
				colors: [
					"#123a68",
					"#f4c7a1",
					"#facc15"
				]
			},
			{
				key: "rebel",
				label: "Rebel",
				colors: [
					"#9f1239",
					"#ffd2b3",
					"#1f1020"
				]
			},
			{
				key: "ninja",
				label: "Ninja",
				colors: [
					"#111827",
					"#c084fc",
					"#05070c"
				]
			},
			{
				key: "royal",
				label: "Royal",
				colors: [
					"#6d28d9",
					"#f6d0ad",
					"#facc15"
				]
			},
			{
				key: "racer",
				label: "Racer",
				colors: [
					"#dc2626",
					"#f8d5ba",
					"#111827"
				]
			}
		]
	},
	{
		key: "creatures",
		label: "Creatures",
		avatars: [
			{
				key: "night",
				label: "Night Cat",
				colors: [
					"#10172c",
					"#64748b",
					"#1ce783"
				]
			},
			{
				key: "panda",
				label: "Panda",
				colors: [
					"#f8fafc",
					"#111827",
					"#fb7185"
				]
			},
			{
				key: "fox",
				label: "Fox",
				colors: [
					"#ea580c",
					"#fff7ed",
					"#431407"
				]
			},
			{
				key: "owl",
				label: "Owl",
				colors: [
					"#92400e",
					"#fde68a",
					"#1e3a8a"
				]
			},
			{
				key: "shark",
				label: "Shark",
				colors: [
					"#0369a1",
					"#bae6fd",
					"#172554"
				]
			},
			{
				key: "dragon",
				label: "Dragon",
				colors: [
					"#166534",
					"#86efac",
					"#facc15"
				]
			},
			{
				key: "bunny",
				label: "Bunny",
				colors: [
					"#f9a8d4",
					"#fff1f2",
					"#831843"
				]
			},
			{
				key: "yeti",
				label: "Yeti",
				colors: [
					"#dbeafe",
					"#f8fafc",
					"#1e40af"
				]
			}
		]
	},
	{
		key: "space",
		label: "Space",
		avatars: [
			{
				key: "orbit",
				label: "Orbit",
				colors: [
					"#3978d5",
					"#dcecff",
					"#152b4d"
				]
			},
			{
				key: "comet",
				label: "Comet",
				colors: [
					"#312e81",
					"#f97316",
					"#fef3c7"
				]
			},
			{
				key: "nova",
				label: "Nova",
				colors: [
					"#701a75",
					"#f0abfc",
					"#facc15"
				]
			},
			{
				key: "alien",
				label: "Alien",
				colors: [
					"#052e16",
					"#4ade80",
					"#111827"
				]
			},
			{
				key: "rover",
				label: "Rover",
				colors: [
					"#7c2d12",
					"#fed7aa",
					"#292524"
				]
			},
			{
				key: "lunar",
				label: "Lunar",
				colors: [
					"#1e293b",
					"#e2e8f0",
					"#38bdf8"
				]
			},
			{
				key: "solar",
				label: "Solar",
				colors: [
					"#9a3412",
					"#facc15",
					"#fff7ed"
				]
			},
			{
				key: "void",
				label: "Void",
				colors: [
					"#020617",
					"#7c3aed",
					"#22d3ee"
				]
			}
		]
	},
	{
		key: "retro",
		label: "Retro",
		avatars: [
			{
				key: "pixel",
				label: "Pixel",
				colors: [
					"#7c3aed",
					"#ded7ff",
					"#1ce783"
				]
			},
			{
				key: "arcade",
				label: "Arcade",
				colors: [
					"#172554",
					"#22d3ee",
					"#f472b6"
				]
			},
			{
				key: "cassette",
				label: "Cassette",
				colors: [
					"#f59e0b",
					"#292524",
					"#fef3c7"
				]
			},
			{
				key: "glitch",
				label: "Glitch",
				colors: [
					"#111827",
					"#ef4444",
					"#22d3ee"
				]
			},
			{
				key: "neon",
				label: "Neon",
				colors: [
					"#4a044e",
					"#f0abfc",
					"#a3e635"
				]
			},
			{
				key: "synth",
				label: "Synth",
				colors: [
					"#312e81",
					"#fb7185",
					"#67e8f9"
				]
			}
		]
	}
];
var PROFILE_AVATARS = PROFILE_AVATAR_CATEGORIES.flatMap((category) => category.avatars);
function normalizeAvatarKey(value) {
	return PROFILE_AVATARS.some((avatar) => avatar.key === value) ? value : "forge";
}
function ProfileAvatar({ avatarKey, name, className, editing = false }) {
	const key = normalizeAvatarKey(avatarKey);
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("span", {
		role: "img",
		"aria-label": `${name} avatar`,
		className: cn("relative block aspect-square overflow-hidden rounded-[4px] bg-[#171717]", className),
		children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(AvatarArtwork, { avatarKey: key }), editing ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
			className: "absolute inset-0 flex items-center justify-center bg-black/55",
			children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
				className: "flex size-11 items-center justify-center rounded-full border-2 border-white bg-black/45",
				children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Pencil, { className: "size-5 text-white" })
			})
		}) : null]
	});
}
function AvatarArtwork({ avatarKey }) {
	if (!(avatarKey === "forge" || avatarKey === "flame" || avatarKey === "orbit" || avatarKey === "pixel" || avatarKey === "night" || avatarKey === "mint")) {
		const index = PROFILE_AVATARS.findIndex((avatar) => avatar.key === avatarKey);
		const avatar = PROFILE_AVATARS[index];
		return /* @__PURE__ */ (0, import_jsx_runtime.jsx)(GeneratedAvatarArtwork, {
			colors: avatar.colors,
			category: Math.floor(index / 8),
			variant: index % 8
		});
	}
	switch (avatarKey) {
		case "flame": return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("svg", {
			viewBox: "0 0 160 160",
			className: "size-full",
			"aria-hidden": true,
			children: [
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("rect", {
					width: "160",
					height: "160",
					fill: "#ff4d1c"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("path", {
					d: "M0 128 30 95 58 116 88 84 121 112 160 76v84H0Z",
					fill: "#24100b"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("circle", {
					cx: "80",
					cy: "77",
					r: "44",
					fill: "#ffd1a8"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("path", {
					d: "M42 61c8-34 26-49 55-47-5 9-4 17 3 24 9-12 20-17 33-15-5 12-14 25-27 38Z",
					fill: "#3a130a"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("circle", {
					cx: "64",
					cy: "77",
					r: "5",
					fill: "#24100b"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("circle", {
					cx: "98",
					cy: "77",
					r: "5",
					fill: "#24100b"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("path", {
					d: "M62 99c13 10 26 10 39 0",
					fill: "none",
					stroke: "#24100b",
					strokeWidth: "6",
					strokeLinecap: "round"
				})
			]
		});
		case "orbit": return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("svg", {
			viewBox: "0 0 160 160",
			className: "size-full",
			"aria-hidden": true,
			children: [
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("rect", {
					width: "160",
					height: "160",
					fill: "#3978d5"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("circle", {
					cx: "25",
					cy: "28",
					r: "3",
					fill: "#fff"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("circle", {
					cx: "134",
					cy: "38",
					r: "4",
					fill: "#fff"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("circle", {
					cx: "116",
					cy: "16",
					r: "2",
					fill: "#fff"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("circle", {
					cx: "80",
					cy: "82",
					r: "58",
					fill: "#dcecff"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("circle", {
					cx: "80",
					cy: "78",
					r: "43",
					fill: "#152b4d"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("circle", {
					cx: "80",
					cy: "82",
					r: "31",
					fill: "#b7dcff"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("circle", {
					cx: "68",
					cy: "78",
					r: "4",
					fill: "#152b4d"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("circle", {
					cx: "94",
					cy: "78",
					r: "4",
					fill: "#152b4d"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("path", {
					d: "M67 96c9 6 18 6 27 0",
					fill: "none",
					stroke: "#152b4d",
					strokeWidth: "5",
					strokeLinecap: "round"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("path", {
					d: "M33 137c28-19 65-19 94 0v23H33Z",
					fill: "#e9f4ff"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("circle", {
					cx: "126",
					cy: "112",
					r: "6",
					fill: "#1ce783"
				})
			]
		});
		case "pixel": return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("svg", {
			viewBox: "0 0 160 160",
			className: "size-full",
			"aria-hidden": true,
			children: [
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("rect", {
					width: "160",
					height: "160",
					fill: "#7c3aed"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("rect", {
					x: "29",
					y: "32",
					width: "102",
					height: "96",
					rx: "9",
					fill: "#ded7ff"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("rect", {
					x: "42",
					y: "48",
					width: "76",
					height: "51",
					fill: "#211747"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("rect", {
					x: "53",
					y: "62",
					width: "13",
					height: "13",
					fill: "#1ce783"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("rect", {
					x: "94",
					y: "62",
					width: "13",
					height: "13",
					fill: "#1ce783"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("rect", {
					x: "62",
					y: "84",
					width: "36",
					height: "6",
					fill: "#c084fc"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("rect", {
					x: "70",
					y: "18",
					width: "20",
					height: "16",
					fill: "#ded7ff"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("rect", {
					x: "76",
					y: "7",
					width: "8",
					height: "15",
					fill: "#ded7ff"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("rect", {
					x: "43",
					y: "111",
					width: "18",
					height: "8",
					fill: "#7c3aed"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("rect", {
					x: "70",
					y: "111",
					width: "18",
					height: "8",
					fill: "#7c3aed"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("rect", {
					x: "97",
					y: "111",
					width: "18",
					height: "8",
					fill: "#7c3aed"
				})
			]
		});
		case "night": return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("svg", {
			viewBox: "0 0 160 160",
			className: "size-full",
			"aria-hidden": true,
			children: [
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("rect", {
					width: "160",
					height: "160",
					fill: "#10172c"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("circle", {
					cx: "126",
					cy: "29",
					r: "18",
					fill: "#facc15"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("circle", {
					cx: "136",
					cy: "22",
					r: "18",
					fill: "#10172c"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("path", {
					d: "m42 62 13-29 24 22 25-22 14 30v68H42Z",
					fill: "#64748b"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("path", {
					d: "m51 56 7-14 11 11ZM107 56l-7-14-11 11Z",
					fill: "#fda4af"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("ellipse", {
					cx: "65",
					cy: "83",
					rx: "8",
					ry: "10",
					fill: "#1ce783"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("ellipse", {
					cx: "96",
					cy: "83",
					rx: "8",
					ry: "10",
					fill: "#1ce783"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("path", {
					d: "m75 101 6 5 6-5",
					fill: "#fda4af"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("path", {
					d: "M53 107h18M90 107h18",
					stroke: "#e2e8f0",
					strokeWidth: "3",
					strokeLinecap: "round"
				})
			]
		});
		case "mint": return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("svg", {
			viewBox: "0 0 160 160",
			className: "size-full",
			"aria-hidden": true,
			children: [
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("rect", {
					width: "160",
					height: "160",
					fill: "#1ce783"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("path", {
					d: "M18 160c8-61 31-99 62-99s55 38 63 99Z",
					fill: "#0c3b2a"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("circle", {
					cx: "56",
					cy: "69",
					r: "22",
					fill: "#f5fff9"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("circle", {
					cx: "104",
					cy: "69",
					r: "22",
					fill: "#f5fff9"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("circle", {
					cx: "60",
					cy: "72",
					r: "9",
					fill: "#0c3b2a"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("circle", {
					cx: "100",
					cy: "72",
					r: "9",
					fill: "#0c3b2a"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("path", {
					d: "M57 113c15 14 31 14 46 0",
					fill: "none",
					stroke: "#f5fff9",
					strokeWidth: "7",
					strokeLinecap: "round"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("path", {
					d: "M35 42 17 21M125 42l18-21",
					stroke: "#0c3b2a",
					strokeWidth: "10",
					strokeLinecap: "round"
				})
			]
		});
		default: return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("svg", {
			viewBox: "0 0 160 160",
			className: "size-full",
			"aria-hidden": true,
			children: [
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("rect", {
					width: "160",
					height: "160",
					fill: "#1b1b1b"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("circle", {
					cx: "80",
					cy: "77",
					r: "49",
					fill: "#1ce783"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("path", {
					d: "M32 63c7-33 25-49 52-49 25 0 42 14 49 41L103 43 82 57 61 43Z",
					fill: "#0a2d21"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("rect", {
					x: "43",
					y: "66",
					width: "31",
					height: "23",
					rx: "5",
					fill: "#111"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("rect", {
					x: "86",
					y: "66",
					width: "31",
					height: "23",
					rx: "5",
					fill: "#111"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("rect", {
					x: "74",
					y: "73",
					width: "12",
					height: "5",
					fill: "#111"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("circle", {
					cx: "59",
					cy: "77",
					r: "4",
					fill: "#1ce783"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("circle", {
					cx: "101",
					cy: "77",
					r: "4",
					fill: "#1ce783"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("path", {
					d: "M58 104c14 11 29 11 44 0",
					fill: "none",
					stroke: "#0a2d21",
					strokeWidth: "7",
					strokeLinecap: "round"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("path", {
					d: "M29 160c8-30 25-45 51-45s44 15 52 45Z",
					fill: "#124d39"
				})
			]
		});
	}
}
function GeneratedAvatarArtwork({ colors, category, variant }) {
	const [background, primary, accent] = colors;
	if (category === 0) return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("svg", {
		viewBox: "0 0 160 160",
		className: "size-full",
		"aria-hidden": true,
		children: [
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("rect", {
				width: "160",
				height: "160",
				fill: background
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("path", {
				d: "M22 160c8-34 28-51 58-51s50 17 58 51Z",
				fill: accent
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("circle", {
				cx: "80",
				cy: "76",
				r: "45",
				fill: primary
			}),
			variant % 2 === 0 ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("path", {
				d: "M38 62c5-31 21-47 48-47 24 0 39 13 45 40L105 42 82 55 58 42Z",
				fill: accent
			}) : /* @__PURE__ */ (0, import_jsx_runtime.jsx)("path", {
				d: "M36 61 48 24l31 12 29-13 17 38Z",
				fill: accent
			}),
			variant === 5 ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("path", {
				d: "M39 70h82v28c-25 16-54 16-82 0Z",
				fill: accent
			}) : /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(import_jsx_runtime.Fragment, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("circle", {
				cx: "64",
				cy: "77",
				r: "5",
				fill: accent
			}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("circle", {
				cx: "97",
				cy: "77",
				r: "5",
				fill: accent
			})] }),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("path", {
				d: "M61 99c13 10 26 10 39 0",
				fill: "none",
				stroke: accent,
				strokeWidth: "6",
				strokeLinecap: "round"
			}),
			variant === 3 ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("path", {
				d: "m55 35 9-23 16 18 17-18 10 23Z",
				fill: "#facc15"
			}) : null
		]
	});
	if (category === 1) return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("svg", {
		viewBox: "0 0 160 160",
		className: "size-full",
		"aria-hidden": true,
		children: [
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("rect", {
				width: "160",
				height: "160",
				fill: background
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("path", {
				d: "M28 67 38 23l32 29M132 67l-10-44-32 29",
				fill: primary,
				stroke: accent,
				strokeWidth: "8",
				strokeLinejoin: "round"
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("ellipse", {
				cx: "80",
				cy: "89",
				rx: "55",
				ry: "58",
				fill: primary
			}),
			variant === 4 ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("path", {
				d: "M21 77h118l-18 26H39Z",
				fill: accent
			}) : null,
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("ellipse", {
				cx: "59",
				cy: "81",
				rx: "9",
				ry: "11",
				fill: accent
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("ellipse", {
				cx: "101",
				cy: "81",
				rx: "9",
				ry: "11",
				fill: accent
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("ellipse", {
				cx: "80",
				cy: "106",
				rx: "17",
				ry: "12",
				fill: background
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("circle", {
				cx: "80",
				cy: "102",
				r: "5",
				fill: accent
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("path", {
				d: "M65 119c10 7 20 7 30 0",
				fill: "none",
				stroke: accent,
				strokeWidth: "5",
				strokeLinecap: "round"
			}),
			variant === 5 ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("path", {
				d: "m80 30 9-20 8 21M58 38 48 19",
				stroke: "#facc15",
				strokeWidth: "7",
				strokeLinecap: "round"
			}) : null
		]
	});
	if (category === 2) return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("svg", {
		viewBox: "0 0 160 160",
		className: "size-full",
		"aria-hidden": true,
		children: [
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("rect", {
				width: "160",
				height: "160",
				fill: background
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("circle", {
				cx: "24",
				cy: "27",
				r: "3",
				fill: primary
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("circle", {
				cx: "133",
				cy: "38",
				r: "4",
				fill: accent
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("circle", {
				cx: "119",
				cy: "17",
				r: "2",
				fill: primary
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("circle", {
				cx: "80",
				cy: "80",
				r: "58",
				fill: primary
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("circle", {
				cx: "80",
				cy: "78",
				r: "43",
				fill: accent
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("circle", {
				cx: "80",
				cy: "82",
				r: "31",
				fill: background
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("circle", {
				cx: "67",
				cy: "79",
				r: "5",
				fill: primary
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("circle", {
				cx: "94",
				cy: "79",
				r: "5",
				fill: primary
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("path", {
				d: "M66 98c10 7 20 7 29 0",
				fill: "none",
				stroke: primary,
				strokeWidth: "5",
				strokeLinecap: "round"
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("path", {
				d: "M31 140c29-20 68-20 98 0v20H31Z",
				fill: accent
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("circle", {
				cx: 120 - variant * 2,
				cy: "119",
				r: "6",
				fill: primary
			})
		]
	});
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("svg", {
		viewBox: "0 0 160 160",
		className: "size-full",
		"aria-hidden": true,
		children: [
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("rect", {
				width: "160",
				height: "160",
				fill: background
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("rect", {
				x: "27",
				y: "31",
				width: "106",
				height: "98",
				rx: variant % 2 === 0 ? 8 : 0,
				fill: primary
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("rect", {
				x: "40",
				y: "47",
				width: "80",
				height: "54",
				fill: accent
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("rect", {
				x: "52",
				y: "63",
				width: "14",
				height: "14",
				fill: background
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("rect", {
				x: "94",
				y: "63",
				width: "14",
				height: "14",
				fill: background
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("rect", {
				x: 58 + variant * 2,
				y: "86",
				width: 44 - variant * 2,
				height: "7",
				fill: primary
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("rect", {
				x: "69",
				y: "17",
				width: "22",
				height: "16",
				fill: primary
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("rect", {
				x: "76",
				y: "7",
				width: "8",
				height: "12",
				fill: accent
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("rect", {
				x: "42",
				y: "112",
				width: "19",
				height: "8",
				fill: background
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("rect", {
				x: "70",
				y: "112",
				width: "19",
				height: "8",
				fill: background
			}),
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("rect", {
				x: "98",
				y: "112",
				width: "19",
				height: "8",
				fill: background
			})
		]
	});
}
var PROFILE_COLORS = [
	"#1ce783",
	"#ff4d1c",
	"#5aa9ff",
	"#c084fc",
	"#facc15",
	"#fb7185"
];
var ProfilesContext = (0, import_react.createContext)(null);
function storageKey(userId) {
	return `forja.active-profile.${userId}`;
}
function ProfilesProvider({ children }) {
	const { user } = useAuth();
	const queryClient = useQueryClient();
	const [activeProfileId, setActiveProfileId] = (0, import_react.useState)(null);
	const profilesQuery = useQuery({
		queryKey: ["profiles", user?.id],
		enabled: Boolean(user?.id && supabaseConfigured),
		queryFn: async () => {
			const { data, error } = await supabase.from("profiles").select("*").eq("user_id", user.id).order("created_at");
			if (error) throw error;
			return data ?? [];
		}
	});
	const profiles = profilesQuery.data ?? [];
	(0, import_react.useEffect)(() => {
		if (!user) {
			setActiveProfileId(null);
			return;
		}
		if (profiles.length === 0) return;
		const saved = window.localStorage.getItem(storageKey(user.id));
		const next = saved && profiles.some((profile) => profile.id === saved) && saved || profiles[0].id;
		setActiveProfileId(next);
		window.localStorage.setItem(storageKey(user.id), next);
	}, [profiles, user]);
	const selectProfile = (profileId) => {
		if (!user || !profiles.some((profile) => profile.id === profileId)) return;
		setActiveProfileId(profileId);
		window.localStorage.setItem(storageKey(user.id), profileId);
	};
	const createMutation = useMutation({
		mutationFn: async ({ name, avatarKey }) => {
			const cleanName = name.trim();
			if (!user || !cleanName) throw new Error("Enter a profile name");
			const color = PROFILE_COLORS[profiles.length % PROFILE_COLORS.length];
			const avatar_key = avatarKey ?? PROFILE_AVATARS[profiles.length % PROFILE_AVATARS.length].key;
			const { data, error } = await supabase.from("profiles").insert({
				user_id: user.id,
				name: cleanName,
				color,
				avatar_key
			}).select("*").single();
			if (error) throw error;
			return data;
		},
		onSuccess: (profile) => {
			queryClient.invalidateQueries({ queryKey: ["profiles", user?.id] });
			setActiveProfileId(profile.id);
			if (user) window.localStorage.setItem(storageKey(user.id), profile.id);
		}
	});
	const renameMutation = useMutation({
		mutationFn: async ({ profileId, name }) => {
			const cleanName = name.trim();
			if (!user || !cleanName) throw new Error("Enter a profile name");
			const { error } = await supabase.from("profiles").update({
				name: cleanName,
				updated_at: (/* @__PURE__ */ new Date()).toISOString()
			}).eq("id", profileId).eq("user_id", user.id);
			if (error) throw error;
		},
		onSuccess: () => {
			queryClient.invalidateQueries({ queryKey: ["profiles", user?.id] });
		}
	});
	const avatarMutation = useMutation({
		mutationFn: async ({ profileId, avatarKey }) => {
			if (!user) return;
			const { error } = await supabase.from("profiles").update({
				avatar_key: avatarKey,
				updated_at: (/* @__PURE__ */ new Date()).toISOString()
			}).eq("id", profileId).eq("user_id", user.id);
			if (error) throw error;
		},
		onSuccess: () => {
			queryClient.invalidateQueries({ queryKey: ["profiles", user?.id] });
		}
	});
	const deleteMutation = useMutation({
		mutationFn: async (profileId) => {
			if (!user) return;
			if (profiles.length <= 1) throw new Error("Every account needs one profile");
			const { error } = await supabase.from("profiles").delete().eq("id", profileId).eq("user_id", user.id);
			if (error) throw error;
		},
		onSuccess: (_, deletedId) => {
			if (activeProfileId === deletedId && user) {
				const next = profiles.find((profile) => profile.id !== deletedId);
				setActiveProfileId(next?.id ?? null);
				if (next) window.localStorage.setItem(storageKey(user.id), next.id);
			}
			queryClient.invalidateQueries({ queryKey: ["profiles", user?.id] });
		}
	});
	const activeProfile = profiles.find((profile) => profile.id === activeProfileId) ?? profiles[0] ?? null;
	const value = (0, import_react.useMemo)(() => ({
		profiles,
		activeProfile,
		loading: profilesQuery.isLoading,
		error: profilesQuery.error instanceof Error ? profilesQuery.error : profilesQuery.error ? /* @__PURE__ */ new Error("Failed to load profiles") : null,
		selectProfile,
		createProfile: async (name, avatarKey) => {
			return createMutation.mutateAsync({
				name,
				avatarKey
			});
		},
		renameProfile: async (profileId, name) => {
			await renameMutation.mutateAsync({
				profileId,
				name
			});
		},
		updateProfileAvatar: async (profileId, avatarKey) => {
			await avatarMutation.mutateAsync({
				profileId,
				avatarKey
			});
		},
		deleteProfile: deleteMutation.mutateAsync,
		creating: createMutation.isPending
	}), [
		profiles,
		activeProfile,
		profilesQuery.isLoading,
		profilesQuery.error,
		createMutation.mutateAsync,
		createMutation.isPending,
		renameMutation.mutateAsync,
		avatarMutation.mutateAsync,
		deleteMutation.mutateAsync
	]);
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)(ProfilesContext.Provider, {
		value,
		children
	});
}
function useProfiles() {
	const context = (0, import_react.useContext)(ProfilesContext);
	if (!context) throw new Error("useProfiles must be used within ProfilesProvider");
	return context;
}
//#endregion
export { normalizeAvatarKey as a, ProfilesProvider as i, PROFILE_AVATAR_CATEGORIES as n, useProfiles as o, ProfileAvatar as r, PROFILE_AVATARS as t };
