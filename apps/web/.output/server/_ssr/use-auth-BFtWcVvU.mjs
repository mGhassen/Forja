import { r as __toESM } from "../_runtime.mjs";
import { n as require_react } from "../_libs/@radix-ui/react-compose-refs+[...].mjs";
import { i as require_jsx_runtime } from "../_libs/@radix-ui/react-primitive+[...].mjs";
import { t as createClient } from "../_libs/supabase__supabase-js.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/use-auth-BFtWcVvU.js
var import_react = /* @__PURE__ */ __toESM(require_react());
var import_jsx_runtime = require_jsx_runtime();
var url = "https://your-project.supabase.co";
var anonKey = "your-anon-key";
var looksLikePlaceholder = url.includes("your-project") || true;
/** True only when real project credentials are present (not .env.example placeholders). */
var supabaseConfigured = !looksLikePlaceholder;
var supabase = createClient(looksLikePlaceholder ? "https://placeholder.supabase.co" : url, looksLikePlaceholder ? "placeholder" : anonKey);
var AuthContext = (0, import_react.createContext)(null);
function AuthProvider({ children }) {
	const [session, setSession] = (0, import_react.useState)(null);
	const [loading, setLoading] = (0, import_react.useState)(true);
	(0, import_react.useEffect)(() => {
		if (!supabaseConfigured) {
			setLoading(false);
			return;
		}
		let mounted = true;
		supabase.auth.getSession().then(({ data }) => {
			if (mounted) {
				setSession(data.session);
				setLoading(false);
			}
		});
		const { data: sub } = supabase.auth.onAuthStateChange((_event, next) => {
			setSession(next);
			setLoading(false);
		});
		return () => {
			mounted = false;
			sub.subscription.unsubscribe();
		};
	}, []);
	const signIn = (0, import_react.useCallback)(async (email, password) => {
		if (!supabaseConfigured) return { error: "Supabase is not configured. Set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY." };
		const { error } = await supabase.auth.signInWithPassword({
			email,
			password
		});
		return { error: error?.message ?? null };
	}, []);
	const signUp = (0, import_react.useCallback)(async (email, password) => {
		if (!supabaseConfigured) return { error: "Supabase is not configured. Set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY." };
		const { error } = await supabase.auth.signUp({
			email,
			password
		});
		return { error: error?.message ?? null };
	}, []);
	const signOut = (0, import_react.useCallback)(async () => {
		if (!supabaseConfigured) return;
		await supabase.auth.signOut();
	}, []);
	const value = (0, import_react.useMemo)(() => ({
		session,
		user: session?.user ?? null,
		loading,
		configured: supabaseConfigured,
		signIn,
		signUp,
		signOut
	}), [
		session,
		loading,
		signIn,
		signUp,
		signOut
	]);
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)(AuthContext.Provider, {
		value,
		children
	});
}
function useAuth() {
	const ctx = (0, import_react.useContext)(AuthContext);
	if (!ctx) throw new Error("useAuth must be used within AuthProvider");
	return ctx;
}
//#endregion
export { useAuth as i, supabase as n, supabaseConfigured as r, AuthProvider as t };
