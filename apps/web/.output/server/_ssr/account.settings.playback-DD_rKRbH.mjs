import { r as __toESM } from "../_runtime.mjs";
import { n as require_react } from "../_libs/@radix-ui/react-compose-refs+[...].mjs";
import { a as require_jsx_runtime } from "../_libs/@radix-ui/react-label+[...].mjs";
import { r as cn } from "./site-header-CQxqjJmj.mjs";
import { a as CardHeader, i as CardDescription, n as Card, o as CardTitle, r as CardContent, t as Button } from "./card-BLl6aleQ.mjs";
import { a as SYNC_DOMAINS, d as useUserSetting, n as AccountSettingsShell, r as MAX_PLAYBACK_HEIGHT_OPTIONS, s as emptyPreferencesPayload, t as AUDIO_LANGUAGE_OPTIONS } from "./sync-domains-C0TgAES7.mjs";
import { t as Label } from "./label-D3h4O29f.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/account.settings.playback-DD_rKRbH.js
var import_react = /* @__PURE__ */ __toESM(require_react());
var import_jsx_runtime = require_jsx_runtime();
function SettingsToggle({ label, description, checked, onChange, disabled }) {
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("label", {
		className: cn("flex cursor-pointer items-start justify-between gap-4 rounded-lg border border-forja-border bg-forja-surface/60 px-4 py-3", disabled && "cursor-not-allowed opacity-60"),
		children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("span", {
			className: "min-w-0",
			children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
				className: "block text-sm font-medium",
				children: label
			}), description ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
				className: "mt-1 block text-sm text-forja-muted",
				children: description
			}) : null]
		}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("input", {
			type: "checkbox",
			className: "mt-1 size-4 shrink-0 accent-forja-green",
			checked,
			disabled,
			onChange: (e) => onChange(e.target.checked)
		})]
	});
}
function AccountSettingsPlaybackPage() {
	const { data, isLoading, save, isSaving, saveError } = useUserSetting(SYNC_DOMAINS.preferences);
	const [draft, setDraft] = (0, import_react.useState)(emptyPreferencesPayload());
	const [savedFlash, setSavedFlash] = (0, import_react.useState)(false);
	(0, import_react.useEffect)(() => {
		if (!data) return;
		setDraft({
			...emptyPreferencesPayload(),
			...data.payload
		});
	}, [data]);
	const setBool = (key, value) => {
		setDraft((prev) => ({
			...prev,
			[key]: value
		}));
	};
	const handleSave = async () => {
		await save(draft);
		setSavedFlash(true);
		window.setTimeout(() => setSavedFlash(false), 2500);
	};
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(AccountSettingsShell, {
		title: "Playback",
		description: "Cross-device playback preferences. Built-in engine and per-device player choices stay in the app.",
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
					children: "Saved — open Forja to sync."
				}) : null,
				saveError ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
					className: "text-sm text-red-300",
					children: saveError instanceof Error ? saveError.message : "Save failed"
				}) : null
			]
		}),
		children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Card, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(CardHeader, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(CardTitle, { children: "Play sources" }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(CardDescription, { children: "Which backends Forja tries when you hit Play." })] }), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(CardContent, {
			className: "space-y-3",
			children: [
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)(SettingsToggle, {
					label: "Direct torrent",
					description: "Indexers and Nuvio scrapers from Sources.",
					checked: draft.play_source_torrent_enabled ?? true,
					onChange: (v) => setBool("play_source_torrent_enabled", v),
					disabled: isLoading
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)(SettingsToggle, {
					label: "Stremio",
					description: "Installed Stremio addons.",
					checked: draft.play_source_stremio_enabled ?? true,
					onChange: (v) => setBool("play_source_stremio_enabled", v),
					disabled: isLoading
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)(SettingsToggle, {
					label: "Web streaming",
					description: "Embed and extractor providers.",
					checked: draft.play_source_webstreaming_enabled ?? true,
					onChange: (v) => setBool("play_source_webstreaming_enabled", v),
					disabled: isLoading
				})
			]
		})] }), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Card, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(CardHeader, { children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(CardTitle, { children: "Player behavior" }) }), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(CardContent, {
			className: "space-y-3",
			children: [
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)(SettingsToggle, {
					label: "Auto next episode",
					checked: draft.auto_next_episode ?? true,
					onChange: (v) => setBool("auto_next_episode", v),
					disabled: isLoading
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)(SettingsToggle, {
					label: "Auto skip intro",
					description: "Uses IntroDB when available.",
					checked: draft.auto_skip_intro ?? false,
					onChange: (v) => setBool("auto_skip_intro", v),
					disabled: isLoading
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)(SettingsToggle, {
					label: "IPTV programme guide",
					description: "Load EPG in the IPTV player.",
					checked: draft.iptv_epg_enabled ?? true,
					onChange: (v) => setBool("iptv_epg_enabled", v),
					disabled: isLoading
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)(SettingsToggle, {
					label: "Avoid unsupported audio",
					description: "Skip Atmos, TrueHD, and 7.1 when possible.",
					checked: draft.avoid_unsupported_audio ?? true,
					onChange: (v) => setBool("avoid_unsupported_audio", v),
					disabled: isLoading
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					className: "space-y-2 pt-2",
					children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Label, {
						htmlFor: "audio-lang",
						children: "Preferred audio language"
					}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("select", {
						id: "audio-lang",
						className: "flex h-10 w-full rounded-md border border-forja-border bg-forja-surface px-3 text-sm",
						value: draft.preferred_audio_lang ?? "None",
						disabled: isLoading,
						onChange: (e) => setDraft((prev) => ({
							...prev,
							preferred_audio_lang: e.target.value
						})),
						children: AUDIO_LANGUAGE_OPTIONS.map((lang) => /* @__PURE__ */ (0, import_jsx_runtime.jsx)("option", {
							value: lang,
							children: lang
						}, lang))
					})]
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					className: "space-y-2",
					children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Label, {
						htmlFor: "max-quality",
						children: "Max stream quality"
					}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("select", {
						id: "max-quality",
						className: "flex h-10 w-full rounded-md border border-forja-border bg-forja-surface px-3 text-sm",
						value: String(draft.max_playback_height ?? 0),
						disabled: isLoading,
						onChange: (e) => setDraft((prev) => ({
							...prev,
							max_playback_height: Number(e.target.value)
						})),
						children: MAX_PLAYBACK_HEIGHT_OPTIONS.map((opt) => /* @__PURE__ */ (0, import_jsx_runtime.jsx)("option", {
							value: opt.value,
							children: opt.label
						}, opt.value))
					})]
				})
			]
		})] })]
	});
}
var SplitComponent = AccountSettingsPlaybackPage;
//#endregion
export { SplitComponent as component };
