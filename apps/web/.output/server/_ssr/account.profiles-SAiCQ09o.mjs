import { r as __toESM } from "../_runtime.mjs";
import { u as require_react } from "../_libs/@floating-ui/react-dom+[...].mjs";
import { s as require_jsx_runtime } from "../_libs/@radix-ui/react-arrow+[...].mjs";
import { b as Check, r as Trash2, u as Plus, x as ArrowLeft } from "../_libs/lucide-react.mjs";
import { a as normalizeAvatarKey, n as PROFILE_AVATAR_CATEGORIES, o as useProfiles, r as ProfileAvatar, t as PROFILE_AVATARS } from "./use-profiles-CvQVjB9I.mjs";
import { f as Link, m as useNavigate } from "../_libs/@tanstack/react-router+[...].mjs";
import { t as RequireAuth } from "./require-auth-DcPvmrt3.mjs";
import { n as SiteHeader } from "./site-header-_V616WVj.mjs";
import { t as Button } from "./button-DinaqNdX.mjs";
import { t as Input } from "./input-WJWRaWLf.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/account.profiles-SAiCQ09o.js
var import_react = /* @__PURE__ */ __toESM(require_react());
var import_jsx_runtime = require_jsx_runtime();
function AccountProfilesPage() {
	const navigate = useNavigate();
	const { profiles, activeProfile, loading, selectProfile, createProfile, renameProfile, updateProfileAvatar, deleteProfile, creating } = useProfiles();
	const [screen, setScreen] = (0, import_react.useState)("choose");
	const [editingId, setEditingId] = (0, import_react.useState)(null);
	const [name, setName] = (0, import_react.useState)("");
	const [avatarKey, setAvatarKey] = (0, import_react.useState)("forge");
	const [saving, setSaving] = (0, import_react.useState)(false);
	const [error, setError] = (0, import_react.useState)(null);
	const editingProfile = profiles.find((profile) => profile.id === editingId) ?? null;
	(0, import_react.useEffect)(() => {
		if (!editingProfile || screen !== "edit") return;
		setName(editingProfile.name);
		setAvatarKey(normalizeAvatarKey(editingProfile.avatar_key));
	}, [editingProfile, screen]);
	const chooseProfile = (profileId) => {
		selectProfile(profileId);
		navigate({ to: "/account/settings" });
	};
	const beginCreate = () => {
		setName("");
		setAvatarKey(PROFILE_AVATARS[profiles.length % PROFILE_AVATARS.length].key);
		setError(null);
		setScreen("create");
	};
	const beginEdit = (profileId) => {
		setEditingId(profileId);
		setError(null);
		setScreen("edit");
	};
	const handleSave = async (event) => {
		event.preventDefault();
		setError(null);
		setSaving(true);
		try {
			if (screen === "create") await createProfile(name, avatarKey);
			else if (editingProfile) await Promise.all([renameProfile(editingProfile.id, name), updateProfileAvatar(editingProfile.id, avatarKey)]);
			setScreen("manage");
			setEditingId(null);
		} catch (caught) {
			setError(caught instanceof Error ? caught.message : "Could not save profile");
		} finally {
			setSaving(false);
		}
	};
	const handleDelete = async () => {
		if (!editingProfile) return;
		setSaving(true);
		setError(null);
		try {
			await deleteProfile(editingProfile.id);
			setScreen("manage");
			setEditingId(null);
		} catch (caught) {
			setError(caught instanceof Error ? caught.message : "Could not delete profile");
		} finally {
			setSaving(false);
		}
	};
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)(RequireAuth, { children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
		className: "min-h-screen",
		children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(SiteHeader, { solid: true }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("main", {
			className: "mx-auto flex min-h-screen max-w-6xl flex-col items-center justify-center px-5 pb-20 pt-28 sm:px-8",
			children: screen === "create" || screen === "edit" ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)(ProfileEditor, {
				title: screen === "create" ? "Add profile" : "Edit profile",
				name,
				avatarKey,
				saving: saving || creating,
				canDelete: screen === "edit" && profiles.length > 1,
				error,
				onNameChange: setName,
				onAvatarChange: setAvatarKey,
				onSave: handleSave,
				onDelete: () => void handleDelete(),
				onCancel: () => {
					setScreen("manage");
					setEditingId(null);
				}
			}) : /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(import_jsx_runtime.Fragment, { children: [
				/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					className: "relative w-full text-center",
					children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Link, {
						to: "/account",
						className: "absolute left-0 top-1/2 hidden -translate-y-1/2 items-center gap-2 text-sm text-forja-muted hover:text-forja-text sm:flex",
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(ArrowLeft, { className: "size-4" }), "Account"]
					}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("h1", {
						className: "font-display text-4xl tracking-tight sm:text-5xl",
						children: screen === "manage" ? "Manage profiles" : "Who's watching?"
					})]
				}),
				loading ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
					className: "mt-12 text-forja-muted",
					children: "Loading profiles…"
				}) : /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					className: "mt-12 flex max-w-5xl flex-wrap justify-center gap-x-5 gap-y-9 sm:gap-x-7",
					children: [profiles.map((profile) => {
						const selected = profile.id === activeProfile?.id;
						return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("button", {
							type: "button",
							className: "group w-28 text-center sm:w-36",
							onClick: () => screen === "manage" ? beginEdit(profile.id) : chooseProfile(profile.id),
							children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(ProfileAvatar, {
								avatarKey: profile.avatar_key,
								name: profile.name,
								editing: screen === "manage",
								className: `w-full border-[3px] transition duration-200 group-hover:scale-[1.04] group-hover:border-white ${selected && screen === "choose" ? "border-forja-green" : "border-transparent"}`
							}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
								className: `mt-3 block truncate text-base transition group-hover:text-white ${selected && screen === "choose" ? "text-forja-text" : "text-forja-muted"}`,
								children: profile.name
							})]
						}, profile.id);
					}), screen === "manage" ? /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("button", {
						type: "button",
						className: "group w-28 text-center sm:w-36",
						onClick: beginCreate,
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
							className: "flex aspect-square w-full items-center justify-center rounded-[4px] border-[3px] border-dashed border-white/25 text-forja-muted transition group-hover:scale-[1.04] group-hover:border-white group-hover:text-white",
							children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Plus, {
								className: "size-14",
								strokeWidth: 1.25
							})
						}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
							className: "mt-3 block text-base text-forja-muted group-hover:text-white",
							children: "Add profile"
						})]
					}) : null]
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Button, {
					type: "button",
					variant: screen === "manage" ? "default" : "secondary",
					className: "mt-14 min-w-40 uppercase tracking-[0.12em]",
					onClick: () => setScreen((current) => current === "manage" ? "choose" : "manage"),
					children: screen === "manage" ? "Done" : "Manage profiles"
				})
			] })
		})]
	}) });
}
function ProfileEditor({ title, name, avatarKey, saving, canDelete, error, onNameChange, onAvatarChange, onSave, onDelete, onCancel }) {
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("section", {
		className: "w-full max-w-5xl",
		children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("h1", {
			className: "border-b border-forja-border pb-5 font-display text-4xl tracking-tight sm:text-5xl",
			children: title
		}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("form", {
			onSubmit: onSave,
			children: [
				/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					className: "grid gap-8 border-b border-forja-border py-8 sm:grid-cols-[150px_1fr]",
					children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(ProfileAvatar, {
						avatarKey,
						name: name || "New profile",
						className: "w-36 border-2 border-white/20"
					}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", { children: [
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Input, {
							autoFocus: true,
							"aria-label": "Profile name",
							placeholder: "Profile name",
							maxLength: 40,
							value: name,
							onChange: (event) => onNameChange(event.target.value),
							className: "h-12 text-base"
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
							className: "mb-4 mt-7 text-xs font-bold uppercase tracking-[0.16em] text-forja-muted",
							children: "Choose an avatar"
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
							className: "space-y-6",
							children: PROFILE_AVATAR_CATEGORIES.map((category) => /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("fieldset", { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("legend", {
								className: "mb-2 text-sm font-semibold text-forja-text",
								children: [category.label, /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
									className: "ml-2 font-normal text-forja-muted",
									children: category.avatars.length
								})]
							}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
								className: "grid grid-cols-4 gap-2.5 sm:grid-cols-8",
								children: category.avatars.map((avatar) => {
									const selected = avatar.key === avatarKey;
									return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("button", {
										type: "button",
										onClick: () => onAvatarChange(avatar.key),
										"aria-label": `Use ${avatar.label} avatar`,
										title: avatar.label,
										children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(ProfileAvatar, {
											avatarKey: avatar.key,
											name: avatar.label,
											className: `w-full border-[3px] transition hover:scale-105 hover:border-white ${selected ? "border-forja-green" : "border-transparent"}`
										}), selected ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
											className: "mx-auto mt-1 flex size-4 items-center justify-center rounded-full bg-forja-green text-black",
											children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Check, { className: "size-3" })
										}) : /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", { className: "mt-1 block h-4" })]
									}, avatar.key);
								})
							})] }, category.key))
						})
					] })]
				}),
				error ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
					className: "mt-4 text-sm text-red-300",
					children: error
				}) : null,
				/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					className: "mt-6 flex flex-wrap gap-3",
					children: [
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Button, {
							type: "submit",
							disabled: saving || !name.trim(),
							children: saving ? "Saving…" : "Save profile"
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Button, {
							type: "button",
							variant: "secondary",
							onClick: onCancel,
							children: "Cancel"
						}),
						canDelete ? /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Button, {
							type: "button",
							variant: "ghost",
							className: "sm:ml-auto",
							onClick: onDelete,
							disabled: saving,
							children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Trash2, { className: "mr-2 size-4 text-red-300" }), "Delete profile"]
						}) : null
					]
				})
			]
		})]
	});
}
var SplitComponent = AccountProfilesPage;
//#endregion
export { SplitComponent as component };
