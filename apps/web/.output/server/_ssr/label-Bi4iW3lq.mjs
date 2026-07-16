import { r as __toESM } from "../_runtime.mjs";
import { n as require_react } from "../_libs/@radix-ui/react-compose-refs+[...].mjs";
import { a as require_jsx_runtime, t as Root } from "../_libs/@radix-ui/react-label+[...].mjs";
import { r as cn } from "./site-header-D6GWurdS.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/label-Bi4iW3lq.js
var import_react = /* @__PURE__ */ __toESM(require_react());
var import_jsx_runtime = require_jsx_runtime();
var Input = import_react.forwardRef(({ className, type, ...props }, ref) => /* @__PURE__ */ (0, import_jsx_runtime.jsx)("input", {
	type,
	className: cn("flex h-10 w-full rounded-md border border-forja-border bg-forja-surface px-3 py-2 text-sm text-forja-text placeholder:text-forja-muted focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-forja-green/50 disabled:cursor-not-allowed disabled:opacity-50", className),
	ref,
	...props
}));
Input.displayName = "Input";
var Label = import_react.forwardRef(({ className, ...props }, ref) => /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Root, {
	ref,
	className: cn("text-sm font-medium text-forja-muted", className),
	...props
}));
Label.displayName = Root.displayName;
//#endregion
export { Label as n, Input as t };
