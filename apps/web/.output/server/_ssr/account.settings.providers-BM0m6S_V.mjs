import { r as __toESM } from "../_runtime.mjs";
import { u as require_react } from "../_libs/@floating-ui/react-dom+[...].mjs";
import { s as require_jsx_runtime } from "../_libs/@radix-ui/react-arrow+[...].mjs";
import { _ as ChevronUp, y as ChevronDown } from "../_libs/lucide-react.mjs";
import { t as Button } from "./button-DinaqNdX.mjs";
import { i as SYNC_DOMAINS, n as AccountSettingsShell, s as emptyProvidersPayload, u as useUserSetting } from "./sync-domains-Djt7WER7.mjs";
import { i as TabsTrigger, n as TabsContent, r as TabsList, t as Tabs } from "./tabs-BZQGAI4f.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/account.settings.providers-BM0m6S_V.js
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
		className: "divide-y divide-forja-border",
		children: items.map((id, index) => /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("li", {
			className: "flex min-h-[52px] items-center justify-between gap-3 px-0.5 py-2.5",
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
var tabs = [
	{
		id: "film",
		label: "Film and series",
		description: "Embed and extractor providers for movies and TV.",
		key: "stream_provider_order"
	},
	{
		id: "anime",
		label: "Anime",
		description: "Mirror try-order for the Anime tab.",
		key: "anime_provider_order"
	},
	{
		id: "asian",
		label: "Asian drama",
		description: "KissKH-compatible hosts.",
		key: "asian_drama_provider_order"
	}
];
function AccountSettingsProvidersPage() {
	const { data, profileId, isLoading, save, isSaving, saveError } = useUserSetting(SYNC_DOMAINS.providers);
	const [draft, setDraft] = (0, import_react.useState)(emptyProvidersPayload());
	const [savedFlash, setSavedFlash] = (0, import_react.useState)(false);
	(0, import_react.useEffect)(() => {
		setDraft(emptyProvidersPayload());
	}, [profileId]);
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
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)(AccountSettingsShell, {
		title: "Provider order",
		description: "Try-order for film and series, anime mirrors, and Asian drama hosts. Higher items are tried first.",
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
		children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Tabs, {
			defaultValue: "film",
			children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(TabsList, {
				"aria-label": "Provider types",
				children: tabs.map((item) => /* @__PURE__ */ (0, import_jsx_runtime.jsx)(TabsTrigger, {
					value: item.id,
					children: item.label
				}, item.id))
			}), tabs.map((item) => /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(TabsContent, {
				value: item.id,
				className: "min-h-80",
				children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
					className: "mb-4 text-xs leading-5 text-forja-muted",
					children: item.description
				}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(ProviderOrderList, {
					items: draft[item.key] ?? [],
					disabled: isLoading,
					onChange: (next) => setDraft((prev) => ({
						...prev,
						[item.key]: next
					}))
				})]
			}, item.id))]
		})
	});
}
var SplitComponent = AccountSettingsProvidersPage;
//#endregion
export { SplitComponent as component };
