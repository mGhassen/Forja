import { r as __toESM } from "../_runtime.mjs";
import { u as require_react } from "../_libs/@floating-ui/react-dom+[...].mjs";
import { s as require_jsx_runtime } from "../_libs/@radix-ui/react-arrow+[...].mjs";
import { a as useAuth, i as supabaseConfigured, n as cn, r as supabase } from "./utils-BshMKIch.mjs";
import { i as useQueryClient, n as useQuery, t as useMutation } from "../_libs/tanstack__react-query.mjs";
import { b as Check, c as Radio, g as CirclePlay, h as Circle, l as Puzzle, p as ListOrdered, v as ChevronRight, x as ArrowLeft, y as ChevronDown } from "../_libs/lucide-react.mjs";
import { o as useProfiles, r as ProfileAvatar } from "./use-profiles-CvQVjB9I.mjs";
import { a as useRouterState, f as Link } from "../_libs/@tanstack/react-router+[...].mjs";
import { t as RequireAuth } from "./require-auth-DcPvmrt3.mjs";
import { n as SiteHeader } from "./site-header-_V616WVj.mjs";
import { a as Label2, c as Root2, d as SubTrigger2, f as Trigger, i as ItemIndicator2, l as Separator2, n as Content2, o as Portal2, r as Item2, s as RadioItem2, t as CheckboxItem2, u as SubContent2 } from "../_libs/@radix-ui/react-dropdown-menu+[...].mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/sync-domains-Djt7WER7.js
var import_react = /* @__PURE__ */ __toESM(require_react());
var import_jsx_runtime = require_jsx_runtime();
var DropdownMenu = Root2;
var DropdownMenuTrigger = Trigger;
var DropdownMenuSubTrigger = import_react.forwardRef(({ className, inset, children, ...props }, ref) => /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(SubTrigger2, {
	ref,
	className: cn("flex cursor-default select-none items-center gap-2 rounded-sm px-2 py-1.5 text-sm outline-none focus:bg-white/8 data-[state=open]:bg-white/8", inset && "pl-8", className),
	...props,
	children: [children, /* @__PURE__ */ (0, import_jsx_runtime.jsx)(ChevronRight, { className: "ml-auto size-4" })]
}));
DropdownMenuSubTrigger.displayName = SubTrigger2.displayName;
var DropdownMenuSubContent = import_react.forwardRef(({ className, ...props }, ref) => /* @__PURE__ */ (0, import_jsx_runtime.jsx)(SubContent2, {
	ref,
	className: cn("z-50 min-w-40 overflow-hidden rounded-md border border-forja-border bg-forja-elevated p-1 text-forja-text shadow-lg data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 data-[state=closed]:zoom-out-95 data-[state=open]:zoom-in-95 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2", className),
	...props
}));
DropdownMenuSubContent.displayName = SubContent2.displayName;
var DropdownMenuContent = import_react.forwardRef(({ className, sideOffset = 6, ...props }, ref) => /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Portal2, { children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Content2, {
	ref,
	sideOffset,
	className: cn("z-50 min-w-48 overflow-hidden rounded-md border border-forja-border bg-forja-elevated p-1 text-forja-text shadow-xl data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 data-[state=closed]:zoom-out-95 data-[state=open]:zoom-in-95 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2", className),
	...props
}) }));
DropdownMenuContent.displayName = Content2.displayName;
var DropdownMenuItem = import_react.forwardRef(({ className, inset, ...props }, ref) => /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Item2, {
	ref,
	className: cn("relative flex cursor-default select-none items-center gap-2 rounded-sm px-2 py-1.5 text-sm outline-none transition-colors focus:bg-white/8 focus:text-forja-text data-[disabled]:pointer-events-none data-[disabled]:opacity-50", inset && "pl-8", className),
	...props
}));
DropdownMenuItem.displayName = Item2.displayName;
var DropdownMenuCheckboxItem = import_react.forwardRef(({ className, children, checked, ...props }, ref) => /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(CheckboxItem2, {
	ref,
	className: cn("relative flex cursor-default select-none items-center rounded-sm py-1.5 pl-8 pr-2 text-sm outline-none transition-colors focus:bg-white/8 focus:text-forja-text data-[disabled]:pointer-events-none data-[disabled]:opacity-50", className),
	checked,
	...props,
	children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
		className: "absolute left-2 flex size-3.5 items-center justify-center",
		children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(ItemIndicator2, { children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Check, { className: "size-4" }) })
	}), children]
}));
DropdownMenuCheckboxItem.displayName = CheckboxItem2.displayName;
var DropdownMenuRadioItem = import_react.forwardRef(({ className, children, ...props }, ref) => /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(RadioItem2, {
	ref,
	className: cn("relative flex cursor-default select-none items-center rounded-sm py-1.5 pl-8 pr-2 text-sm outline-none transition-colors focus:bg-white/8 focus:text-forja-text data-[disabled]:pointer-events-none data-[disabled]:opacity-50", className),
	...props,
	children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
		className: "absolute left-2 flex size-3.5 items-center justify-center",
		children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(ItemIndicator2, { children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Circle, { className: "size-2 fill-current" }) })
	}), children]
}));
DropdownMenuRadioItem.displayName = RadioItem2.displayName;
var DropdownMenuLabel = import_react.forwardRef(({ className, inset, ...props }, ref) => /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Label2, {
	ref,
	className: cn("px-2 py-1.5 text-xs font-semibold text-forja-muted", inset && "pl-8", className),
	...props
}));
DropdownMenuLabel.displayName = Label2.displayName;
var DropdownMenuSeparator = import_react.forwardRef(({ className, ...props }, ref) => /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Separator2, {
	ref,
	className: cn("-mx-1 my-1 h-px bg-forja-border", className),
	...props
}));
DropdownMenuSeparator.displayName = Separator2.displayName;
var categories = [
	{
		href: "/account/settings/iptv",
		title: "IPTV portals",
		subtitle: "Xtream and M3U lists",
		icon: Radio
	},
	{
		href: "/account/settings/playback",
		title: "Playback",
		subtitle: "Sources, quality, auto-play",
		icon: CirclePlay
	},
	{
		href: "/account/settings/providers",
		title: "Provider order",
		subtitle: "Film, anime, and Asian drama",
		icon: ListOrdered
	},
	{
		href: "/account/settings/stremio",
		title: "Stremio addons",
		subtitle: "Synced manifest URLs",
		icon: Puzzle
	}
];
function AccountSettingsShell({ title, description, backTo = "/account/settings", backLabel = "← All settings", children, footer }) {
	const pathname = useRouterState({ select: (state) => state.location.pathname });
	const { profiles, activeProfile, selectProfile, loading: profilesLoading } = useProfiles();
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)(RequireAuth, { children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
		className: "min-h-screen",
		children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(SiteHeader, { solid: true }), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("main", {
			className: "mx-auto max-w-6xl px-5 pb-16 pt-24 sm:px-6 sm:pt-28",
			children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
				className: "mb-7 flex flex-wrap items-center justify-between gap-4",
				children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					className: "flex items-center gap-3",
					children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
						to: backTo,
						className: "flex size-9 items-center justify-center text-forja-muted hover:text-forja-text",
						"aria-label": backLabel.replace("← ", ""),
						children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(ArrowLeft, { className: "size-5" })
					}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("h1", {
						className: "font-display text-2xl tracking-tight",
						children: "Settings"
					})]
				}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
					className: "flex items-center gap-2",
					children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(DropdownMenu, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(DropdownMenuTrigger, {
						"aria-label": "Active profile",
						disabled: profilesLoading || profiles.length === 0,
						className: "inline-flex items-center gap-2 rounded-md border border-forja-border bg-forja-elevated px-2.5 py-1.5 text-sm font-semibold outline-none transition hover:border-forja-green/40 focus-visible:ring-2 focus-visible:ring-forja-green/60 disabled:opacity-50",
						children: [
							activeProfile ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)(ProfileAvatar, {
								avatarKey: activeProfile.avatar_key,
								name: activeProfile.name,
								className: "size-7"
							}) : null,
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
								className: "max-w-36 truncate",
								children: activeProfile?.name ?? "Profile"
							}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)(ChevronDown, { className: "size-4 text-forja-muted" })
						]
					}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(DropdownMenuContent, {
						align: "end",
						className: "w-56",
						children: [
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)(DropdownMenuLabel, { children: "Switch profile" }),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)(DropdownMenuSeparator, {}),
							profiles.map((profile) => {
								const selected = profile.id === activeProfile?.id;
								return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(DropdownMenuItem, {
									onSelect: () => selectProfile(profile.id),
									className: "gap-3 py-2",
									children: [
										/* @__PURE__ */ (0, import_jsx_runtime.jsx)(ProfileAvatar, {
											avatarKey: profile.avatar_key,
											name: profile.name,
											className: "size-8 shrink-0"
										}),
										/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
											className: "min-w-0 flex-1 truncate font-medium",
											children: profile.name
										}),
										selected ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Check, { className: "size-4 shrink-0 text-forja-green" }) : null
									]
								}, profile.id);
							}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)(DropdownMenuSeparator, {}),
							/* @__PURE__ */ (0, import_jsx_runtime.jsx)(DropdownMenuItem, {
								asChild: true,
								children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
									to: "/account/profiles",
									className: "cursor-pointer",
									children: "Manage profiles"
								})
							})
						]
					})] })
				})]
			}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
				className: "grid min-h-[620px] lg:grid-cols-[310px_1fr]",
				children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("aside", {
					className: "border-b border-forja-border py-3 lg:border-b-0 lg:border-r lg:pr-5",
					children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)("nav", {
						className: "grid gap-0 sm:grid-cols-2 lg:grid-cols-1",
						children: categories.map((category) => {
							const selected = pathname === category.href;
							const Icon = category.icon;
							return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Link, {
								to: category.href,
								className: `relative flex min-h-16 items-center gap-4 border-l-[3px] px-3 py-3 ${selected ? "border-forja-green bg-white/[0.035] text-forja-text" : "border-transparent text-forja-muted hover:bg-white/2 hover:text-forja-text"}`,
								children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Icon, { className: `size-[22px] shrink-0 ${selected ? "text-forja-green" : "text-forja-muted"}` }), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("span", {
									className: "min-w-0",
									children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
										className: `block text-sm ${selected ? "font-bold" : "font-medium"}`,
										children: category.title
									}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", {
										className: "mt-0.5 block truncate text-xs text-forja-muted",
										children: category.subtitle
									})]
								})]
							}, category.href);
						})
					})
				}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("section", {
					className: "pt-7 lg:px-10 lg:pt-3",
					children: [
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)("h2", {
							className: "font-display text-3xl tracking-tight",
							children: title
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
							className: "mt-2 max-w-2xl text-sm leading-6 text-forja-muted",
							children: description
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
							className: "mt-9 max-w-2xl",
							children
						}),
						footer ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
							className: "sticky bottom-0 mt-8 max-w-2xl bg-forja-bg/95 py-4 backdrop-blur",
							children: footer
						}) : null
					]
				})]
			})]
		})]
	}) });
}
function useUserSetting(domain) {
	const { user } = useAuth();
	const { activeProfile } = useProfiles();
	const queryClient = useQueryClient();
	const query = useQuery({
		queryKey: [
			"user_setting",
			domain,
			user?.id,
			activeProfile?.id
		],
		enabled: Boolean(user?.id && activeProfile?.id && supabaseConfigured),
		queryFn: async () => {
			const { data, error } = await supabase.from("user_settings").select("payload, updated_at").eq("user_id", user.id).eq("profile_id", activeProfile.id).eq("domain", domain).maybeSingle();
			if (error) throw error;
			return {
				payload: data?.payload ?? {},
				updated_at: data?.updated_at ?? null
			};
		}
	});
	const saveMutation = useMutation({
		mutationFn: async (payload) => {
			if (!activeProfile) throw new Error("Select a profile first");
			const now = (/* @__PURE__ */ new Date()).toISOString();
			const { error } = await supabase.from("user_settings").upsert({
				user_id: user.id,
				profile_id: activeProfile.id,
				domain,
				payload,
				updated_at: now
			});
			if (error) throw error;
			return now;
		},
		onSuccess: () => {
			queryClient.invalidateQueries({ queryKey: [
				"user_settings",
				user?.id,
				activeProfile?.id
			] });
			queryClient.invalidateQueries({ queryKey: [
				"user_setting",
				domain,
				user?.id,
				activeProfile?.id
			] });
		}
	});
	return {
		...query,
		profileId: activeProfile?.id ?? null,
		save: saveMutation.mutateAsync,
		isSaving: saveMutation.isPending,
		saveError: saveMutation.error
	};
}
/** Sync domain payloads - must match Flutter `SyncDomainBridge` export/import. */
var SYNC_DOMAINS = {
	iptv: "iptv",
	preferences: "preferences",
	providers: "providers",
	stremio: "stremio"
};
var DEFAULT_STREAM_PROVIDER_ORDER = [
	"videasy",
	"vidlink",
	"vidsrc",
	"vidsrcwin",
	"vixsrc",
	"vidnest",
	"vidzee",
	"vidrock",
	"vidfast",
	"2embed",
	"autoembed",
	"vidlove",
	"vidsrcsbs",
	"111movies",
	"moviesapi",
	"service111477",
	"webstreamr"
];
var DEFAULT_ANIME_PROVIDER_ORDER = [
	"miruro:bee",
	"allanime:Default",
	"allanime:Yt-mp4",
	"allanime:S-mp4",
	"allanime:Luf-Mp4",
	"vidnest:hianime",
	"vidnest:animepahe",
	"megaplay",
	"vidwish",
	"miruro:zoro",
	"miruro:kiwi",
	"miruro:ally",
	"miruro:hop",
	"miruro:bonk",
	"miruro:moo"
];
var DEFAULT_ASIAN_DRAMA_PROVIDER_ORDER = [
	"kisskh.co",
	"kisskh.nl",
	"kisskh.ovh",
	"kisskh.la",
	"kisskh.do"
];
var MAX_PLAYBACK_HEIGHT_OPTIONS = [
	{
		label: "Auto",
		value: 0
	},
	{
		label: "4K (2160p)",
		value: 2160
	},
	{
		label: "1440p",
		value: 1440
	},
	{
		label: "1080p",
		value: 1080
	},
	{
		label: "720p",
		value: 720
	},
	{
		label: "480p",
		value: 480
	}
];
var AUDIO_LANGUAGE_OPTIONS = [
	"None",
	"English",
	"French",
	"Spanish",
	"German",
	"Italian",
	"Portuguese",
	"Arabic",
	"Japanese",
	"Korean",
	"Chinese"
];
SYNC_DOMAINS.iptv, SYNC_DOMAINS.preferences, SYNC_DOMAINS.providers, SYNC_DOMAINS.stremio;
function portalKey(row) {
	return `${row.url}|${row.username}|${row.password}`.toLowerCase();
}
function emptyIptvPayload() {
	return {
		portals: [],
		favoriteKeys: [],
		m3uPlaylists: []
	};
}
function emptyPreferencesPayload() {
	return {
		play_source_torrent_enabled: true,
		play_source_stremio_enabled: true,
		play_source_webstreaming_enabled: true,
		preferred_audio_lang: "None",
		avoid_unsupported_audio: true,
		auto_next_episode: true,
		auto_skip_intro: false,
		iptv_epg_enabled: true,
		max_playback_height: 0
	};
}
function emptyProvidersPayload() {
	return {
		stream_provider_order: [...DEFAULT_STREAM_PROVIDER_ORDER],
		anime_provider_order: [...DEFAULT_ANIME_PROVIDER_ORDER],
		asian_drama_provider_order: [...DEFAULT_ASIAN_DRAMA_PROVIDER_ORDER]
	};
}
function emptyStremioPayload() {
	return { addons: [] };
}
//#endregion
export { emptyIptvPayload as a, emptyStremioPayload as c, SYNC_DOMAINS as i, portalKey as l, AccountSettingsShell as n, emptyPreferencesPayload as o, MAX_PLAYBACK_HEIGHT_OPTIONS as r, emptyProvidersPayload as s, AUDIO_LANGUAGE_OPTIONS as t, useUserSetting as u };
