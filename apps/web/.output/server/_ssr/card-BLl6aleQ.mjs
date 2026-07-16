import { r as __toESM } from "../_runtime.mjs";
import { n as require_react } from "../_libs/@radix-ui/react-compose-refs+[...].mjs";
import { a as require_jsx_runtime, r as Slot } from "../_libs/@radix-ui/react-label+[...].mjs";
import { t as cva } from "../_libs/class-variance-authority+clsx.mjs";
import { r as cn } from "./site-header-CQxqjJmj.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/card-BLl6aleQ.js
var import_react = /* @__PURE__ */ __toESM(require_react());
var import_jsx_runtime = require_jsx_runtime();
var buttonVariants = cva("inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-md text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-forja-green/60 disabled:pointer-events-none disabled:opacity-50", {
	variants: {
		variant: {
			default: "bg-forja-green text-[#0B0A0A] hover:bg-forja-flame",
			secondary: "bg-forja-elevated text-forja-text border border-forja-border hover:border-forja-green/40",
			ghost: "text-forja-text hover:bg-white/5",
			outline: "border border-forja-border bg-transparent hover:border-forja-green/50 hover:text-forja-green"
		},
		size: {
			default: "h-10 px-4 py-2",
			sm: "h-8 rounded-md px-3 text-xs",
			lg: "h-12 rounded-md px-8 text-base",
			icon: "h-10 w-10"
		}
	},
	defaultVariants: {
		variant: "default",
		size: "default"
	}
});
var Button = import_react.forwardRef(({ className, variant, size, asChild = false, ...props }, ref) => {
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)(asChild ? Slot : "button", {
		className: cn(buttonVariants({
			variant,
			size,
			className
		})),
		ref,
		...props
	});
});
Button.displayName = "Button";
function Card({ className, ...props }) {
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
		className: cn("rounded-xl border border-forja-border bg-forja-surface text-forja-text shadow-sm", className),
		...props
	});
}
function CardHeader({ className, ...props }) {
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
		className: cn("flex flex-col gap-1.5 p-6", className),
		...props
	});
}
function CardTitle({ className, ...props }) {
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("h3", {
		className: cn("font-display text-xl font-semibold tracking-tight", className),
		...props
	});
}
function CardDescription({ className, ...props }) {
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("p", {
		className: cn("text-sm text-forja-muted", className),
		...props
	});
}
function CardContent({ className, ...props }) {
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
		className: cn("p-6 pt-0", className),
		...props
	});
}
//#endregion
export { CardHeader as a, CardDescription as i, Card as n, CardTitle as o, CardContent as r, Button as t };
