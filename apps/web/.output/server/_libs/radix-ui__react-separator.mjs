import { r as __toESM } from "../_runtime.mjs";
import { n as require_react } from "./@radix-ui/react-compose-refs+[...].mjs";
import { a as require_jsx_runtime, n as Primitive } from "./@radix-ui/react-label+[...].mjs";
//#region node_modules/.pnpm/@radix-ui+react-separator@1.1.11_@types+react-dom@19.2.3_@types+react@19.2.17__@types+r_c37f49cb46d48299c6ae5b33c74ee195/node_modules/@radix-ui/react-separator/dist/index.mjs
var import_react = /* @__PURE__ */ __toESM(require_react(), 1);
var import_jsx_runtime = require_jsx_runtime();
var NAME = "Separator";
var DEFAULT_ORIENTATION = "horizontal";
var ORIENTATIONS = ["horizontal", "vertical"];
var Separator = import_react.forwardRef((props, forwardedRef) => {
	const { decorative, orientation: orientationProp = DEFAULT_ORIENTATION, ...domProps } = props;
	const orientation = isValidOrientation(orientationProp) ? orientationProp : DEFAULT_ORIENTATION;
	const semanticProps = decorative ? { role: "none" } : {
		"aria-orientation": orientation === "vertical" ? orientation : void 0,
		role: "separator"
	};
	return /* @__PURE__ */ (0, import_jsx_runtime.jsx)(Primitive.div, {
		"data-orientation": orientation,
		...semanticProps,
		...domProps,
		ref: forwardedRef
	});
});
Separator.displayName = NAME;
function isValidOrientation(orientation) {
	return ORIENTATIONS.includes(orientation);
}
var Root = Separator;
//#endregion
export { Root as t };
