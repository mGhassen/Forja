import { r as __toESM } from "../_runtime.mjs";
import { n as require_react } from "../_libs/@radix-ui/react-compose-refs+[...].mjs";
import { a as require_jsx_runtime } from "../_libs/@radix-ui/react-label+[...].mjs";
import { i as useAuth } from "./use-auth-BFtWcVvU.mjs";
import { f as Link, m as useNavigate } from "../_libs/@tanstack/react-router+[...].mjs";
import { n as SiteHeader } from "./site-header-D6GWurdS.mjs";
import { a as CardHeader, i as CardDescription, n as Card, o as CardTitle, r as CardContent, t as Button } from "./card-CmGbaTHK.mjs";
import { n as Label, t as Input } from "./label-Bi4iW3lq.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/login-Dcn_txwg.js
var import_react = /* @__PURE__ */ __toESM(require_react());
var import_jsx_runtime = require_jsx_runtime();
function LoginPage() {
	const { signIn } = useAuth();
	const navigate = useNavigate();
	const [email, setEmail] = (0, import_react.useState)("");
	const [password, setPassword] = (0, import_react.useState)("");
	const [error, setError] = (0, import_react.useState)(null);
	const [pending, setPending] = (0, import_react.useState)(false);
	async function onSubmit(e) {
		e.preventDefault();
		setPending(true);
		setError(null);
		const result = await signIn(email.trim(), password);
		setPending(false);
		if (result.error) {
			setError(result.error);
			return;
		}
		navigate({ to: "/account" });
	}
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
		className: "min-h-screen",
		children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(SiteHeader, { solid: true }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("main", {
			className: "mx-auto flex max-w-md flex-col px-5 pb-16 pt-24 sm:px-6 sm:pt-28",
			children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Card, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(CardHeader, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(CardTitle, { children: "Log in" }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(CardDescription, { children: "Same account as the Forja desktop and mobile apps." })] }), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(CardContent, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("form", {
				className: "space-y-4",
				onSubmit,
				children: [
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
						className: "space-y-2",
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Label, {
							htmlFor: "email",
							children: "Email"
						}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Input, {
							id: "email",
							type: "email",
							autoComplete: "email",
							required: true,
							value: email,
							onChange: (e) => setEmail(e.target.value)
						})]
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
						className: "space-y-2",
						children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Label, {
							htmlFor: "password",
							children: "Password"
						}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Input, {
							id: "password",
							type: "password",
							autoComplete: "current-password",
							required: true,
							value: password,
							onChange: (e) => setPassword(e.target.value)
						})]
					}),
					error && /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
						className: "text-sm text-red-300",
						children: error
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Button, {
						type: "submit",
						className: "w-full",
						disabled: pending,
						children: pending ? "Logging in…" : "Log in"
					})
				]
			}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", {
				className: "mt-4 text-center text-sm text-forja-muted",
				children: [
					"No account yet?",
					" ",
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
						to: "/signup",
						className: "text-forja-green hover:underline",
						children: "Account"
					})
				]
			})] })] })
		})]
	});
}
var SplitComponent = LoginPage;
//#endregion
export { SplitComponent as component };
