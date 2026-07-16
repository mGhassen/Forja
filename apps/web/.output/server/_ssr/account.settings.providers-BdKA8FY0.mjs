import { r as __toESM } from "../_runtime.mjs";
import { n as require_react } from "../_libs/@radix-ui/react-compose-refs+[...].mjs";
import { a as require_jsx_runtime } from "../_libs/@radix-ui/react-label+[...].mjs";
import { a as CardHeader, i as CardDescription, n as Card, o as CardTitle, r as CardContent, t as Button } from "./card-BLl6aleQ.mjs";
import { a as SYNC_DOMAINS, c as emptyProvidersPayload, d as useUserSetting, n as AccountSettingsShell } from "./sync-domains-C0TgAES7.mjs";
import { i as ChevronDown, r as ChevronUp } from "../_libs/lucide-react.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/account.settings.providers-BdKA8FY0.js
var import_react = /* @__PURE__ */ __toESM(require_react());
var import_jsx_runtime = require_jsx_runtime();
function ProviderOrderList({ items, onChange, disabled }) {
	const move = (index, delta) => {
		const next = [...items];
		const target = index + delta;
		if (target < 0 || target >= next.length) return;
		const tmp = next[index];
		next[index] = next[target];
		next[target] = tmp;
		onChange(next);
	};
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("ul", {
		className: "divide-y divide-forja-border rounded-lg border border-forja-border",
		children: items.map((id, index) => /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("li", {
			className: "flex items-center justify-between gap-3 px-3 py-2.5 first:rounded-t-lg last:rounded-b-lg",
			children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
				className: "min-w-0",
				children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("span", {
					className: "text-xs text-forja-muted",
					children: ["#", index + 1]
				}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
					className: "ml-2 font-mono text-sm",
					children: id
				})]
			}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
				className: "flex shrink-0 gap-1",
				children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Button, {
					type: "button",
					variant: "ghost",
					size: "sm",
					className: "h-8 w-8 p-0",
					disabled: disabled || index === 0,
					onClick: () => move(index, -1),
					"aria-label": `Move ${id} up`,
					children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(ChevronUp, { className: "size-4" })
				}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Button, {
					type: "button",
					variant: "ghost",
					size: "sm",
					className: "h-8 w-8 p-0",
					disabled: disabled || index === items.length - 1,
					onClick: () => move(index, 1),
					"aria-label": `Move ${id} down`,
					children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(ChevronDown, { className: "size-4" })
				})]
			})]
		}, id))
	});
}
function AccountSettingsProvidersPage() {
	const { data, isLoading, save, isSaving, saveError } = useUserSetting(SYNC_DOMAINS.providers);
	const [draft, setDraft] = (0, import_react.useState)(emptyProvidersPayload());
	const [savedFlash, setSavedFlash] = (0, import_react.useState)(false);
	(0, import_react.useEffect)(() => {
		if (!data) return;
		setDraft({
			...emptyProvidersPayload(),
			...data.payload
		});
	}, [data]);
	const handleSave = async () => {
		await save(draft);
		setSavedFlash(true);
		window.setTimeout(() => setSavedFlash(false), 2500);
	};
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(AccountSettingsShell, {
		title: "Provider order",
		description: "Try-order for web streams, anime mirrors, and Asian drama hosts. Higher items are tried first.",
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
		children: [
			/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Card, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(CardHeader, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(CardTitle, { children: "Web streaming" }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(CardDescription, { children: "Embed and extractor providers for movies and TV." })] }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(CardContent, { children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(ProviderOrderList, {
				items: draft.stream_provider_order ?? [],
				disabled: isLoading,
				onChange: (stream_provider_order) => setDraft((prev) => ({
					...prev,
					stream_provider_order
				}))
			}) })] }),
			/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Card, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(CardHeader, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(CardTitle, { children: "Anime" }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(CardDescription, { children: "Mirror try-order for the Anime tab." })] }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(CardContent, { children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(ProviderOrderList, {
				items: draft.anime_provider_order ?? [],
				disabled: isLoading,
				onChange: (anime_provider_order) => setDraft((prev) => ({
					...prev,
					anime_provider_order
				}))
			}) })] }),
			/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Card, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(CardHeader, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(CardTitle, { children: "Asian drama" }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(CardDescription, { children: "KissKH-compatible hosts." })] }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(CardContent, { children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(ProviderOrderList, {
				items: draft.asian_drama_provider_order ?? [],
				disabled: isLoading,
				onChange: (asian_drama_provider_order) => setDraft((prev) => ({
					...prev,
					asian_drama_provider_order
				}))
			}) })] })
		]
	});
}
var SplitComponent = AccountSettingsProvidersPage;
//#endregion
export { SplitComponent as component };
