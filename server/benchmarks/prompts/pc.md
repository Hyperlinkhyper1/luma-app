# 3D PC BUILDING + CREATIVITY BENCHMARK

Create an impressive, interactive **3D desktop gaming PC** entirely inside **one self-contained HTML page**.

This is a benchmark of your ability to combine:

* 3D scene construction
* visual design
* creativity
* animation
* lighting
* interaction
* UI design
* technical problem-solving
* attention to detail
* performance optimization

Do not treat this as a basic demonstration. Build something that feels polished, intentional, and visually interesting.

## CORE REQUIREMENTS

Create a complete desktop PC in 3D.

The PC should contain recognizable internal hardware and components, but **you decide what those components are, how they look, how they are arranged, and what design language the PC follows**.

You are encouraged to invent your own:

* case design
* cooling system
* GPU design
* motherboard appearance
* RAM
* fans
* lighting arrangement
* cables
* decorations
* materials
* mechanical details
* branding or fictional component designs

Do not simply build the minimum required objects.

Use your own judgment and creativity to make the PC visually convincing.

## SINGLE-FILE RULE

HTML, CSS, JavaScript, shaders, geometry definitions, UI code, animation logic, and other required code must all be contained within the one page.

Three.js (and its official addons) may be loaded from a public CDN (unpkg.com or cdn.jsdelivr.net). No images, textures, models or other external assets.

The page renders the 3D scene to a WebGL canvas.

## 3D EXPERIENCE

The user should be able to inspect the PC as a 3D object.

Provide intuitive camera controls so the PC can be viewed from different angles.

The PC should have enough geometric depth and detail that it clearly feels like an actual 3D build rather than a collection of flat shapes.

Good use of materials, reflections, transparency, lighting, shadows, emissive surfaces, and subtle animation is encouraged.

## POWER SYSTEM

In the **bottom-right corner**, create a compact PC-control HUD.

It must contain a clearly recognizable **Power button**.

When the PC is OFF:

* RGB lighting should be off.
* illuminated components should shut down appropriately.
* moving powered components should stop or transition into an off state.
* the system should visibly feel powered down.

When the user presses the power button, the PC should perform a convincing startup sequence. For example, hardware may come alive progressively rather than everything changing instantly.

## RGB CONTROL

The bottom-right HUD must allow the user to change the PC's RGB lighting.

The user must be able to select **any RGB color**, not just a small collection of presets.

Changes should update the 3D lighting in real time, across multiple appropriate elements of the PC.

## HUD

The HUD should feel like a small PC control panel rather than a debug menu.

Besides the required power and RGB controls, add several additional controls or features that make sense for the experience. You are specifically being evaluated on what useful or interesting ideas you add beyond the minimum requirements. Do not fill the HUD with meaningless controls.

## ANIMATION

The PC should feel alive while powered on: fans, lighting, cooling hardware, displays, mechanical components, environmental effects, or something else you invent. Animations should be readable, not so fast the viewer cannot appreciate them.

## CREATIVITY

You have substantial creative freedom. Do not assume that the safest or simplest interpretation is the best one. Add original details, interactions, animations, visual effects, or hardware features that support the central idea of showcasing a high-quality 3D PC.

The brief intentionally does **not** specify dimensions, hardware, fan count, case layout, materials, lighting, camera composition, animation style, HUD design, RGB implementation or visual theme. Those decisions are part of the test.

## VISUAL QUALITY

Aim for something that could serve as a visually impressive interactive demo. Pay attention to proportions, composition, material variation, lighting, depth, reflections, component placement, small details, clean geometry, animation quality and UI presentation.

Avoid making the PC look like a stack of simple colored boxes unless that simplicity is deliberately part of a sophisticated visual style.

## PERFORMANCE, INTERACTION, RESPONSIVENESS

The experience should remain smooth on a normal modern desktop browser and make sense immediately when opened. Buttons give visual feedback, the scene stays usable while animating, and the viewport and HUD adapt to different window sizes without overlapping.

Avoid console errors, broken controls, missing resources, interactions that work only once, page scrolling while controlling the camera, UI blocking important interactions, and frame-rate-dependent animation speed.

## PRIORITY

1. Creativity and originality
2. Quality of the 3D PC
3. Interactive functionality
4. Visual polish
5. Animation quality
6. Technical robustness
7. Performance
8. Code cleanliness

A technically perfect but visually boring collection of primitives should not score as highly as an ambitious, polished, well-designed PC — but visual ambition must not come at the expense of broken functionality.

Make your own design decisions. Surprise the evaluator.

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
