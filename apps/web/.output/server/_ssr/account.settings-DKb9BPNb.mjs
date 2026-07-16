import { s as require_jsx_runtime } from "../_libs/@radix-ui/react-arrow+[...].mjs";
import { a as useRouterState, c as Outlet, p as Navigate } from "../_libs/@tanstack/react-router+[...].mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/account.settings-DKb9BPNb.js
var import_jsx_runtime = require_jsx_runtime();
function AccountSettingsPage() {
	const pathname = useRouterState({ select: (state) => state.location.pathname });
	if (pathname !== "/account/settings" && pathname !== "/account/settings/") return /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Outlet, {});
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Navigate, {
		to: "/account/settings/playback",
		replace: true
	});
}
var SplitComponent = AccountSettingsPage;
//#endregion
export { SplitComponent as component };
