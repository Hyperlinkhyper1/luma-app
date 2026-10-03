export function sendHostMessage(data, host = globalThis.chrome?.webview) {
  try { host?.postMessage(JSON.stringify(data)); } catch {}
}

export function captureMouse(canvas, unavailable) {
  canvas.focus({ preventScroll: true });
  try {
    if (!canvas.requestPointerLock) { unavailable(); return; }
    canvas.requestPointerLock()?.catch?.(unavailable);
  } catch { unavailable(); }
}
