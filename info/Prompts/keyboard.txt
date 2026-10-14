Create a polished, interactive mechanical keyboard showcase as one complete, self-contained HTML file. Put all HTML, CSS, and JavaScript in that file.

The keyboard must be presented as a 3D object with clear depth, perspective, and visible sides. Build the scene with real 3D positioning and transforms, such as CSS 3D transforms or WebGL. Do not make it a flat illustration, a top-down diagram, or a set of 2D images. Give the case, PCB, foam, plate, switches, and keycaps visible thickness and distinct shapes.

When the page opens, animate an exploded-view assembly of the keyboard. Start with the motherboard/PCB, then bring the foam, plate, switches, and keycaps into place in that order. Show each layer moving through 3D space before it settles into the keyboard. Install switches one by one from left to right, then keycaps one by one from left to right. Use smooth, deliberate motion so each stage is easy to see.

Choose the keyboard's layout, style, colors, and materials yourself. You may include a rotary knob if it fits the design. Make the finished keyboard look detailed and cohesive. RGB lighting is optional; if included, make it tasteful and controllable.

After assembly, clicking a key should visibly press and release it in 3D and play a sound. Physical keyboard input should trigger the matching on-screen key too. Give different key groups distinct sounds: spacebar should sound deeper than letter keys, and Enter, Backspace, and modifier keys can each have their own character. Generate audio in the browser with the Web Audio API; do not load audio files. Account for browser audio restrictions by enabling sound on the first user interaction and showing a small hint if needed.

Include a replay button for the assembly animation and a mute control. Make the page responsive and the controls functional. Respect reduced-motion preferences where practical. Avoid placeholders and unfinished interactions.

Libraries: you may use Three.js (and its helper modules) loaded from a public CDN such as unpkg.com or cdn.jsdelivr.net, or use plain CSS 3D transforms with no library. No external models, textures, images or audio files.

============================================================
OUTPUT FORMAT — READ CAREFULLY
============================================================

Reply with ONE complete, self-contained HTML document and nothing else.

- Start your reply with <!DOCTYPE html> and end it with </html>.
- No explanation, summary or notes before or after the document.
- No Markdown code fences.
- No additional files: all CSS and JavaScript go inline in this one page.
- Libraries may only be loaded from the public CDN URLs this prompt allows.
- The page must fill the browser window (no page scrollbars) and start on
  its own when opened. It is shown inside an app's embedded browser.

Your reply is saved byte for byte as the page, so anything outside the
document breaks it.
