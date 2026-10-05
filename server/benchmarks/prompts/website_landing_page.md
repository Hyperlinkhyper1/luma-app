# WEBSITE LANDING PAGE BENCHMARK — EMBER & BEAN, COFFEE FOR SLOW MORNINGS

Create a complete, polished coffee landing page for Ember & Bean, a fictional
specialty coffee roastery selling freshly roasted beans and recurring coffee
deliveries to home brewers. The entire website must be coffee related:
branding, copy, illustrations, products, stories, and interactions. Do not
turn this into a software, productivity, or generic technology landing page.
This is a repeatable benchmark of frontend design,
instruction following, responsive layout, accessibility, and practical
JavaScript. Every model receives this same brief. Build the actual website,
not a wireframe, screenshot, source-code viewer, or explanation of a website.

DELIVERABLE AND RUNTIME

Return exactly one self-contained HTML document with inline CSS and inline
JavaScript. It must run directly from a local file in a modern embedded
browser without installation, a build step, a server, an account, or a
network connection. Do not import frameworks, libraries, external fonts,
images, icon packs, videos, or remote resources. Create all artwork using
your own CSS, inline SVG, and HTML. Use system fonts. Use real semantic HTML
for readable content and controls; do not paint the entire page on a canvas.
The document scrolls vertically like a real landing page. Never lock the
whole page to one viewport or hide overflow to conceal missing sections.

AUDIENCE, BRAND, AND DESIGN

The audience is people who enjoy a daily coffee ritual, from curious home
brewers to espresso enthusiasts looking for their next favorite roast.
Ember & Bean should feel warm, tactile, considered, and welcoming. Choose a
cohesive visual direction with a restrained palette, a distinctive accent,
strong typography, intentional spacing, and a clear rhythm between sections.
Light or dark styling is your choice. Use coffee-inspired colors and original
artwork of beans, cups, roasting, or brewing equipment. Make the result look
like a finished coffee brand with its own identity. Avoid an interchangeable collection of equal
cards, excessive gradients, arbitrary decorative blobs, and walls of tiny
text. Balance expressive design with readable contrast and obvious actions.

Use the exact brand name Ember & Bean and the hero headline "Good mornings
start with great coffee." Write concise supporting copy explaining that
freshly roasted coffee is delivered for the reader's favorite brewing ritual.
The primary action is "Choose your coffee" and the secondary action is
"Meet the roasts". A small note must say "Freshly roasted · Brew your way".
Do not invent numerical
customer counts, awards, certifications, or claims about real companies.

REQUIRED CONTENT IN PAGE ORDER

1. Header: include an original Ember & Bean wordmark or simple inline SVG
coffee mark, links to Our coffee, How it works, Subscriptions, and FAQ,
plus a Choose your coffee button.
Keep navigation useful while scrolling. On narrow screens provide a real
menu button that opens and closes the navigation, reports its expanded
state, closes after choosing a link, and closes when Escape is pressed.

2. Hero: build a convincing first impression with the exact headline,
supporting copy, both actions, and the freshness note. Include a large
original coffee illustration: a beautifully labeled bag of beans beside a
cup, coffee beans, and a brewer. Create it using CSS or inline SVG, with
careful shapes, lighting, texture, and composition. The artwork should feel
like a coffee product presentation, not an app dashboard. Include a roast
selector that updates the featured bag label, accent, and tasting notes.
Offer these three fictional 250g coffees: "Morning Light", a medium roast
with chocolate and caramel notes; "Daybreak", a light roast with citrus and
honey notes; and "Nightcap Decaf", a decaf medium roast with cocoa and
hazelnut notes. Do not claim decaf contains zero caffeine. Show roast level,
bag weight, and tasting notes as readable text outside the artwork as well.

3. Our coffee: present the same three roasts with a short, evocative
description and a working Choose this roast action. Explain exactly three
benefits: "Roasted with care", "Made for your brew", and "Fresh coffee,
on your schedule". Give each a specific description and an original visual
treatment tied to roasting, grind choice, or recurring deliveries. Prefer
varied composition to repeated identical boxes. Do not invent real farm
partnerships, sustainability certifications, or unsupported sourcing claims.

4. How it works: show three ordered steps named "Pick your roast", "Choose
your grind", and "Set your rhythm". Include brief descriptions. Connect
them into a readable sequence on desktop and a clear stack on mobile.

5. Customer stories: include two clearly labeled fictional example stories.
One quote is "Morning Light turned my first cup into my favorite ritual."
from Mira Chen, Home brewer. The other is "A fresh bag, the right grind,
and a better espresso every morning." from Alex Rivera, Espresso enthusiast.
State "Illustrative stories from fictional coffee drinkers" near the
quotes. Do not use real-company logos or present these examples as evidence
of actual customers. Treat the stories as thoughtful typography rather
than stuffing them into the same feature-card layout.

6. Subscriptions: show three coffee delivery options: "Solo ritual" is one
250g bag for $14 per delivery; "Daily duo" is two 250g bags (500g total) for
$26 per delivery; "Coffee household" is four 250g bags (1kg total) for $48
per delivery. Mark Daily duo as "Most popular". Include an Every 2 weeks /
Monthly switch that really updates visible delivery and billing explanations.
Prices are per delivery and stay the same for either frequency: $14, $26,
and $48. State that billing follows the selected delivery schedule. Do not
label a fortnightly delivery price as a monthly total or invent discounts.
State "Shipping included in this demo pricing". Each subscription action
opens the coffee selection dialog with that option selected, retaining the
chosen delivery frequency and featured roast. Include whole bean, filter
grind, and espresso grind choices in the dialog. Explain that customers can
pause or change their next delivery in the fictional service.

7. FAQ: provide at least four questions with real accordion controls. Cover
roast choice, grind options, pausing deliveries, and how the demo works.
Answers must agree with this brief. Explain that this delivered benchmark
is an offline demo and does not connect to the fictional Ember & Bean shop.
Use buttons or details/summary, expose expanded state accessibly, and allow
keyboard operation. Opening and closing answers must not break page layout.

8. Final action and footer: end with a strong invitation to find a favorite
coffee, a Choose your coffee action, the Ember & Bean identity, copyright text, and useful links
to existing page sections. Do not add dead links, nonexistent legal pages,
social links that go nowhere, or controls that only log to the console.

WORKING INTERACTIONS

All Choose your coffee actions open the same accessible coffee selection
dialog. Choose this roast actions open it with their specific roast selected.
Include a name field, email field, roast selector, grind selector, delivery
option selector, delivery frequency, and a live order summary. The summary
must show the selected coffee, grind, number of bags, total weight, price per
delivery, and frequency, and update whenever a choice changes. Use a
"Confirm demo subscription" submit button. Require a nonblank name and a valid email. Show
field-specific validation messages and retain input after a validation
failure. On successful submission, show a clear local confirmation with
the selected roast, grind, bags, price, and delivery frequency. Explicitly
say "Demo only: no order was placed, no payment was taken, and no information
was sent." Do not send requests, collect payment or address details,
or pretend the fictional shop placed a real coffee order. Do not persist names
or email addresses. The dialog must have a close control, close on Escape,
keep keyboard focus inside while open, and return focus to the control that
opened it. Every field needs a visible label. Every other visible button,
tab, switch, or navigation item must do the useful thing its label promises.
Meet the roasts scrolls to Our coffee. Changing the featured roast must
update its visible label and tasting notes and carry that selection into
the dialog. Opening a subscription option must retain that option rather
than resetting to a default. Every action must remain coffee related.

RESPONSIVENESS AND ACCESSIBILITY

Design carefully for widths of 1440, 1024, 768, 390, and 320 CSS pixels.
At 320 pixels every section must remain readable and every control usable,
without horizontal document scrolling, clipped prices, overlapping text,
or fixed elements covering content. Reflow the coffee artwork and subscriptions
instead of merely scaling down a desktop screenshot. Keep tap targets
comfortable, provide visible keyboard focus, and use semantic landmarks,
one main heading, and correctly nested section headings. Navigation anchors
must land below any sticky header. Include a working skip-to-content link.
Ensure text and interactive controls have sufficient contrast. Decorative
artwork must not confuse assistive technology; meaningful controls need
accessible names. Support prefers-reduced-motion by removing nonessential
movement and smooth scrolling. Content must remain visible if an animation
does not run. Avoid continuous distracting animation or scroll hijacking.

QUALITY AND EVALUATION

The page will be judged on visual identity, composition, typography,
consistency, believable coffee product detail, fidelity to the brief, responsive
behavior, keyboard accessibility, and whether interactions work end to end.
Use the supplied names, headline, prices, benefits, and interaction rules
exactly so model outputs can be compared fairly. You may choose the art
direction and write the remaining copy. Prioritize a complete, attractive,
usable page over complicated effects. Keep code organized and ensure there
are no syntax errors, missing assets, placeholder sections, broken links,
unfinished loading states, or claims that a backend exists. Before replying,
check the menu, roast selector, delivery toggle, subscription and grind selection, FAQ controls,
form validation, confirmation, dialog focus, and narrow layout. Deliver the
finished HTML document alone.

============================================================
OUTPUT FORMAT — READ CAREFULLY
============================================================

Reply with ONE complete, self-contained HTML document and nothing else.

- Start your reply with <!DOCTYPE html> and end it with </html>.
- No explanation, summary or notes before or after the document.
- No Markdown code fences.
- No additional files: all CSS and JavaScript go inline in this one page.
- Libraries may only be loaded from the public CDN URLs this prompt allows.
- Use normal vertical document scrolling for the landing page, with no
  horizontal overflow. It must work when opened in an app's embedded browser.

Your reply is saved byte for byte as the page, so anything outside the
document breaks it.
