import { r as __toESM } from "../_runtime.mjs";
import { n as require_react } from "../_libs/@radix-ui/react-compose-refs+[...].mjs";
import { i as require_jsx_runtime } from "../_libs/@radix-ui/react-label+[...].mjs";
import { i as useAuth, n as supabase, r as supabaseConfigured } from "./use-auth-xp43OQr8.mjs";
import { i as useQueryClient, n as useQuery, t as useMutation } from "../_libs/tanstack__react-query.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/use-profiles-V2uJTVXk.js
var import_react = /* @__PURE__ */ __toESM(require_react());
var import_jsx_runtime = require_jsx_runtime();
var PROFILE_COLORS = [
	"#1ce783",
	"#ff4d1c",
	"#5aa9ff",
	"#c084fc",
	"#facc15",
	"#fb7185"
];
var ProfilesContext = (0, import_react.createContext)(null);
function storageKey(userId) {
	return `forja.active-profile.${userId}`;
}
function ProfilesProvider({ children }) {
	const { user } = useAuth();
	const queryClient = useQueryClient();
	const [activeProfileId, setActiveProfileId] = (0, import_react.useState)(null);
	const profilesQuery = useQuery({
		queryKey: ["profiles", user?.id],
		enabled: Boolean(user?.id && supabaseConfigured),
		queryFn: async () => {
			const { data, error } = await supabase.from("profiles").select("*").eq("user_id", user.id).order("created_at");
			if (error) throw error;
			return data ?? [];
		}
	});
	const profiles = profilesQuery.data ?? [];
	(0, import_react.useEffect)(() => {
		if (!user) {
			setActiveProfileId(null);
			return;
		}
		if (profiles.length === 0) return;
		const saved = window.localStorage.getItem(storageKey(user.id));
		const next = saved && profiles.some((profile) => profile.id === saved) && saved || profiles[0].id;
		setActiveProfileId(next);
		window.localStorage.setItem(storageKey(user.id), next);
	}, [profiles, user]);
	const selectProfile = (profileId) => {
		if (!user || !profiles.some((profile) => profile.id === profileId)) return;
		setActiveProfileId(profileId);
		window.localStorage.setItem(storageKey(user.id), profileId);
	};
	const createMutation = useMutation({
		mutationFn: async (name) => {
			const cleanName = name.trim();
			if (!user || !cleanName) throw new Error("Enter a profile name");
			const color = PROFILE_COLORS[profiles.length % PROFILE_COLORS.length];
			const { data, error } = await supabase.from("profiles").insert({
				user_id: user.id,
				name: cleanName,
				color
			}).select("*").single();
			if (error) throw error;
			return data;
		},
		onSuccess: (profile) => {
			queryClient.invalidateQueries({ queryKey: ["profiles", user?.id] });
			setActiveProfileId(profile.id);
			if (user) window.localStorage.setItem(storageKey(user.id), profile.id);
		}
	});
	const renameMutation = useMutation({
		mutationFn: async ({ profileId, name }) => {
			const cleanName = name.trim();
			if (!user || !cleanName) throw new Error("Enter a profile name");
			const { error } = await supabase.from("profiles").update({
				name: cleanName,
				updated_at: (/* @__PURE__ */ new Date()).toISOString()
			}).eq("id", profileId).eq("user_id", user.id);
			if (error) throw error;
		},
		onSuccess: () => {
			queryClient.invalidateQueries({ queryKey: ["profiles", user?.id] });
		}
	});
	const deleteMutation = useMutation({
		mutationFn: async (profileId) => {
			if (!user) return;
			if (profiles.length <= 1) throw new Error("Every account needs one profile");
			const { error } = await supabase.from("profiles").delete().eq("id", profileId).eq("user_id", user.id);
			if (error) throw error;
		},
		onSuccess: (_, deletedId) => {
			if (activeProfileId === deletedId && user) {
				const next = profiles.find((profile) => profile.id !== deletedId);
				setActiveProfileId(next?.id ?? null);
				if (next) window.localStorage.setItem(storageKey(user.id), next.id);
			}
			queryClient.invalidateQueries({ queryKey: ["profiles", user?.id] });
		}
	});
	const activeProfile = profiles.find((profile) => profile.id === activeProfileId) ?? profiles[0] ?? null;
	const value = (0, import_react.useMemo)(() => ({
		profiles,
		activeProfile,
		loading: profilesQuery.isLoading,
		error: profilesQuery.error instanceof Error ? profilesQuery.error : profilesQuery.error ? /* @__PURE__ */ new Error("Failed to load profiles") : null,
		selectProfile,
		createProfile: createMutation.mutateAsync,
		renameProfile: async (profileId, name) => {
			await renameMutation.mutateAsync({
				profileId,
				name
			});
		},
		deleteProfile: deleteMutation.mutateAsync,
		creating: createMutation.isPending
	}), [
		profiles,
		activeProfile,
		profilesQuery.isLoading,
		profilesQuery.error,
		createMutation.mutateAsync,
		createMutation.isPending,
		renameMutation.mutateAsync,
		deleteMutation.mutateAsync
	]);
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)(ProfilesContext.Provider, {
		value,
		children
	});
}
function useProfiles() {
	const context = (0, import_react.useContext)(ProfilesContext);
	if (!context) throw new Error("useProfiles must be used within ProfilesProvider");
	return context;
}
//#endregion
export { useProfiles as n, ProfilesProvider as t };
