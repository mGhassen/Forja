import { r as __toESM } from "../_runtime.mjs";
import { n as require_react } from "../_libs/@radix-ui/react-compose-refs+[...].mjs";
import { i as require_jsx_runtime } from "../_libs/@radix-ui/react-primitive+[...].mjs";
//#region node_modules/.nitro/vite/services/ssr/assets/reveal-DOvxdxVG.js
var import_react = /* @__PURE__ */ __toESM(require_react());
var import_jsx_runtime = require_jsx_runtime();
/** Difference-blend custom cursor (fine pointer + motion OK only). */
function CustomCursor() {
	const dotRef = (0, import_react.useRef)(null);
	const ringRef = (0, import_react.useRef)(null);
	(0, import_react.useEffect)(() => {
		const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
		if (!window.matchMedia("(hover: hover) and (pointer: fine)").matches || reduced) return;
		document.body.classList.add("cursor-on");
		const dot = dotRef.current;
		const ring = ringRef.current;
		if (!dot || !ring) return;
		let mx = window.innerWidth / 2;
		let my = window.innerHeight / 2;
		let rx = mx;
		let ry = my;
		let raf = 0;
		const onMove = (e) => {
			mx = e.clientX;
			my = e.clientY;
			dot.style.left = `${mx}px`;
			dot.style.top = `${my}px`;
		};
		const loop = () => {
			rx += (mx - rx) * .18;
			ry += (my - ry) * .18;
			ring.style.left = `${rx}px`;
			ring.style.top = `${ry}px`;
			raf = requestAnimationFrame(loop);
		};
		const onEnter = () => ring.classList.add("big");
		const onLeave = () => ring.classList.remove("big");
		window.addEventListener("mousemove", onMove);
		raf = requestAnimationFrame(loop);
		const bindHoverables = () => {
			document.querySelectorAll("a, button, [data-hover]").forEach((el) => {
				el.addEventListener("mouseenter", onEnter);
				el.addEventListener("mouseleave", onLeave);
			});
		};
		bindHoverables();
		const mo = new MutationObserver(bindHoverables);
		mo.observe(document.body, {
			childList: true,
			subtree: true
		});
		return () => {
			document.body.classList.remove("cursor-on");
			window.removeEventListener("mousemove", onMove);
			cancelAnimationFrame(raf);
			mo.disconnect();
			document.querySelectorAll("a, button, [data-hover]").forEach((el) => {
				el.removeEventListener("mouseenter", onEnter);
				el.removeEventListener("mouseleave", onLeave);
			});
		};
	}, []);
	return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(import_jsx_runtime.Fragment, { children: [/* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
		ref: dotRef,
		className: "cur-dot",
		"aria-hidden": true
	}), /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
		ref: ringRef,
		className: "cur-ring",
		"aria-hidden": true
	})] });
}
function Reveal({ children, className = "", delayMs = 0 }) {
	const ref = (0, import_react.useRef)(null);
	(0, import_react.useEffect)(() => {
		const el = ref.current;
		if (!el) return;
		const observer = new IntersectionObserver(([entry]) => {
			if (entry.isIntersecting) {
				el.classList.add("is-visible");
				observer.unobserve(el);
			}
		}, {
			threshold: .16,
			rootMargin: "0px 0px -8% 0px"
		});
		observer.observe(el);
		return () => observer.disconnect();
	}, []);
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)("div", {
		ref,
		className: `reveal ${className}`,
		style: delayMs ? { transitionDelay: `${delayMs}ms` } : void 0,
		children
	});
}
//#endregion
export { Reveal as n, CustomCursor as t };
