/**
 * Client for Lidl NL's "Aanbiedingen" (weekly offers) hub page
 * (www.lidl.nl/c/aanbiedingen/a10008785).
 *
 * No headless browser is needed here, unlike Jumbo/Hoogvliet: the page is
 * fully server-rendered, and every product tile — all 117 of them across
 * the week's three release days (Monday/Wednesday/Friday) — carries its
 * complete product data in a `data-grid-data="..."` HTML attribute
 * (HTML-entity-encoded JSON), present in the raw response before any
 * client JS runs. That's worth relying on directly rather than driving a
 * browser and reading the rendered DOM: the live page has a client-side
 * rendering bug where only ~8 of the 117 tiles ever actually mount into
 * visible markup, no matter how long you wait or scroll (confirmed live
 * 2026-08-31 — even forcing a native `scrollIntoView` on an unrendered
 * tile never converts it). Reading the embedded JSON sidesteps that bug
 * and gets every current deal, not just whatever happened to render.
 *
 * A plain `fetch()` gets the identical HTML a real browser session does —
 * no Akamai-style bot mitigation observed on this endpoint (unlike Jumbo).
 */

const OFFERS_URL = 'https://www.lidl.nl/c/aanbiedingen/a10008785';
const USER_AGENT =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36';

const GRID_DATA_ATTR_RE = /data-grid-data="([^"]*)"/g;

function decodeHtmlEntities(str) {
  return str
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&amp;/g, '&');
}

/**
 * Fetches the Aanbiedingen page and extracts every embedded product
 * record. A tile whose JSON fails to parse is skipped rather than failing
 * the whole fetch — one malformed record shouldn't sink the rest.
 */
async function fetchHighlightedDeals() {
  const response = await fetch(OFFERS_URL, {
    headers: { 'User-Agent': USER_AGENT, 'Accept-Language': 'nl-NL,nl;q=0.9' },
  });
  if (!response.ok) {
    throw new Error(`Lidl offers request failed: HTTP ${response.status}`);
  }
  const html = await response.text();

  const records = [];
  GRID_DATA_ATTR_RE.lastIndex = 0;
  let match;
  while ((match = GRID_DATA_ATTR_RE.exec(html)) !== null) {
    try {
      records.push(JSON.parse(decodeHtmlEntities(match[1])));
    } catch (_) {
      // Skip this one tile; keep going.
    }
  }
  return records;
}

module.exports = { fetchHighlightedDeals };
