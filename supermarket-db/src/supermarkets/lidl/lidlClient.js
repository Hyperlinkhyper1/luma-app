/**
 * Playwright-driven client for Lidl NL's "Aanbiedingen" (weekly offers) hub
 * page (www.lidl.nl/c/aanbiedingen/a10008785).
 *
 * Unlike Jumbo/AH/Hoogvliet, Lidl NL does not run a browsable grocery
 * catalog at all — every food category link (e.g. /c/eten-en-drinken/...)
 * redirects straight back to this one hub page, and the comprehensive
 * weekly flyer is a 53-page image-based flipbook with no product API
 * behind it (verified live 2026-08-31). The one real structured data source
 * is this page's highlighted-deals grid: a handful of product tiles
 * (position "2.1".."2.8" in practice, count varies day to day) each
 * carrying a `data-gridbox-impression` attribute with clean JSON
 * (id/name/price/category) alongside rendered price/discount/availability
 * markup. That's what gets scraped here — a small, honest weekly showcase,
 * not a full catalog.
 */

const { chromium } = require('playwright');

const BASE_URL = 'https://www.lidl.nl';
const OFFERS_URL = `${BASE_URL}/c/aanbiedingen/a10008785`;
const USER_AGENT =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36';

async function launch() {
  const browser = await chromium.launch({
    headless: true,
    args: ['--disable-dev-shm-usage', '--disable-blink-features=AutomationControlled'],
  });
  const context = await browser.newContext({ userAgent: USER_AGENT, locale: 'nl-NL' });
  await context.addInitScript(() => {
    Object.defineProperty(navigator, 'webdriver', { get: () => undefined });
  });
  const page = await context.newPage();
  page.setDefaultTimeout(45000);
  return { browser, page };
}

/**
 * Scrapes the highlighted-deals grid on the Aanbiedingen hub page.
 *
 * Each tile's own metadata comes from `data-gridbox-impression`, a
 * URL-encoded JSON blob Lidl's own analytics layer already attaches
 * (id/name/price/category) — reading that is far more reliable than
 * parsing the rendered title/price text. Returns [] if the grid isn't
 * there; the caller treats an empty result as a hard failure.
 */
async function fetchHighlightedDeals(page) {
  const response = await page.goto(OFFERS_URL, { waitUntil: 'load', timeout: 60000 });
  if (response && !response.ok()) {
    throw new Error(`Lidl offers request failed: HTTP ${response.status()}`);
  }
  // The grid hydrates client-side (Vue) a couple seconds after the initial
  // HTML lands — a fresh page load has 0 tiles at 0s and the full grid by
  // ~2.5s (verified live 2026-08-31). Give it a comfortable margin.
  await page.waitForTimeout(3000);

  return page.evaluate(() => {
    function text(el) {
      return el ? (el.textContent || '').trim() : '';
    }

    const tiles = Array.from(document.querySelectorAll('div.product-grid-box'));
    return tiles.map((tile) => {
      let meta = null;
      try {
        meta = JSON.parse(decodeURIComponent(tile.getAttribute('data-gridbox-impression') || ''));
      } catch (_) {
        meta = null;
      }

      const linkEl = tile.querySelector('a.odsc-tile__link');
      const href = linkEl ? linkEl.getAttribute('href') : null;

      const imageEl = tile.querySelector('.odsc-image-gallery__image');
      const image = imageEl ? imageEl.getAttribute('src') : null;

      // Non-weight-based items (e.g. potted plants) describe themselves here
      // instead of the price footer's pack size, so it's kept as a separate
      // fallback rather than folded into quantity.
      const descEl = tile.querySelector('.product-grid-box__desc');
      const desc = descEl
        ? descEl.innerHTML.replace(/<br\s*\/?>/gi, ', ').replace(/<[^>]+>/g, '').trim()
        : '';

      // Crossed-out regular price, only present when this tile is a real
      // markdown vs. Lidl's usual price (e.g. a Lidl Plus member discount).
      const strokeEl = tile.querySelector('.ods-price__stroke-price');
      const oldPriceText = strokeEl ? text(strokeEl) : null;

      const discountBadgeEl = tile.querySelector('.ods-price__box-content-text-el');
      const discountText = discountBadgeEl ? text(discountBadgeEl) : null;

      const isLidlPlusPrice = !!tile.querySelector('.ods-price__lidl-plus-hint');

      // Pack size (e.g. "400 g") lives in the price footer for weight-based
      // groceries; the footer's other spans are always empty placeholders.
      const footerEl = tile.querySelector('.ods-price__footer');
      const quantity = footerEl ? text(footerEl).replace(/\s+/g, ' ').trim() || null : null;

      const availabilityEl = tile.querySelector(
        '.product-grid-box__availabilities .ods-badge__label'
      );
      const availabilityText = availabilityEl ? text(availabilityEl) : null;

      return {
        id: meta ? String(meta.id) : null,
        name: meta ? meta.name : text(tile.querySelector('.product-grid-box__title')) || null,
        category: meta ? meta.category : null,
        price: meta ? meta.price : null,
        href,
        image,
        desc: desc || null,
        oldPriceText,
        discountText,
        isLidlPlusPrice,
        quantity,
        availabilityText,
      };
    });
  });
}

module.exports = { launch, fetchHighlightedDeals };
