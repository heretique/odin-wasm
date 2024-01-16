import * as wasm from "../wasm/runtime.js"

import {IS_DEV, WEB_SOCKET_PORT, MESSAGE_RELOAD, WASM_FILENAME} from "./_config.js"

// eslint-disable-next-line @typescript-eslint/no-unused-vars
import * as t from "./types.js"

if (IS_DEV) {
	wasm.enableConsole()

	/* Hot Reload */
	new WebSocket("ws://localhost:" + WEB_SOCKET_PORT).addEventListener(
		"message",
		event => event.data === MESSAGE_RELOAD && location.reload(),
	)
}

const wasm_state = wasm.makeWasmState()
const webgl_state = wasm.webgl.makeWebGLState()

const src_instance = await wasm.fetchInstanciateWasm(WASM_FILENAME, {
	env: {}, // TODO
	odin_env: wasm.env.makeOdinEnv(wasm_state),
	odin_ls: wasm.ls.makeOdinLS(wasm_state),
	odin_dom: wasm.dom.makeOdinDOM(wasm_state),
	webgl: wasm.webgl.makeOdinWebGL(webgl_state, wasm_state),
})

wasm.initWasmState(wasm_state, src_instance)
const exports = /** @type {t.WasmExports} */ (wasm_state.exports)

exports._start()
const odin_ctx = exports.default_context_ptr()
exports._end()

void requestAnimationFrame(prev_time => {
	/** @type {FrameRequestCallback} */
	const frame = time => {
		const delta = time - prev_time
		prev_time = time
		exports.frame(delta, odin_ctx)
		void requestAnimationFrame(frame)
	}

	void requestAnimationFrame(frame)
})

const canvas = /** @type {HTMLCanvasElement} */ (document.getElementById("canvas"))
const dpr = window.devicePixelRatio || 1

function updateCanvasSize() {
	const rect = canvas.getBoundingClientRect()
	canvas.width = rect.width * dpr
	canvas.height = rect.height * dpr
	exports.on_window_resize(
		window.innerWidth,
		window.innerHeight,
		rect.width,
		rect.height,
		rect.left,
		rect.top,
	)
}
updateCanvasSize()
window.addEventListener("resize", updateCanvasSize)

/* To test dispatching custom events */
document.body.addEventListener("lol", () => {
	// eslint-disable-next-line no-console
	console.log("lol event has been received")
})
