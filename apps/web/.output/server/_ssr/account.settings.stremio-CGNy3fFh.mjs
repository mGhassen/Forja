import { r as __toESM } from "../_runtime.mjs";
import { u as require_react } from "../_libs/@floating-ui/react-dom+[...].mjs";
import { s as require_jsx_runtime } from "../_libs/@radix-ui/react-arrow+[...].mjs";
import { r as Trash2 } from "../_libs/lucide-react.mjs";
import { t as Button } from "./button-DinaqNdX.mjs";
import { t as Input } from "./input-WJWRaWLf.mjs";
import { c as emptyStremioPayload, i as SYNC_DOMAINS, n as AccountSettingsShell, u as useUserSetting } from "./sync-domains-Djt7WER7.mjs";
import { t as Label } from "./label-1Dfq8Kig.mjs";
import { t as SettingsSection } from "./settings-section-DPl3lks6.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/account.settings.stremio-CGNy3fFh.js
var import_react = /* @__PURE__ */ __toESM(require_react());
var import_jsx_runtime = require_jsx_runtime();
function AccountSettingsStremioPage() {
	const { data, profileId, isLoading, save, isSaving, saveError } = useUserSetting(SYNC_DOMAINS.stremio);
	const [draft, setDraft] = (0, import_react.useState)(emptyStremioPayload());
	const [url, setUrl] = (0, import_react.useState)("");
	const [savedFlash, setSavedFlash] = (0, import_react.useState)(false);
	(0, import_react.useEffect)(() => {
		setDraft(emptyStremioPayload());
	}, [profileId]);
	(0, import_react.useEffect)(() => {
		if (!data) return;
		setDraft({ addons: data.payload.addons ?? [] });
	}, [data]);
	const addAddon = () => {
		const baseUrl = url.trim();
		if (!baseUrl) return;
		if (draft.addons.some((a) => a.baseUrl === baseUrl)) return;
		const row = {
			baseUrl,
			name: baseUrl
		};
		setDraft((prev) => ({ addons: [...prev.addons, row] }));
		setUrl("");
	};
	const removeAddon = (baseUrl) => {
		setDraft((prev) => ({ addons: prev.addons.filter((a) => a.baseUrl !== baseUrl) }));
	};
	const handleSave = async () => {
		await save(draft);
		setSavedFlash(true);
		window.setTimeout(() => setSavedFlash(false), 2500);
	};
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)(AccountSettingsShell, {
		title: "Stremio addons",
		description: "Manifest URLs for Stremio addons. The app installs these on sync - same list as Settings → Sources.",
		footer: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
			className: "flex flex-wrap items-center gap-3",
			children: [
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Button, {
					onClick: () => void handleSave(),
					disabled: isLoading || isSaving,
					children: isSaving ? "Saving…" : "Save changes"
				}),
				savedFlash ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
					className: "text-sm text-forja-green",
					children: "Saved - open Forja to sync."
				}) : null,
				saveError ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
					className: "text-sm text-red-300",
					children: saveError instanceof Error ? saveError.message : "Save failed"
				}) : null
			]
		}),
		children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(SettingsSection, {
			label: "Installed addons",
			description: "Paste a Stremio addon manifest URL ending with /manifest.json.",
			children: [
				draft.addons.length === 0 ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
					className: "text-sm text-forja-muted",
					children: "No addons yet."
				}) : /* @__PURE__ */ (0, import_jsx_runtime.jsx)("ul", {
					className: "divide-y divide-forja-border",
					children: draft.addons.map((addon) => /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("li", {
						className: "flex min-h-[58px] items-center justify-between gap-3 px-0.5 py-3",
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
							className: "min-w-0",
							children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
								className: "font-medium",
								children: addon.name || "Addon"
							}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
								className: "truncate text-sm text-forja-muted",
								children: addon.baseUrl
							})]
						}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Button, {
							type: "button",
							variant: "ghost",
							size: "sm",
							className: "text-red-300 hover:text-red-200",
							onClick: () => removeAddon(addon.baseUrl),
							children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Trash2, { className: "size-4" })
						})]
					}, addon.baseUrl))
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					className: "space-y-2 py-4",
					children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Label, {
						htmlFor: "addon-url",
						children: "Manifest URL"
					}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Input, {
						id: "addon-url",
						placeholder: "https://…/manifest.json",
						value: url,
						onChange: (e) => setUrl(e.target.value)
					})]
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Button, {
					type: "button",
					variant: "secondary",
					onClick: addAddon,
					children: "Add addon"
				})
			]
		})
	});
}
var SplitComponent = AccountSettingsStremioPage;
//#endregion
export { SplitComponent as component };
