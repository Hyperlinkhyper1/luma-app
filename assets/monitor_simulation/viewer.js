'use strict';

const discover = document.getElementById('discover');
const devices = document.getElementById('devices');
const start = document.getElementById('start');
const expand = document.getElementById('expand');
const stop = document.getElementById('stop');
const status = document.getElementById('status');
const video = document.getElementById('video');
const placeholder = document.getElementById('placeholder');
let stream = null;
let probeStream = null;
let requestGeneration = 0;
let busy = false;

function stopTracks(activeStream) {
  if (activeStream) {
    activeStream.getTracks().forEach(track => {
      if (track.readyState !== 'ended') track.stop();
    });
  }
}

function updateControls() {
  discover.disabled = busy;
  devices.disabled = busy || devices.options.length === 0;
  start.disabled = busy || devices.options.length === 0 || !!stream;
  expand.disabled = busy || !stream;
  stop.disabled = !busy && !stream;
}

function release() {
  requestGeneration++;
  if (document.fullscreenElement) document.exitFullscreen().catch(() => {});
  stopTracks(stream);
  stopTracks(probeStream);
  stream = null;
  probeStream = null;
  video.srcObject = null;
  placeholder.hidden = false;
  busy = false;
  updateControls();
}

function fail(error) {
  if (error.name === 'NotAllowedError' || error.name === 'SecurityError') {
    status.textContent = 'Camera access was denied. Allow camera access in Windows Settings, then try again.';
  } else if (error.name === 'NotFoundError' || error.name === 'OverconstrainedError') {
    status.textContent = 'That video input is unavailable. Reconnect the capture device and find inputs again.';
  } else if (error.name === 'NotReadableError') {
    status.textContent = 'The video input is busy or could not be opened. Close other apps using it and try again.';
  } else {
    status.textContent = 'Could not open the video input. Check the capture device and Windows camera permissions.';
  }
}

discover.addEventListener('click', async () => {
  release();
  const generation = ++requestGeneration;
  busy = true;
  updateControls();
  status.textContent = 'Looking for video inputs…';
  let probe;
  try {
    if (!navigator.mediaDevices?.getUserMedia) throw new Error('Camera API unavailable');
    probe = await navigator.mediaDevices.getUserMedia({ video: true, audio: false });
    if (generation !== requestGeneration) return;
    probeStream = probe;
    const inputs = (await navigator.mediaDevices.enumerateDevices()).filter(d => d.kind === 'videoinput');
    if (generation !== requestGeneration) return;
    devices.replaceChildren();
    inputs.forEach((input, i) => {
      const option = document.createElement('option');
      option.value = input.deviceId;
      option.textContent = input.label || `Video input ${i + 1}`;
      devices.append(option);
    });
    status.textContent = inputs.length ? 'Choose your HDMI capture device, then select Start viewing.' : 'No video inputs found. Reconnect the capture device and try again.';
  } catch (error) {
    if (generation === requestGeneration) fail(error);
  } finally {
    stopTracks(probe);
    if (probeStream === probe) probeStream = null;
    if (generation === requestGeneration) {
      busy = false;
      updateControls();
    }
  }
});

start.addEventListener('click', async () => {
  const generation = ++requestGeneration;
  busy = true;
  updateControls();
  status.textContent = 'Opening video input…';
  try {
    const opened = await navigator.mediaDevices.getUserMedia({
      video: { deviceId: { exact: devices.value }, width: { ideal: 1920 }, height: { ideal: 1080 }, frameRate: { ideal: 60 } },
      audio: false,
    });
    if (generation !== requestGeneration) {
      stopTracks(opened);
      return;
    }
    stream = opened;
    video.srcObject = opened;
    placeholder.hidden = true;
    opened.getVideoTracks()[0].addEventListener('ended', () => {
      if (stream === opened) {
        release();
        status.textContent = 'The video input disconnected. Reconnect it and find inputs again.';
      }
    });
    await video.play();
    if (generation === requestGeneration) status.textContent = 'Viewing the selected video input.';
  } catch (error) {
    if (generation === requestGeneration) {
      release();
      fail(error);
    }
  } finally {
    if (generation === requestGeneration) {
      busy = false;
      updateControls();
    }
  }
});

stop.addEventListener('click', () => {
  release();
  status.textContent = 'Viewing stopped.';
});
const screen = document.querySelector('.screen');
function toggleFullscreen() {
  if (document.fullscreenElement) {
    document.exitFullscreen().catch(() => {});
    return;
  }
  if (!stream) return;
  screen.requestFullscreen().catch(() => {
    status.textContent = 'The viewer could not go full screen.';
  });
}
expand.addEventListener('click', toggleFullscreen);
screen.addEventListener('dblclick', toggleFullscreen);
document.addEventListener('keydown', event => {
  if (event.key === 'F11') {
    event.preventDefault();
    toggleFullscreen();
  }
});
document.addEventListener('fullscreenchange', () => {
  const on = document.fullscreenElement === screen;
  window.chrome.webview.postMessage(on ? 'fullscreen-on' : 'fullscreen-off');
});
window.chrome.webview.addEventListener('message', event => {
  if (event.data === 'stop-capture') {
    release();
    status.textContent = 'Viewing stopped. Select Start viewing to resume.';
  }
});
window.addEventListener('pagehide', release);
updateControls();
