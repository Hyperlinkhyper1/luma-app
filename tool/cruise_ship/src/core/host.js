// Messages to the luma app when the scene runs inside its WebView2 host
// (`NativeWebview`): it waits for `cruise-ready` and shows its own error
// panel with a Retry button on `cruise-error`. In a plain browser there is
// no host and these are no-ops.

export function tellHost(type, extra = {}) {
  try { globalThis.chrome?.webview?.postMessage(JSON.stringify({ type, ...extra })); } catch {}
}
