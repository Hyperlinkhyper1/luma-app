# SVG ANIMATION BENCHMARK — A TIMELINE OF THE WORLD

Create an animated, illustrated history of the world as a single HTML page
whose artwork is entirely SVG.

This tests vector illustration, animation craft and factual accuracy. The
animation travels from the formation of the Earth to the present day as
one continuous, narrated piece — a short animated documentary, not a slide
deck of text cards.

==================================================
TECHNICAL RULES
==================================================

- All artwork is inline SVG in the page's DOM: paths, shapes, gradients,
  patterns, masks, clip paths and filters. Do NOT use <canvas>, WebGL,
  raster images (no <image>, no data: URIs of bitmaps) or emoji as artwork.
- Animate with JavaScript (requestAnimationFrame driving attributes and
  transforms), CSS animations, SMIL, or a mix. No libraries, no network
  requests, system fonts only.
- The main <svg> uses a viewBox and scales to fill the window at any
  aspect ratio without distortion or cropping important content.

==================================================
THE STORY
==================================================

Cover at least these chapters, in order, with correct dates:

1. Formation of the Earth, about 4.54 billion years ago, and the
   Moon-forming impact (Theia)
2. The Hadean: a molten surface cooling, the first oceans
3. First life, about 3.7–3.5 billion years ago (microbial mats,
   stromatolites)
4. The Great Oxidation Event, about 2.4 billion years ago (sky and sea
   change colour)
5. Snowball Earth, about 720–635 million years ago
6. The Cambrian explosion, about 538 million years ago
7. Life moves onto land: plants, then animals (roughly 470–375 million
   years ago)
8. Pangaea forms and breaks apart; the age of dinosaurs (252–66 million
   years ago)
9. The asteroid impact 66 million years ago
10. The rise of mammals
11. Homo sapiens, about 300,000 years ago
12. Farming begins, about 10,000 BCE
13. Early civilisations: Mesopotamia and Egypt (the Great Pyramid of Giza,
    about 2560 BCE)
14. The classical world (Greece, Rome, Han China)
15. The medieval world
16. The printing press (about 1450) and the age of exploration (1492)
17. The Industrial Revolution (from about 1760)
18. The 20th century: powered flight (1903), the world wars, the Moon
    landing (1969)
19. The digital age, up to today

Every chapter gets a title, its date and one or two sentences of caption.
Dates and facts must be right; when a date is approximate, say so.

==================================================
VISUALS
==================================================

The main stage is one evolving illustration, not separate pictures:

- A globe or landscape that changes through the eras: glowing magma,
  cooling crust, oceans forming, the sky turning from orange haze to blue,
  ice covering the planet, continents drifting together into Pangaea and
  apart again (shapes morph smoothly between eras).
- Life appears in the scene as it evolves: stromatolites, trilobites and
  early fish, ferns and forests, dinosaurs, the impact and its aftermath,
  mammals, people, fields, cities, ships, factories with smoke, aeroplanes,
  a rocket, a city at night with glowing lights.
- Use parallax layers, stroke-drawing reveals (stroke-dasharray), path
  morphing, gradient and colour shifts, glow and blur filters, and
  particles built from SVG elements (embers, snow, stars, birds).
- Transitions between chapters are animated and continuous: the view
  pans, zooms, cross-fades or morphs — never a hard cut to a new slide.

==================================================
THE TIMELINE
==================================================

Along the bottom, an interactive timeline bar:

- Deep time is enormous compared with history, so use a scale that makes
  both readable (logarithmic or piecewise segments), and show on the bar
  which scale each part uses.
- Era bands (Hadean, Archean, Proterozoic, Paleozoic, Mesozoic, Cenozoic,
  then human history) with labels and chapter tick marks.
- A playhead that moves as the animation plays, with a date readout in
  fitting units: "4.54 billion years ago", "66 million years ago",
  "300,000 years ago", "2560 BCE", "1969 CE".
- Drag the playhead to scrub; click a chapter tick to jump to it.

Controls: play / pause, playback speed (0.5x, 1x, 2x), restart, and
keyboard support (Space to play / pause, arrow keys for the previous /
next chapter). The whole piece at 1x should last about 2–4 minutes, start
playing automatically when the page opens, and loop at the end.

==================================================
QUALITY BAR
==================================================

- No placeholders or dead controls; every chapter has real artwork.
- Smooth at 60 fps: animate transforms and opacity rather than rebuilding
  the DOM every frame; keep the element count reasonable.
- Text stays legible over the artwork at every window size.

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
