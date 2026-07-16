import { i as require_jsx_runtime } from "../_libs/@radix-ui/react-label+[...].mjs";
import { i as useAuth, n as supabase, r as supabaseConfigured } from "./use-auth-xp43OQr8.mjs";
import { i as useQueryClient, n as useQuery, t as useMutation } from "../_libs/tanstack__react-query.mjs";
import { n as useProfiles } from "./use-profiles-V2uJTVXk.mjs";
import { a as useRouterState, f as Link } from "../_libs/@tanstack/react-router+[...].mjs";
import { t as RequireAuth } from "./require-auth-DtXzK_my.mjs";
import { n as SiteHeader } from "./site-header-CQxqjJmj.mjs";
import { d as ListOrdered, f as CirclePlay, g as ArrowLeft, o as Radio, s as Puzzle, t as Users } from "../_libs/lucide-react.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/sync-domains-_br4J9hJ.js
var import_jsx_runtime = require_jsx_runtime();
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
		subtitle: "Stream and mirror priority",
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
				}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
					className: "flex items-center gap-2 border-b border-forja-border pb-1",
					children: [
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Users, { className: "size-4 text-forja-green" }),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)("select", {
							"aria-label": "Active profile",
							className: "min-w-32 bg-transparent py-1 text-sm font-semibold outline-none",
							value: activeProfile?.id ?? "",
							disabled: profilesLoading || profiles.length === 0,
							onChange: (event) => selectProfile(event.target.value),
							children: profiles.map((profile) => /* @__PURE__ */ (0, import_jsx_runtime.jsx)("option", {
								value: profile.id,
								children: profile.name
							}, profile.id))
						}),
						/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
							to: "/account/profiles",
							className: "px-1 text-xs text-forja-muted hover:text-forja-green",
							children: "Manage"
						})
					]
				})]
			}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
				className: "grid min-h-[620px] border-t border-forja-border lg:grid-cols-[310px_1fr]",
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
							className: "sticky bottom-0 mt-8 max-w-2xl border-t border-forja-border bg-forja-bg/95 py-4 backdrop-blur",
							children: footer
						}) : null
					]
				})]
			})]
		})]
	}) });
}
function SettingsSection({ label, description, children }) {
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("section", {
		className: "mb-10",
		children: [
			/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
				className: "mb-1 flex items-center gap-2.5",
				children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("span", { className: "h-0.5 w-3.5 bg-forja-green" }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("h3", {
					className: "text-[11px] font-bold uppercase tracking-[0.16em] text-forja-green",
					children: label
				})]
			}),
			description ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
				className: "mb-3 ml-6 text-xs leading-5 text-forja-muted",
				children: description
			}) : null,
			/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
				className: "divide-y divide-forja-border",
				children
			})
		]
	});
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
/** Sync domain payloads — must match Flutter `SyncDomainBridge` export/import. */
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
export { SettingsSection as a, emptyProvidersPayload as c, useUserSetting as d, SYNC_DOMAINS as i, emptyStremioPayload as l, AccountSettingsShell as n, emptyIptvPayload as o, MAX_PLAYBACK_HEIGHT_OPTIONS as r, emptyPreferencesPayload as s, AUDIO_LANGUAGE_OPTIONS as t, portalKey as u };
