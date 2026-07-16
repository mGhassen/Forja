import { r as __toESM } from "../_runtime.mjs";
import { n as require_react } from "../_libs/@radix-ui/react-compose-refs+[...].mjs";
import { i as require_jsx_runtime } from "../_libs/@radix-ui/react-label+[...].mjs";
import { i as Star, r as Trash2 } from "../_libs/lucide-react.mjs";
import { t as Button } from "./button-DJTIkX4p.mjs";
import { t as Input } from "./input-tsNMiz--.mjs";
import { a as SettingsSection, d as useUserSetting, i as SYNC_DOMAINS, n as AccountSettingsShell, o as emptyIptvPayload, u as portalKey } from "./sync-domains-_br4J9hJ.mjs";
import { t as Label } from "./label-D3h4O29f.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/account.settings.iptv-CMxPA31D.js
var import_react = /* @__PURE__ */ __toESM(require_react());
var import_jsx_runtime = require_jsx_runtime();
function newM3uId() {
	return `${Date.now().toString(16)}_${Math.random().toString(16).slice(2, 10)}`;
}
function AccountSettingsIptvPage() {
	const { data, profileId, isLoading, save, isSaving, saveError } = useUserSetting(SYNC_DOMAINS.iptv);
	const [draft, setDraft] = (0, import_react.useState)(emptyIptvPayload());
	const [portalForm, setPortalForm] = (0, import_react.useState)({
		url: "",
		username: "",
		password: "",
		name: ""
	});
	const [m3uForm, setM3uForm] = (0, import_react.useState)({
		name: "",
		sourceUrl: ""
	});
	const [savedFlash, setSavedFlash] = (0, import_react.useState)(false);
	(0, import_react.useEffect)(() => {
		setDraft(emptyIptvPayload());
	}, [profileId]);
	(0, import_react.useEffect)(() => {
		if (!data) return;
		setDraft({
			portals: data.payload.portals ?? [],
			favoriteKeys: data.payload.favoriteKeys ?? [],
			m3uPlaylists: data.payload.m3uPlaylists ?? []
		});
	}, [data]);
	const favorites = new Set(draft.favoriteKeys ?? []);
	const toggleFavorite = (row) => {
		const key = portalKey(row);
		const next = new Set(favorites);
		if (next.has(key)) next.delete(key);
		else next.add(key);
		setDraft((prev) => ({
			...prev,
			favoriteKeys: [...next]
		}));
	};
	const addPortal = () => {
		const url = portalForm.url.trim();
		const username = portalForm.username.trim();
		const password = portalForm.password;
		if (!url || !username || !password) return;
		const row = {
			url,
			username,
			password,
			name: portalForm.name.trim() || url,
			source: "web",
			expiry: "",
			max: "1",
			active: "0"
		};
		const key = portalKey(row);
		if (draft.portals.some((p) => portalKey(p) === key)) return;
		setDraft((prev) => ({
			...prev,
			portals: [...prev.portals, row]
		}));
		setPortalForm({
			url: "",
			username: "",
			password: "",
			name: ""
		});
	};
	const removePortal = (key) => {
		setDraft((prev) => ({
			...prev,
			portals: prev.portals.filter((p) => portalKey(p) !== key),
			favoriteKeys: (prev.favoriteKeys ?? []).filter((k) => k !== key)
		}));
	};
	const addM3u = () => {
		const name = m3uForm.name.trim();
		const sourceUrl = m3uForm.sourceUrl.trim();
		if (!name || !sourceUrl) return;
		const now = Date.now();
		const row = {
			id: newM3uId(),
			name,
			sourceUrl,
			addedAt: now,
			updatedAt: now,
			channels: []
		};
		setDraft((prev) => ({
			...prev,
			m3uPlaylists: [...prev.m3uPlaylists ?? [], row]
		}));
		setM3uForm({
			name: "",
			sourceUrl: ""
		});
	};
	const removeM3u = (id) => {
		setDraft((prev) => ({
			...prev,
			m3uPlaylists: (prev.m3uPlaylists ?? []).filter((p) => p.id !== id)
		}));
	};
	const handleSave = async () => {
		await save(draft);
		setSavedFlash(true);
		window.setTimeout(() => setSavedFlash(false), 2500);
	};
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(AccountSettingsShell, {
		title: "IPTV portals",
		description: "Xtream-Codes portals and M3U playlist URLs. The app pulls these on sign-in — credentials are stored in your account (HTTPS + row-level access only).",
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
		children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(SettingsSection, {
			label: "Xtream portals",
			description: "Panel URL plus username and password — same fields as in the IPTV tab.",
			children: [
				isLoading ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
					className: "text-sm text-forja-muted",
					children: "Loading…"
				}) : draft.portals.length === 0 ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
					className: "text-sm text-forja-muted",
					children: "No portals yet."
				}) : /* @__PURE__ */ (0, import_jsx_runtime.jsx)("ul", {
					className: "divide-y divide-forja-border",
					children: draft.portals.map((portal) => {
						const key = portalKey(portal);
						const starred = favorites.has(key);
						return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("li", {
							className: "flex min-h-[64px] items-center gap-3 px-0.5 py-3",
							children: [
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("button", {
									type: "button",
									className: "mt-0.5 text-forja-muted hover:text-forja-green",
									onClick: () => toggleFavorite(portal),
									"aria-label": starred ? "Remove favorite" : "Mark favorite",
									children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Star, {
										className: "size-4",
										fill: starred ? "currentColor" : "none"
									})
								}),
								/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
									className: "min-w-0 flex-1",
									children: [
										/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
											className: "font-medium",
											children: portal.name || portal.url
										}),
										/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
											className: "truncate text-sm text-forja-muted",
											children: portal.url
										}),
										/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", {
											className: "text-xs text-forja-muted",
											children: [portal.username, portal.expiry ? ` · expires ${portal.expiry}` : ""]
										})
									]
								}),
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Button, {
									type: "button",
									variant: "ghost",
									size: "sm",
									className: "text-red-300 hover:text-red-200",
									onClick: () => removePortal(key),
									children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Trash2, { className: "size-4" })
								})
							]
						}, key);
					})
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					className: "mt-5 grid gap-3 border-t border-forja-border pt-5 sm:grid-cols-2",
					children: [
						/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
							className: "space-y-2 sm:col-span-2",
							children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Label, {
								htmlFor: "portal-url",
								children: "Panel URL"
							}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Input, {
								id: "portal-url",
								placeholder: "http://example.com:8080",
								value: portalForm.url,
								onChange: (e) => setPortalForm((f) => ({
									...f,
									url: e.target.value
								}))
							})]
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
							className: "space-y-2",
							children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Label, {
								htmlFor: "portal-user",
								children: "Username"
							}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Input, {
								id: "portal-user",
								value: portalForm.username,
								onChange: (e) => setPortalForm((f) => ({
									...f,
									username: e.target.value
								}))
							})]
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
							className: "space-y-2",
							children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Label, {
								htmlFor: "portal-pass",
								children: "Password"
							}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Input, {
								id: "portal-pass",
								type: "password",
								value: portalForm.password,
								onChange: (e) => setPortalForm((f) => ({
									...f,
									password: e.target.value
								}))
							})]
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
							className: "space-y-2 sm:col-span-2",
							children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Label, {
								htmlFor: "portal-name",
								children: "Display name (optional)"
							}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Input, {
								id: "portal-name",
								value: portalForm.name,
								onChange: (e) => setPortalForm((f) => ({
									...f,
									name: e.target.value
								}))
							})]
						})
					]
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Button, {
					type: "button",
					variant: "secondary",
					onClick: addPortal,
					children: "Add portal"
				})
			]
		}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(SettingsSection, {
			label: "M3U playlists",
			description: "Remote playlist URLs refresh in the app. File uploads stay device-local.",
			children: [
				(draft.m3uPlaylists ?? []).length === 0 ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
					className: "text-sm text-forja-muted",
					children: "No M3U URLs yet."
				}) : /* @__PURE__ */ (0, import_jsx_runtime.jsx)("ul", {
					className: "divide-y divide-forja-border",
					children: (draft.m3uPlaylists ?? []).map((playlist) => /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("li", {
						className: "flex min-h-[64px] items-center justify-between gap-3 px-0.5 py-3",
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
							className: "min-w-0",
							children: [
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
									className: "font-medium",
									children: playlist.name
								}),
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
									className: "truncate text-sm text-forja-muted",
									children: playlist.sourceUrl
								}),
								playlist.channels.length > 0 ? /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", {
									className: "text-xs text-forja-muted",
									children: [playlist.channels.length, " cached channels"]
								}) : null
							]
						}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Button, {
							type: "button",
							variant: "ghost",
							size: "sm",
							className: "text-red-300 hover:text-red-200",
							onClick: () => removeM3u(playlist.id),
							children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Trash2, { className: "size-4" })
						})]
					}, playlist.id))
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					className: "mt-5 grid gap-3 border-t border-forja-border pt-5 sm:grid-cols-2",
					children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
						className: "space-y-2",
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Label, {
							htmlFor: "m3u-name",
							children: "Name"
						}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Input, {
							id: "m3u-name",
							value: m3uForm.name,
							onChange: (e) => setM3uForm((f) => ({
								...f,
								name: e.target.value
							}))
						})]
					}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
						className: "space-y-2",
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Label, {
							htmlFor: "m3u-url",
							children: "Playlist URL"
						}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Input, {
							id: "m3u-url",
							placeholder: "https://…/playlist.m3u",
							value: m3uForm.sourceUrl,
							onChange: (e) => setM3uForm((f) => ({
								...f,
								sourceUrl: e.target.value
							}))
						})]
					})]
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Button, {
					type: "button",
					variant: "secondary",
					onClick: addM3u,
					children: "Add M3U URL"
				})
			]
		})]
	});
}
var SplitComponent = AccountSettingsIptvPage;
//#endregion
export { SplitComponent as component };
