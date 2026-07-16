import { r as __toESM } from "../_runtime.mjs";
import { n as require_react } from "../_libs/@radix-ui/react-compose-refs+[...].mjs";
import { i as require_jsx_runtime } from "../_libs/@radix-ui/react-label+[...].mjs";
import { r as cn } from "./site-header-CQxqjJmj.mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/reveal-C110PiPA.js
var import_react = /* @__PURE__ */ __toESM(require_react());
var import_jsx_runtime = require_jsx_runtime();
function Reveal({ children, className = "", delayMs = 0, variant = "up" }) {
	const ref = (0, import_react.useRef)(null);
	(0, import_react.useEffect)(() => {
		const el = ref.current;
		if (!el) return;
		if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
			el.classList.add("is-visible");
			return;
		}
		const observer = new IntersectionObserver(([entry]) => {
			if (entry.isIntersecting) {
				el.classList.add("is-visible");
				observer.unobserve(el);
			}
		}, {
			threshold: .12,
			rootMargin: "0px 0px -10% 0px"
		});
		observer.observe(el);
		return () => observer.disconnect();
	}, []);
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
		ref,
		className: cn("reveal", `reveal-${variant}`, className),
		style: delayMs ? { transitionDelay: `${delayMs}ms` } : void 0,
		children
	});
}
//#endregion
export { Reveal as t };
