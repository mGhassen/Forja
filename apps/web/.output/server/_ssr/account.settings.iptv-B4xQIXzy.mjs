import { r as __toESM } from "../_runtime.mjs";
import { u as require_react } from "../_libs/@floating-ui/react-dom+[...].mjs";
import { s as require_jsx_runtime } from "../_libs/@radix-ui/react-arrow+[...].mjs";
import { n as cn } from "./utils-BshMKIch.mjs";
import { a as Share2, b as Check, d as Pencil, i as Star, m as Copy, r as Trash2, s as Search, t as X, u as Plus } from "../_libs/lucide-react.mjs";
import { t as Button } from "./button-DinaqNdX.mjs";
import { t as Input } from "./input-WJWRaWLf.mjs";
import { a as emptyIptvPayload, i as SYNC_DOMAINS, l as portalKey, n as AccountSettingsShell, u as useUserSetting } from "./sync-domains-Djt7WER7.mjs";
import { t as Label } from "./label-1Dfq8Kig.mjs";
import { i as TabsTrigger, n as TabsContent, r as TabsList, t as Tabs } from "./tabs-BZQGAI4f.mjs";
import { t as SettingsSection } from "./settings-section-DPl3lks6.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/account.settings.iptv-B4xQIXzy.js
var import_react = /* @__PURE__ */ __toESM(require_react());
var import_jsx_runtime = require_jsx_runtime();
var SHARE_CODE_LENGTH = 8;
var CHARSET = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ";
var KEY_PREFIX = "forja-iptv-share-v1:";
var IV_PREFIX = "forja-iptv-iv-v1:";
function normalizeShareCode(raw) {
	return raw.trim().toUpperCase().replace(/[^A-Z0-9]/g, "");
}
function isValidShareCode(raw) {
	return normalizeShareCode(raw).length === SHARE_CODE_LENGTH;
}
function formatShareCode(raw) {
	const code = normalizeShareCode(raw);
	if (code.length <= 4) return code;
	return `${code.slice(0, 4)}-${code.slice(4)}`;
}
function generateCode() {
	const bytes = crypto.getRandomValues(new Uint8Array(SHARE_CODE_LENGTH));
	return Array.from(bytes, (b) => CHARSET[b % 32]).join("");
}
async function sha256(text) {
	const data = new TextEncoder().encode(text);
	const digest = await crypto.subtle.digest("SHA-256", data);
	return new Uint8Array(digest);
}
async function deriveKey(code) {
	const raw = await sha256(`${KEY_PREFIX}${code}`);
	return crypto.subtle.importKey("raw", raw, { name: "AES-CBC" }, false, ["encrypt", "decrypt"]);
}
async function deriveIv(code) {
	return (await sha256(`${IV_PREFIX}${code}`)).slice(0, 16);
}
function bytesToBase64(bytes) {
	let binary = "";
	for (const byte of bytes) binary += String.fromCharCode(byte);
	return btoa(binary);
}
function base64ToBytes(value) {
	const clean = value.replace(/\n/g, "").trim();
	const binary = atob(clean);
	const out = new Uint8Array(binary.length);
	for (let i = 0; i < binary.length; i += 1) out[i] = binary.charCodeAt(i);
	return out;
}
async function encryptPortal(portal, code) {
	const plain = new TextEncoder().encode(JSON.stringify({
		v: 1,
		url: portal.url,
		username: portal.username,
		password: portal.password
	}));
	const key = await deriveKey(code);
	const iv = await deriveIv(code);
	const cipher = await crypto.subtle.encrypt({
		name: "AES-CBC",
		iv
	}, key, plain);
	return bytesToBase64(new Uint8Array(cipher));
}
async function decryptPortal(encryptedB64, code) {
	try {
		const key = await deriveKey(code);
		const iv = await deriveIv(code);
		const cipherBytes = base64ToBytes(encryptedB64);
		const plainBuf = await crypto.subtle.decrypt({
			name: "AES-CBC",
			iv
		}, key, cipherBytes);
		const decoded = JSON.parse(new TextDecoder().decode(plainBuf));
		const url = decoded.url?.trim() ?? "";
		const username = decoded.username?.trim() ?? "";
		const password = decoded.password?.trim() ?? "";
		if (!url || !username || !password) return null;
		return {
			url,
			username,
			password,
			source: "Shared",
			name: username || url,
			expiry: "",
			max: "1",
			active: "0"
		};
	} catch {
		return null;
	}
}
async function postShareApi(path, body) {
	const response = await fetch(path, {
		method: "POST",
		headers: { "Content-Type": "application/json" },
		body: JSON.stringify(body)
	});
	const json = await response.json().catch(() => ({}));
	if (!response.ok) throw new Error(typeof json.error === "string" ? json.error : "Share service failed");
	return json;
}
/** Encrypt credentials and upload ciphertext; returns 8-char share code. */
async function createPortalShare(portal) {
	let lastError;
	for (let attempt = 0; attempt < 6; attempt += 1) {
		const code = generateCode();
		try {
			await postShareApi("/api/iptv-share", {
				action: "create",
				code,
				text: await encryptPortal(portal, code)
			});
			return code;
		} catch (error) {
			lastError = error;
			if ((error instanceof Error ? error.message : "").toLowerCase().includes("already in use")) continue;
			throw error;
		}
	}
	throw new Error(lastError instanceof Error ? lastError.message : "Could not allocate share code");
}
/** Resolve an 8-char share code into portal credentials. */
async function resolvePortalShare(rawCode) {
	const code = normalizeShareCode(rawCode);
	if (code.length !== SHARE_CODE_LENGTH) return null;
	const json = await postShareApi("/api/iptv-share", {
		action: "fetch",
		code
	});
	const text = typeof json.text === "string" ? json.text : "";
	if (!text) return null;
	return decryptPortal(text, code);
}
function newM3uId() {
	return `${Date.now().toString(16)}_${Math.random().toString(16).slice(2, 10)}`;
}
function AccountSettingsIptvPage() {
	const { data, profileId, isLoading, save, isSaving, saveError } = useUserSetting(SYNC_DOMAINS.iptv);
	const [draft, setDraft] = (0, import_react.useState)(emptyIptvPayload());
	const [portalQuery, setPortalQuery] = (0, import_react.useState)("");
	const [m3uQuery, setM3uQuery] = (0, import_react.useState)("");
	const [addOpen, setAddOpen] = (0, import_react.useState)(false);
	const [addMode, setAddMode] = (0, import_react.useState)("share");
	const [shareCode, setShareCode] = (0, import_react.useState)("");
	const [shareBusy, setShareBusy] = (0, import_react.useState)(false);
	const [shareError, setShareError] = (0, import_react.useState)(null);
	const [portalForm, setPortalForm] = (0, import_react.useState)({
		url: "",
		username: "",
		password: "",
		name: ""
	});
	const [editingKey, setEditingKey] = (0, import_react.useState)(null);
	const [shareFlash, setShareFlash] = (0, import_react.useState)({});
	const [sharingKey, setSharingKey] = (0, import_react.useState)(null);
	const [m3uForm, setM3uForm] = (0, import_react.useState)({
		name: "",
		sourceUrl: ""
	});
	const [savedFlash, setSavedFlash] = (0, import_react.useState)(false);
	(0, import_react.useEffect)(() => {
		setDraft(emptyIptvPayload());
		setPortalQuery("");
		setM3uQuery("");
		setAddOpen(false);
		setEditingKey(null);
	}, [profileId]);
	(0, import_react.useEffect)(() => {
		if (!data) return;
		setDraft({
			portals: data.payload.portals ?? [],
			favoriteKeys: data.payload.favoriteKeys ?? [],
			m3uPlaylists: data.payload.m3uPlaylists ?? []
		});
	}, [data]);
	const favorites = (0, import_react.useMemo)(() => new Set(draft.favoriteKeys ?? []), [draft.favoriteKeys]);
	const sortedPortals = (0, import_react.useMemo)(() => {
		const list = [...draft.portals];
		list.sort((a, b) => {
			const aFav = favorites.has(portalKey(a)) ? 0 : 1;
			const bFav = favorites.has(portalKey(b)) ? 0 : 1;
			if (aFav !== bFav) return aFav - bFav;
			const aName = (a.name || a.url).toLowerCase();
			const bName = (b.name || b.url).toLowerCase();
			return aName.localeCompare(bName);
		});
		return list;
	}, [draft.portals, favorites]);
	const filteredPortals = (0, import_react.useMemo)(() => {
		const q = portalQuery.trim().toLowerCase();
		if (!q) return sortedPortals;
		return sortedPortals.filter((portal) => {
			return [
				portal.name,
				portal.url,
				portal.username,
				portal.source
			].filter(Boolean).join(" ").toLowerCase().includes(q);
		});
	}, [sortedPortals, portalQuery]);
	const filteredM3u = (0, import_react.useMemo)(() => {
		const list = draft.m3uPlaylists ?? [];
		const q = m3uQuery.trim().toLowerCase();
		if (!q) return list;
		return list.filter((playlist) => [playlist.name, playlist.sourceUrl].filter(Boolean).join(" ").toLowerCase().includes(q));
	}, [draft.m3uPlaylists, m3uQuery]);
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
	const upsertPortal = (row, replaceKey) => {
		const key = portalKey(row);
		setDraft((prev) => {
			const without = prev.portals.filter((p) => {
				const pk = portalKey(p);
				if (replaceKey && pk === replaceKey) return false;
				return pk !== key;
			});
			const favoriteKeys = (prev.favoriteKeys ?? []).map((fav) => replaceKey && fav === replaceKey ? key : fav).filter((fav, index, arr) => arr.indexOf(fav) === index);
			return {
				...prev,
				portals: [...without, row],
				favoriteKeys
			};
		});
	};
	const addPortalManual = () => {
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
		upsertPortal(row, editingKey);
		setPortalForm({
			url: "",
			username: "",
			password: "",
			name: ""
		});
		setEditingKey(null);
		setAddOpen(false);
		setAddMode("share");
	};
	const beginEdit = (portal) => {
		setEditingKey(portalKey(portal));
		setPortalForm({
			url: portal.url,
			username: portal.username,
			password: portal.password,
			name: portal.name ?? ""
		});
		setAddMode("manual");
		setAddOpen(true);
		setShareError(null);
	};
	const removePortal = (key) => {
		setDraft((prev) => ({
			...prev,
			portals: prev.portals.filter((p) => portalKey(p) !== key),
			favoriteKeys: (prev.favoriteKeys ?? []).filter((k) => k !== key)
		}));
		if (editingKey === key) {
			setEditingKey(null);
			setPortalForm({
				url: "",
				username: "",
				password: "",
				name: ""
			});
		}
	};
	const importShareCode = async (raw) => {
		const code = normalizeShareCode(raw);
		if (!isValidShareCode(code)) return;
		setShareBusy(true);
		setShareError(null);
		try {
			const portal = await resolvePortalShare(code);
			if (!portal) {
				setShareError("Share code not found or expired");
				return;
			}
			const key = portalKey(portal);
			if (draft.portals.some((p) => portalKey(p) === key)) {
				setShareError("Portal already in your list");
				return;
			}
			upsertPortal(portal);
			setShareCode("");
			setAddOpen(false);
		} catch (error) {
			setShareError(error instanceof Error ? error.message : "Could not import share code");
		} finally {
			setShareBusy(false);
		}
	};
	const copyShare = async (portal) => {
		const key = portalKey(portal);
		setSharingKey(key);
		setShareError(null);
		try {
			const code = await createPortalShare(portal);
			const formatted = formatShareCode(code);
			try {
				await navigator.clipboard.writeText(code);
			} catch {}
			setShareFlash((prev) => ({
				...prev,
				[key]: formatted
			}));
			window.setTimeout(() => {
				setShareFlash((prev) => {
					const next = { ...prev };
					delete next[key];
					return next;
				});
			}, 8e3);
		} catch (error) {
			setShareError(error instanceof Error ? error.message : "Could not create share code");
		} finally {
			setSharingKey(null);
		}
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
		description: "Manage many Xtream portals and M3U URLs. Share codes work like the app — peer transfer, not account invite.",
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
				}) : null,
				shareError && !addOpen ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
					className: "text-sm text-red-300",
					children: shareError
				}) : null
			]
		}),
		children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(SettingsSection, {
			label: "Xtream portals",
			description: "Favorites stay on top. Search filters name, URL, and username.",
			children: [
				/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					className: "mb-3 flex flex-wrap items-center gap-2",
					children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
						className: "relative min-w-0 flex-1",
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Search, { className: "pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-forja-muted" }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Input, {
							"aria-label": "Search portals",
							placeholder: "Search portals…",
							value: portalQuery,
							onChange: (event) => setPortalQuery(event.target.value),
							className: "pl-9"
						})]
					}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Button, {
						type: "button",
						variant: "secondary",
						onClick: () => {
							setAddOpen((open) => !open);
							setAddMode("share");
							setEditingKey(null);
							setShareError(null);
							setPortalForm({
								url: "",
								username: "",
								password: "",
								name: ""
							});
						},
						children: [addOpen ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)(X, { className: "mr-2 size-4" }) : /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Plus, { className: "mr-2 size-4" }), addOpen ? "Close" : "Add"]
					})]
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", {
					className: "mb-2 text-xs text-forja-muted",
					children: [
						filteredPortals.length,
						portalQuery.trim() ? ` of ${draft.portals.length}` : "",
						" portals"
					]
				}),
				addOpen ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
					className: "mb-4 rounded-md border border-forja-border bg-forja-elevated/60 p-4",
					children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Tabs, {
						value: addMode,
						onValueChange: (value) => setAddMode(value),
						children: [
							/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(TabsList, {
								"aria-label": "Add portal method",
								children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(TabsTrigger, {
									value: "share",
									children: "Share code"
								}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(TabsTrigger, {
									value: "manual",
									children: "Manual"
								})]
							}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(TabsContent, {
								value: "share",
								className: "space-y-3",
								children: [
									/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Label, {
										htmlFor: "share-code",
										children: "Paste an 8-character code"
									}),
									/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Input, {
										id: "share-code",
										placeholder: "XXXX-XXXX",
										value: shareCode,
										maxLength: 9,
										disabled: shareBusy,
										onChange: (event) => {
											const next = formatShareCode(event.target.value);
											setShareCode(next);
											setShareError(null);
											if (isValidShareCode(next)) importShareCode(next);
										}
									}),
									/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
										className: "flex gap-2",
										children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Button, {
											type: "button",
											disabled: shareBusy || !isValidShareCode(shareCode),
											onClick: () => void importShareCode(shareCode),
											children: shareBusy ? "Importing…" : "Import portal"
										})
									}),
									shareError ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
										className: "text-sm text-red-300",
										children: shareError
									}) : /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
										className: "text-xs text-forja-muted",
										children: "Same share codes as the Forja app. Credentials never go through your account sync — only encrypted ciphertext."
									})
								]
							}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)(TabsContent, {
								value: "manual",
								children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
									className: "grid gap-3 sm:grid-cols-2",
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
										}),
										/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
											className: "sm:col-span-2",
											children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Button, {
												type: "button",
												variant: "secondary",
												onClick: addPortalManual,
												children: editingKey ? "Save portal" : "Add portal"
											})
										})
									]
								})
							})
						]
					})
				}) : null,
				isLoading ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
					className: "text-sm text-forja-muted",
					children: "Loading…"
				}) : filteredPortals.length === 0 ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
					className: "text-sm text-forja-muted",
					children: draft.portals.length === 0 ? "No portals yet — add a share code or enter credentials." : "No portals match your search."
				}) : /* @__PURE__ */ (0, import_jsx_runtime.jsx)("ul", {
					className: "max-h-[420px] divide-y divide-forja-border overflow-y-auto pr-1",
					children: filteredPortals.map((portal) => {
						const key = portalKey(portal);
						const starred = favorites.has(key);
						const shownCode = shareFlash[key];
						return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("li", {
							className: "flex min-h-14 items-center gap-2 px-0.5 py-2.5",
							children: [
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("button", {
									type: "button",
									className: cn("shrink-0 text-forja-muted hover:text-forja-green", starred && "text-amber-300 hover:text-amber-200"),
									onClick: () => toggleFavorite(portal),
									"aria-label": starred ? "Remove favorite" : "Mark favorite",
									children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Star, {
										className: "size-4",
										fill: starred ? "currentColor" : "none"
									})
								}),
								/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
									className: "min-w-0 flex-1",
									children: shownCode ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
										className: "font-mono text-base tracking-[0.18em] text-forja-green",
										children: shownCode
									}) : /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(import_jsx_runtime.Fragment, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
										className: "truncate font-medium",
										children: portal.name || portal.username || portal.url
									}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", {
										className: "truncate text-xs text-forja-muted",
										children: [
											portal.url,
											portal.username ? ` · ${portal.username}` : "",
											portal.expiry ? ` · expires ${portal.expiry}` : "",
											portal.max ? ` · ${portal.active || "0"}/${portal.max}` : ""
										]
									})] })
								}),
								/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
									className: "flex shrink-0 items-center gap-0.5",
									children: [
										/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Button, {
											type: "button",
											variant: "ghost",
											size: "sm",
											className: "h-8 w-8 p-0",
											disabled: sharingKey === key,
											"aria-label": "Copy share code",
											title: "Copy share code",
											onClick: () => void copyShare(portal),
											children: sharingKey === key ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Share2, { className: "size-4 animate-pulse" }) : shownCode ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Check, { className: "size-4 text-forja-green" }) : /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Copy, { className: "size-4" })
										}),
										/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Button, {
											type: "button",
											variant: "ghost",
											size: "sm",
											className: "h-8 w-8 p-0",
											"aria-label": "Edit portal",
											onClick: () => beginEdit(portal),
											children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Pencil, { className: "size-4" })
										}),
										/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Button, {
											type: "button",
											variant: "ghost",
											size: "sm",
											className: "h-8 w-8 p-0 text-red-300 hover:text-red-200",
											"aria-label": "Delete portal",
											onClick: () => removePortal(key),
											children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Trash2, { className: "size-4" })
										})
									]
								})
							]
						}, key);
					})
				})
			]
		}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(SettingsSection, {
			label: "M3U playlists",
			description: "Remote playlist URLs refresh in the app. File uploads stay device-local.",
			children: [
				(draft.m3uPlaylists ?? []).length > 4 ? /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					className: "relative mb-3",
					children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Search, { className: "pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-forja-muted" }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Input, {
						"aria-label": "Search M3U playlists",
						placeholder: "Search playlists…",
						value: m3uQuery,
						onChange: (event) => setM3uQuery(event.target.value),
						className: "pl-9"
					})]
				}) : null,
				filteredM3u.length === 0 ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
					className: "text-sm text-forja-muted",
					children: (draft.m3uPlaylists ?? []).length === 0 ? "No M3U URLs yet." : "No playlists match your search."
				}) : /* @__PURE__ */ (0, import_jsx_runtime.jsx)("ul", {
					className: "mb-4 max-h-64 divide-y divide-forja-border overflow-y-auto",
					children: filteredM3u.map((playlist) => /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("li", {
						className: "flex min-h-14 items-center justify-between gap-3 px-0.5 py-2.5",
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
							className: "min-w-0",
							children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
								className: "truncate font-medium",
								children: playlist.name
							}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
								className: "truncate text-xs text-forja-muted",
								children: playlist.sourceUrl
							})]
						}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Button, {
							type: "button",
							variant: "ghost",
							size: "sm",
							className: "h-8 w-8 p-0 text-red-300 hover:text-red-200",
							onClick: () => removeM3u(playlist.id),
							children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Trash2, { className: "size-4" })
						})]
					}, playlist.id))
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					className: "grid gap-3 sm:grid-cols-2",
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
				/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Button, {
					type: "button",
					variant: "secondary",
					className: "mt-3",
					onClick: addM3u,
					children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Plus, { className: "mr-2 size-4" }), "Add M3U URL"]
				})
			]
		})]
	});
}
var SplitComponent = AccountSettingsIptvPage;
//#endregion
export { SplitComponent as component };
