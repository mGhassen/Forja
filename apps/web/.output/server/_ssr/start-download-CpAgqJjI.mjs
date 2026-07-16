import { r as __toESM } from "../_runtime.mjs";
import { n as require_react } from "../_libs/@radix-ui/react-compose-refs+[...].mjs";
import { a as require_jsx_runtime } from "../_libs/@radix-ui/react-label+[...].mjs";
import { n as supabase, r as supabaseConfigured } from "./use-auth-BFtWcVvU.mjs";
import { t as useQuery } from "../_libs/tanstack__react-query.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/start-download-CpAgqJjI.js
var import_react = /* @__PURE__ */ __toESM(require_react());
var import_jsx_runtime = require_jsx_runtime();
/** Difference-blend custom cursor (fine pointer + motion OK only). */
function CustomCursor() {
	const dotRef = (0, import_react.useRef)(null);
	const ringRef = (0, import_react.useRef)(null);
	(0, import_react.useEffect)(() => {
		const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
		if (!window.matchMedia("(hover: hover) and (pointer: fine)").matches || reduced) return;
		document.body.classList.add("cursor-on");
		const dot = dotRef.current;
		const ring = ringRef.current;
		if (!dot || !ring) return;
		let mx = window.innerWidth / 2;
		let my = window.innerHeight / 2;
		let rx = mx;
		let ry = my;
		let raf = 0;
		const onMove = (e) => {
			mx = e.clientX;
			my = e.clientY;
			dot.style.left = `${mx}px`;
			dot.style.top = `${my}px`;
		};
		const loop = () => {
			rx += (mx - rx) * .18;
			ry += (my - ry) * .18;
			ring.style.left = `${rx}px`;
			ring.style.top = `${ry}px`;
			raf = requestAnimationFrame(loop);
		};
		const onEnter = () => ring.classList.add("big");
		const onLeave = () => ring.classList.remove("big");
		window.addEventListener("mousemove", onMove);
		raf = requestAnimationFrame(loop);
		const bindHoverables = () => {
			document.querySelectorAll("a, button, [data-hover]").forEach((el) => {
				el.addEventListener("mouseenter", onEnter);
				el.addEventListener("mouseleave", onLeave);
			});
		};
		bindHoverables();
		const mo = new MutationObserver(bindHoverables);
		mo.observe(document.body, {
			childList: true,
			subtree: true
		});
		return () => {
			document.body.classList.remove("cursor-on");
			window.removeEventListener("mousemove", onMove);
			cancelAnimationFrame(raf);
			mo.disconnect();
			document.querySelectorAll("a, button, [data-hover]").forEach((el) => {
				el.removeEventListener("mouseenter", onEnter);
				el.removeEventListener("mouseleave", onLeave);
			});
		};
	}, []);
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(import_jsx_runtime.Fragment, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
		ref: dotRef,
		className: "cur-dot",
		"aria-hidden": true
	}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
		ref: ringRef,
		className: "cur-ring",
		"aria-hidden": true
	})] });
}
function Reveal({ children, className = "", delayMs = 0 }) {
	const ref = (0, import_react.useRef)(null);
	(0, import_react.useEffect)(() => {
		const el = ref.current;
		if (!el) return;
		const observer = new IntersectionObserver(([entry]) => {
			if (entry.isIntersecting) {
				el.classList.add("is-visible");
				observer.unobserve(el);
			}
		}, {
			threshold: .16,
			rootMargin: "0px 0px -8% 0px"
		});
		observer.observe(el);
		return () => observer.disconnect();
	}, []);
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
		ref,
		className: `reveal ${className}`,
		style: delayMs ? { transitionDelay: `${delayMs}ms` } : void 0,
		children
	});
}
/** Platforms Forja ships today. */
var SHOWCASE_PLATFORMS = [
	{
		id: "windows",
		label: "Windows",
		tagline: "Film night on your PC — same calm Forja as everywhere else.",
		format: "For your PC",
		match: ["windows"]
	},
	{
		id: "macos",
		label: "macOS",
		tagline: "Laptop on the couch or Mac on the desk — press play and settle in.",
		format: "For your Mac",
		match: ["macos"]
	},
	{
		id: "linux",
		label: "Linux",
		tagline: "Same movies, series, and live nights — no fuss.",
		format: "For Linux",
		match: ["linux"]
	},
	{
		id: "android_tv",
		label: "Android TV",
		tagline: "The living-room screen. Remote in hand. Lights down.",
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
//#endregion
export { primaryDownloadsByPlatform as a, assetsForPlatform as i, Reveal as n, startBackgroundDownload as o, SHOWCASE_PLATFORMS as r, useLatestRelease as s, CustomCursor as t };
