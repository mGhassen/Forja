import { r as __toESM } from "../_runtime.mjs";
import { n as require_react } from "../_libs/@radix-ui/react-compose-refs+[...].mjs";
import { i as require_jsx_runtime } from "../_libs/@radix-ui/react-label+[...].mjs";
import { n as useProfiles } from "./use-profiles-V2uJTVXk.mjs";
import { f as Link } from "../_libs/@tanstack/react-router+[...].mjs";
import { t as RequireAuth } from "./require-auth-DtXzK_my.mjs";
import { n as SiteHeader } from "./site-header-CQxqjJmj.mjs";
import { c as Plus, g as ArrowLeft, h as Check, l as Pencil, n as UserRound, r as Trash2 } from "../_libs/lucide-react.mjs";
import { t as Button } from "./button-DJTIkX4p.mjs";
import { t as Input } from "./input-tsNMiz--.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/account.profiles-B2sya13L.js
var import_react = /* @__PURE__ */ __toESM(require_react());
var import_jsx_runtime = require_jsx_runtime();
function AccountProfilesPage() {
	const { profiles, activeProfile, loading, selectProfile, createProfile, renameProfile, deleteProfile, creating } = useProfiles();
	const [newName, setNewName] = (0, import_react.useState)("");
	const [editingId, setEditingId] = (0, import_react.useState)(null);
	const [editingName, setEditingName] = (0, import_react.useState)("");
	const [deletingId, setDeletingId] = (0, import_react.useState)(null);
	const [error, setError] = (0, import_react.useState)(null);
	const handleCreate = async (event) => {
		event.preventDefault();
		setError(null);
		try {
			await createProfile(newName);
			setNewName("");
		} catch (caught) {
			setError(caught instanceof Error ? caught.message : "Could not create profile");
		}
	};
	const handleRename = async (profileId) => {
		setError(null);
		try {
			await renameProfile(profileId, editingName);
			setEditingId(null);
		} catch (caught) {
			setError(caught instanceof Error ? caught.message : "Could not rename profile");
		}
	};
	const handleDelete = async (profileId) => {
		setError(null);
		try {
			await deleteProfile(profileId);
			setDeletingId(null);
		} catch (caught) {
			setError(caught instanceof Error ? caught.message : "Could not delete profile");
		}
	};
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)(RequireAuth, { children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
		className: "min-h-screen",
		children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(SiteHeader, { solid: true }), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("main", {
			className: "mx-auto max-w-3xl px-5 pb-16 pt-24 sm:px-6 sm:pt-28",
			children: [
				/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					className: "flex items-center gap-3",
					children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
						to: "/account",
						className: "flex size-9 items-center justify-center text-forja-muted hover:text-forja-text",
						"aria-label": "Back to account",
						children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(ArrowLeft, { className: "size-5" })
					}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("h1", {
						className: "font-display text-3xl tracking-tight",
						children: "Profiles"
					})]
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
					className: "ml-12 mt-2 text-sm text-forja-muted",
					children: "Each profile has its own IPTV portals, playback preferences, providers, and addons."
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("section", {
					className: "mt-10",
					children: [
						/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
							className: "mb-2 flex items-center gap-2.5",
							children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", { className: "h-0.5 w-3.5 bg-forja-green" }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("h2", {
								className: "text-[11px] font-bold uppercase tracking-[0.16em] text-forja-green",
								children: "Your profiles"
							})]
						}),
						loading ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
							className: "py-5 text-sm text-forja-muted",
							children: "Loading…"
						}) : null,
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
							className: "divide-y divide-forja-border border-t border-forja-border",
							children: profiles.map((profile) => {
								const selected = profile.id === activeProfile?.id;
								const editing = editingId === profile.id;
								const deleting = deletingId === profile.id;
								return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
									className: "flex min-h-20 items-center gap-4 px-0.5 py-3",
									children: [
										/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("button", {
											type: "button",
											className: "relative flex size-11 shrink-0 items-center justify-center rounded-full text-black",
											style: { backgroundColor: profile.color },
											onClick: () => selectProfile(profile.id),
											"aria-label": `Use ${profile.name}`,
											children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(UserRound, { className: "size-5" }), selected ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
												className: "absolute -bottom-0.5 -right-0.5 flex size-4 items-center justify-center rounded-full bg-forja-text text-forja-bg",
												children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Check, { className: "size-3" })
											}) : null]
										}),
										/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
											className: "min-w-0 flex-1",
											children: editing ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Input, {
												autoFocus: true,
												value: editingName,
												maxLength: 40,
												onChange: (event) => setEditingName(event.target.value),
												onKeyDown: (event) => {
													if (event.key === "Enter") handleRename(profile.id);
													if (event.key === "Escape") setEditingId(null);
												}
											}) : /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(import_jsx_runtime.Fragment, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
												className: "font-semibold",
												children: profile.name
											}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
												className: "mt-0.5 text-xs text-forja-muted",
												children: selected ? "Active on this browser" : "Select profile"
											})] })
										}),
										deleting ? /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
											className: "flex items-center gap-2",
											children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Button, {
												size: "sm",
												variant: "ghost",
												onClick: () => setDeletingId(null),
												children: "Cancel"
											}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Button, {
												size: "sm",
												className: "bg-red-500 text-white hover:bg-red-400",
												onClick: () => void handleDelete(profile.id),
												children: "Delete"
											})]
										}) : editing ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Button, {
											size: "sm",
											variant: "ghost",
											onClick: () => void handleRename(profile.id),
											children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Check, { className: "size-4" })
										}) : /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
											className: "flex items-center gap-1",
											children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Button, {
												size: "sm",
												variant: "ghost",
												"aria-label": `Rename ${profile.name}`,
												onClick: () => {
													setEditingId(profile.id);
													setEditingName(profile.name);
												},
												children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Pencil, { className: "size-4" })
											}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Button, {
												size: "sm",
												variant: "ghost",
												disabled: profiles.length <= 1,
												"aria-label": `Delete ${profile.name}`,
												onClick: () => setDeletingId(profile.id),
												children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Trash2, { className: "size-4 text-red-300" })
											})]
										})
									]
								}, profile.id);
							})
						})
					]
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("section", {
					className: "mt-10",
					children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
						className: "mb-3 flex items-center gap-2.5",
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", { className: "h-0.5 w-3.5 bg-forja-green" }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("h2", {
							className: "text-[11px] font-bold uppercase tracking-[0.16em] text-forja-green",
							children: "Add profile"
						})]
					}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("form", {
						className: "flex gap-3",
						onSubmit: handleCreate,
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Input, {
							"aria-label": "New profile name",
							placeholder: "Profile name",
							maxLength: 40,
							value: newName,
							onChange: (event) => setNewName(event.target.value)
						}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Button, {
							type: "submit",
							disabled: creating || !newName.trim(),
							children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Plus, { className: "mr-2 size-4" }), "Add"]
						})]
					})]
				}),
				error ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
					className: "mt-5 text-sm text-red-300",
					children: error
				}) : null
			]
		})]
	}) });
}
var SplitComponent = AccountProfilesPage;
//#endregion
export { SplitComponent as component };
