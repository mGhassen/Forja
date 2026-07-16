import { a as require_jsx_runtime } from "../_libs/@radix-ui/react-label+[...].mjs";
import { i as useAuth, n as supabase, r as supabaseConfigured } from "./use-auth-xp43OQr8.mjs";
import { f as Link } from "../_libs/@tanstack/react-router+[...].mjs";
import { n as SiteHeader } from "./site-header-CQxqjJmj.mjs";
import { t as Button } from "./card-BLl6aleQ.mjs";
import { t as RequireAuth } from "./require-auth-DtXzK_my.mjs";
import { i as useQueryClient, n as useQuery, t as useMutation } from "../_libs/tanstack__react-query.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/sync-domains-C0TgAES7.js
var import_jsx_runtime = require_jsx_runtime();
function AccountSettingsShell({ title, description, backTo = "/account/settings", backLabel = "← All settings", children, footer }) {
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)(RequireAuth, { children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
		className: "min-h-screen",
		children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(SiteHeader, { solid: true }), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("main", {
			className: "mx-auto max-w-2xl px-5 pb-16 pt-24 sm:px-6 sm:pt-28",
			children: [
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Button, {
					asChild: true,
					variant: "ghost",
					size: "sm",
					className: "-ml-2 mb-6",
					children: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
						to: backTo,
						children: backLabel
					})
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
					className: "font-display text-sm uppercase tracking-[0.3em] text-forja-green",
					children: "Cloud settings"
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("h1", {
					className: "mt-3 font-display text-3xl tracking-tight sm:text-4xl",
					children: title
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
					className: "mt-4 text-forja-muted",
					children: description
				}),
				/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
					className: "mt-10 space-y-6",
					children
				}),
				footer ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
					className: "mt-8",
					children: footer
				}) : null
			]
		})]
	}) });
}
function useUserSettings() {
	const { user } = useAuth();
	return useQuery({
		queryKey: ["user_settings", user?.id],
		enabled: Boolean(user?.id && supabaseConfigured),
		queryFn: async () => {
			const { data, error } = await supabase.from("user_settings").select("domain, payload, updated_at").eq("user_id", user.id).order("domain");
			if (error) throw error;
			return data ?? [];
		}
	});
}
function useUserSetting(domain) {
	const { user } = useAuth();
	const queryClient = useQueryClient();
	const query = useQuery({
		queryKey: [
			"user_setting",
			domain,
			user?.id
		],
		enabled: Boolean(user?.id && supabaseConfigured),
		queryFn: async () => {
			const { data, error } = await supabase.from("user_settings").select("payload, updated_at").eq("user_id", user.id).eq("domain", domain).maybeSingle();
			if (error) throw error;
			return {
				payload: data?.payload ?? {},
				updated_at: data?.updated_at ?? null
			};
		}
	});
	const saveMutation = useMutation({
		mutationFn: async (payload) => {
			const now = (/* @__PURE__ */ new Date()).toISOString();
			const { error } = await supabase.from("user_settings").upsert({
				user_id: user.id,
				domain,
				payload,
				updated_at: now
			});
			if (error) throw error;
			return now;
		},
		onSuccess: (updatedAt) => {
			queryClient.invalidateQueries({ queryKey: ["user_settings", user?.id] });
			queryClient.setQueryData([
				"user_setting",
				domain,
				user?.id
			], (prev) => ({
				payload: prev?.payload ?? {},
				updated_at: updatedAt
			}));
			queryClient.invalidateQueries({ queryKey: [
				"user_setting",
				domain,
				user?.id
			] });
		}
	});
	return {
		...query,
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
var REMOTE_SETTING_SECTIONS = [
	{
		domain: SYNC_DOMAINS.iptv,
		title: "IPTV portals",
		description: "Xtream portals and M3U playlists — synced to every signed-in device.",
		href: "/account/settings/iptv"
	},
	{
		domain: SYNC_DOMAINS.preferences,
		title: "Playback",
		description: "Play sources, auto next episode, audio language, and quality cap.",
		href: "/account/settings/playback"
	},
	{
		domain: SYNC_DOMAINS.providers,
		title: "Provider order",
		description: "Priority for web streams, anime mirrors, and Asian drama hosts.",
		href: "/account/settings/providers"
	},
	{
		domain: SYNC_DOMAINS.stremio,
		title: "Stremio addons",
		description: "Addon manifest URLs installed on your account.",
		href: "/account/settings/stremio"
	}
];
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
export { SYNC_DOMAINS as a, emptyProvidersPayload as c, useUserSetting as d, useUserSettings as f, REMOTE_SETTING_SECTIONS as i, emptyStremioPayload as l, AccountSettingsShell as n, emptyIptvPayload as o, MAX_PLAYBACK_HEIGHT_OPTIONS as r, emptyPreferencesPayload as s, AUDIO_LANGUAGE_OPTIONS as t, portalKey as u };
