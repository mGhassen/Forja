import { a as require_jsx_runtime } from "../_libs/@radix-ui/react-label+[...].mjs";
import { f as Link } from "../_libs/@tanstack/react-router+[...].mjs";
import { r as cn } from "./site-header-D6GWurdS.mjs";
import { a as primaryDownloadsByPlatform, o as startBackgroundDownload, r as SHOWCASE_PLATFORMS, s as useLatestRelease } from "./start-download-CpAgqJjI.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/platform-download-buttons-BHwQV6P1.js
var import_jsx_runtime = require_jsx_runtime();
function DownloadTrigger({ href, className, children, "data-hover": dataHover }) {
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("a", {
		href,
		"data-hover": dataHover,
		className,
		onClick: (e) => {
			e.preventDefault();
			startBackgroundDownload(href);
		},
		children
	});
}
/**
* One download control per platform, wired to the latest GitHub release asset
* (Supabase mirror if synced; otherwise GitHub Releases API).
* Platforms without a file in the latest release fall back to `/download`.
*/
function PlatformDownloadButtons({ variant = "pills", className, emphasize }) {
	const { data, isLoading } = useLatestRelease();
	const byId = primaryDownloadsByPlatform(data?.assets);
	if (variant === "links") return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
		className: cn("flex flex-wrap gap-x-[22px] gap-y-2 font-mono-ui text-xs uppercase tracking-[0.1em]", className),
		children: SHOWCASE_PLATFORMS.map((p) => {
			const asset = byId[p.id];
			const classNames = cn("transition-colors", emphasize === p.id ? "text-brand hover:text-flame" : "text-[rgba(237,230,218,0.42)] hover:text-flame");
			if (asset) return /* @__PURE__ */ (0, import_jsx_runtime.jsx)(DownloadTrigger, {
				href: asset.download_url,
				className: classNames,
				children: p.label
			}, p.id);
			return /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
				to: "/download",
				className: classNames,
				children: p.label
			}, p.id);
		})
	});
	if (variant === "row") return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
		className: cn("flex flex-col gap-2", className),
		children: SHOWCASE_PLATFORMS.map((p) => {
			const asset = byId[p.id];
			const body = /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(import_jsx_runtime.Fragment, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
				className: "font-disp text-lg uppercase tracking-tight sm:text-xl",
				children: p.label
			}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
				className: "font-mono-ui text-[10px] uppercase tracking-[0.14em] text-[rgba(237,230,218,0.4)]",
				children: asset ? "Download" : isLoading ? "…" : "Soon"
			})] });
			const shell = "flex items-center justify-between gap-4 border border-[rgba(237,230,218,0.12)] px-4 py-3 transition-colors hover:border-brand/50 hover:bg-brand/5";
			if (asset) return /* @__PURE__ */ (0, import_jsx_runtime.jsx)(DownloadTrigger, {
				href: asset.download_url,
				"data-hover": "",
				className: shell,
				children: body
			}, p.id);
			return /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
				to: "/download",
				"data-hover": "",
				className: shell,
				children: body
			}, p.id);
		})
	});
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
		className: cn("flex flex-wrap gap-2.5 sm:gap-3", className),
		children: SHOWCASE_PLATFORMS.map((p) => {
			const asset = byId[p.id];
			const classNames = cn("btn-magnet inline-flex min-h-11 flex-1 items-center justify-center rounded-full px-4 py-3 font-mono-ui text-[11px] font-bold uppercase tracking-[0.1em] shadow-[0_0_28px_rgba(28,231,131,0.28)] transition-all will-change-transform sm:min-h-0 sm:flex-none sm:px-7 sm:py-4 sm:text-[13px]", emphasize === p.id && "scale-[1.04] shadow-[0_0_40px_rgba(28,231,131,0.45)]");
			if (asset) return /* @__PURE__ */ (0, import_jsx_runtime.jsx)(DownloadTrigger, {
				href: asset.download_url,
				"data-hover": "",
				className: classNames,
				children: p.label
			}, p.id);
			return /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
				to: "/download",
				"data-hover": "",
				className: classNames,
				"aria-disabled": !isLoading,
				children: p.label
			}, p.id);
		})
	});
}
//#endregion
export { PlatformDownloadButtons as t };
