import { r as __toESM } from "../_runtime.mjs";
import { n as require_react } from "../_libs/@radix-ui/react-compose-refs+[...].mjs";
import { a as require_jsx_runtime } from "../_libs/@radix-ui/react-label+[...].mjs";
import { i as useAuth } from "./use-auth-BFtWcVvU.mjs";
import { f as Link, m as useNavigate } from "../_libs/@tanstack/react-router+[...].mjs";
import { n as SiteHeader } from "./site-header-D6GWurdS.mjs";
import { a as CardHeader, i as CardDescription, n as Card, o as CardTitle, r as CardContent, t as Button } from "./card-CmGbaTHK.mjs";
import { n as Label, t as Input } from "./label-Bi4iW3lq.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/signup-DziQYCvU.js
var import_react = /* @__PURE__ */ __toESM(require_react());
var import_jsx_runtime = require_jsx_runtime();
function SignupPage() {
	const { signUp } = useAuth();
	const navigate = useNavigate();
	const [email, setEmail] = (0, import_react.useState)("");
	const [password, setPassword] = (0, import_react.useState)("");
	const [error, setError] = (0, import_react.useState)(null);
	const [message, setMessage] = (0, import_react.useState)(null);
	const [pending, setPending] = (0, import_react.useState)(false);
	async function onSubmit(e) {
		e.preventDefault();
		setPending(true);
		setError(null);
		setMessage(null);
		const result = await signUp(email.trim(), password);
		setPending(false);
		if (result.error) {
			setError(result.error);
			return;
		}
		setMessage("Account ready. Confirm by email if asked, then log in.");
		navigate({ to: "/account" });
	}
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("div", {
		className: "min-h-screen",
		children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(SiteHeader, { solid: true }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("main", {
			className: "mx-auto flex max-w-md flex-col px-5 pb-16 pt-24 sm:px-6 sm:pt-28",
			children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(Card, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)(CardHeader, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)(CardTitle, { children: "Account" }), /* @__PURE__ */ (0, import_jsx_runtime.jsx)(CardDescription, { children: "Optional — syncs settings across Forja devices." })] }), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(CardContent, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsxs)("form", {
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
							autoComplete: "new-password",
							required: true,
							minLength: 8,
							value: password,
							onChange: (e) => setPassword(e.target.value)
						})]
					}),
					error && /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
						className: "text-sm text-red-300",
						children: error
					}),
					message && /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
						className: "text-sm text-forja-green",
						children: message
					}),
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Button, {
						type: "submit",
						className: "w-full",
						disabled: pending,
						children: pending ? "Saving…" : "Continue"
					})
				]
			}), /* @__PURE__ */ (0, import_jsx_runtime.jsxs)("p", {
				className: "mt-4 text-center text-sm text-forja-muted",
				children: [
					"Already registered?",
					" ",
					/* @__PURE__ */ (0, import_jsx_runtime.jsx)(Link, {
						to: "/login",
						className: "text-forja-green hover:underline",
						children: "Log in"
					})
				]
			})] })] })
		})]
	});
}
var SplitComponent = SignupPage;
//#endregion
export { SplitComponent as component };
