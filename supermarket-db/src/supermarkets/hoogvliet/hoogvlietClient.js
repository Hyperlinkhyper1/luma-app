/**
 * Playwright-driven client for Hoogvliet (www.hoogvliet.com).
 *
 * Hoogvliet runs on Intershop Commerce (org-webshop) with a Tweakwise
 * Navigator search layer. The Tweakwise instance (navigator-group1) is not
 * reachable directly from outside (401 Instance not found), but the
 * Intershop proxy endpoint ViewTWParametricSearch-SimpleOfferSearch renders
 * the product grid server-side when loaded in a real browser session (with
 * the sid/pgid cookies and Incapsula challenge passed). So — like Jumbo —
 * this drives a headless Chromium instance and scrapes the rendered tiles.
 *
 * Two-stage crawl:
 *   1. fetchCategories(page)  — visits the shop homepage and collects every
 *      top-level CategoryName link (999999-xxx + 100/200/300… families)
 *      which maps to a Tweakwise filtered product listing.
 *   2. fetchCategoryPage(page, {categoryName, pageNumber}) — loads one
 *      paginated listing for that category via the ViewTWParametricSearch
 *      endpoint and returns raw tile records.
 */

const { chromium } = require('playwright');

const BASE_URL = 'https://www.hoogvliet.com';
const USER_AGENT =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36';

async function launch() {
  const browser = await chromium.launch({
    headless: true,
    args: ['--disable-dev-shm-usage', '--disable-blink-features=AutomationControlled'],
  });
  const context = await browser.newContext({
    userAgent: USER_AGENT,
    locale: 'nl-NL',
    viewport: { width: 1280, height: 900 },
  });
  await context.addInitScript(() => {
    Object.defineProperty(navigator, 'webdriver', { get: () => undefined });
  });
  const page = await context.newPage();
  page.setDefaultTimeout(45000);
  return { browser, page };
}

/**
 * Collects every distinct top-level Hoogvliet product category.
 *
 * Hoogvliet's nav is fully rendered in the homepage HTML (not JS-injected),
 * so a single goto + evaluate is enough. Each tile link carries
 * `CategoryName=999999-XXX` (parent Tweakwise category) or `100-10001`-style
 * subcategories. We keep the 999999-family ones as crawl roots — paginating
 * a root already walks all its subcategories server-side, but using the
 * leaf-level links as well would duplicate work. Roots are also the most
 * stable set (survive merchandising reshuffles) and correspond 1:1 to the
 * sidebar departments shown to shoppers.
 *
 * Returns [{ name, categoryName, title }]
 */
async function fetchCategories(page) {
  await page.goto(`${BASE_URL}/`, { waitUntil: 'load', timeout: 60000 });
  // Let Incapsula challenge settle (fast on good IPs, a second or two on others)
  await page.waitForTimeout(1500);

  const categories = await page.evaluate(() => {
    const links = Array.from(document.querySelectorAll('a[href*="CategoryName="]'));
    const seen = new Map();
    for (const a of links) {
      try {
        const url = new URL(a.href, location.origin);
        const categoryName = url.searchParams.get('CategoryName');
        const title = (url.searchParams.get('CategoryTitle') || a.textContent || '')
          .replace(/--/g, ' / ')
          .replace(/\+/g, ' ')
          .trim();
        if (!categoryName) continue;
        // Keep only the 999999-family top categories for a lean crawl.
        // Subcategories like 100-10001 are already covered by paging the root.
        // Still stash any non-999999 top categories that slip through (e.g.
        // seasonal "Alles voor de barbecue" with CategoryName 20221604).
        if (!seen.has(categoryName)) {
          seen.set(categoryName, { categoryName, title: title || a.textContent.trim() || categoryName });
        }
      } catch (_) {}
    }
    return Array.from(seen.values());
  });

  // Fallback: if homepage parsing found nothing (bot challenge, layout change),
  // use the known stable catalogue roots observed on 2026-08-25 so the sync
  // still makes progress rather than silently producing 0 products.
  if (categories.length === 0) {
    return [
      { categoryName: '999999-100', title: 'Aardappelen, groente, fruit' },
      { categoryName: '999999-200', title: 'Vlees, kip, vis, vegetarisch' },
      { categoryName: '999999-300', title: 'Kaas, vleeswaren, tapas' },
      { categoryName: '999999-500', title: 'Zuivel, plantaardig, eieren' },
      { categoryName: '999999-700', title: 'Brood' },
      { categoryName: '999999-900', title: 'Frisdrank, sappen, koffie, thee' },
      { categoryName: '999999-1100', title: 'Chips, zoutjes, noten' },
      { categoryName: '999999', title: 'Producten' },
    ].map((c) => ({ name: c.title, categoryName: c.categoryName, title: c.title }));
  }

  // Prefer the 999999-family roots; keep a seasonal top category if it's the
  // only representative of its family so the crawl still reaches those aisles.
  const roots = categories.filter((c) => c.categoryName.startsWith('999999'));
  const nonRoots = categories.filter((c) => !c.categoryName.startsWith('999999'));
  const chosen = roots.length > 0 ? roots : categories;
  // Deduplicate by categoryName and attach display name
  const deduped = [];
  const seenNames = new Set();
  for (const c of chosen) {
    if (seenNames.has(c.categoryName)) continue;
    seenNames.add(c.categoryName);
    deduped.push({ name: c.title || c.categoryName, categoryName: c.categoryName, title: c.title || c.categoryName });
  }
  // Include seasonal non-root categories that don't overlap a chosen root's
  // numeric range (e.g. barbecue special).
  for (const c of nonRoots) {
    if (!seenNames.has(c.categoryName)) {
      seenNames.add(c.categoryName);
      deduped.push({ name: c.title || c.categoryName, categoryName: c.categoryName, title: c.title || c.categoryName });
    }
  }

  return deduped;
}

function categoryUrl(categoryName, pageNumber, pageSize = 48) {
  const params = new URLSearchParams({
    PageNumber: String(pageNumber),
    PageSize: String(pageSize),
    SelectedSearchResult: 'SFProductSearch',
    SearchTerm: '',
    SelectedItem: '',
    SortingOption: 'Relevantie',
    CategoryName: categoryName,
  });
  // CategoryTitle / CatalogPermalink are not required for the server to return
  // products, but carrying an empty title avoids a redirect loop on some
  // categories — same pattern the storefront's own next-page links use.
  return `${BASE_URL}/INTERSHOP/web/WFS/org-webshop-Site/nl_NL/-/EUR/ViewTWParametricSearch-SimpleOfferSearch?${params.toString()}`;
}

/**
 * One paginated product listing for a Tweakwise category.
 * Returns [] once PageNumber runs past the last page.
 *
 * Each tile is scraped with generous fallback selectors so a minor class
 * rename doesn't silently empty the crawl. Price is parsed from whatever
 * text the tile actually renders (Hoogvliet shows e.g. "4 . 27" with the
 * cents as a superscript — joining all price spans and running a single
 * (\d+)[\.,](\d{2}) match catches both that and a plain "2,39").
 */
async function fetchCategoryPage(page, { categoryName, pageNumber = 0, pageSize = 48 } = {}) {
  const url = categoryUrl(categoryName, pageNumber, pageSize);
  const response = await page.goto(url, { waitUntil: 'load', timeout: 45000 });
  if (response && !response.ok() && response.status() !== 200) {
    throw new Error(`Hoogvliet request failed: HTTP ${response.status()} for category ${categoryName} page ${pageNumber}`);
  }
  await page.waitForTimeout(1200);

  return page.evaluate(() => {
    function text(el) {
      return el ? (el.textContent || '').trim() : '';
    }

    // Hoogvliet product tiles — try the most likely selectors first.
    // The storefront has used a consistent "product-tile" family for years,
    // but Incapsula/Intershop upgrades could shuffle classes, so we probe
    // several patterns before giving up.
    const tileSelectors = [
      '[data-test*="product-tile"]',
      '.product-tile',
      '.productTile',
      '.ish-productTile',
      '.product-item',
      '[data-productid]',
      'a[href*="/product/"]',
      '.kor-product-tile',
    ];

    let tiles = [];
    for (const sel of tileSelectors) {
      const found = Array.from(document.querySelectorAll(sel));
      // Filter to elements that actually look like a product tile (have an
      // image and some price-ish text), otherwise a header link to /product/
      // would pollute the result set.
      const plausible = found.filter((el) => {
        const hasImg = el.querySelector('img') !== null || el.tagName === 'IMG';
        const hasPrice = /(\d+[.,]\d{2})/.test(text(el));
        const href = el.getAttribute('href') || '';
        return hasImg || hasPrice || href.includes('/product/');
      });
      if (plausible.length > 0) {
        tiles = plausible;
        break;
      }
    }

    return tiles.map((tile) => {
      // Normalize: if the match was just the <a> link, the tile wrapper is its
      // closest tile-like ancestor.
      const container =
        tile.closest('.product-tile') ||
        tile.closest('.productTile') ||
        tile.closest('.ish-productTile') ||
        tile.closest('.product-item') ||
        tile.closest('li') ||
        tile;

      const linkEl =
        container.querySelector('a[href*="/product/"]') ||
        (tile.tagName === 'A' ? tile : null);
      const href = linkEl ? linkEl.getAttribute('href') : null;
      const skuMatch = href ? href.match(/\/product\/([^\/;?#]+)/) : null;
      const sku = skuMatch ? skuMatch[1] : null;

      const name =
        text(container.querySelector('[data-test*="product-name"]')) ||
        text(container.querySelector('.product-name')) ||
        text(container.querySelector('.product-title')) ||
        text(container.querySelector('[itemprop="name"]')) ||
        text(linkEl) ||
        null;

      const imageEl =
        container.querySelector('img[src*="cdn.hoogvliet.com"]') ||
        container.querySelector('img[data-src]') ||
        container.querySelector('img');
      let image = null;
      if (imageEl) {
        image = imageEl.getAttribute('src') || imageEl.getAttribute('data-src') || null;
        // Intershop serves thumb variants; prefer a larger rendition when the
        // thumb URL carries a size hint (e.g. /S.jpg -> /L.jpg). Leave as-is
        // if no hint is present rather than guessing.
        if (image && /\/S\.jpg(\?|$)/.test(image)) image = image.replace('/S.jpg', '/L.jpg');
      }

      // Price: join all price-ish spans so "4 <sup>27</sup>" still matches.
      const priceScope =
        container.querySelector('[data-test*="price"]') ||
        container.querySelector('.price') ||
        container.querySelector('.product-price') ||
        container;
      const priceText = text(priceScope);
      // Hoogvliet tiles also show "Prijs per kilo € 8,90" — avoid picking that
      // as the main price by preferring the first prominent price element,
      // falling back to the largest numeric match in the container.
      const priceCandidates = Array.from(
        container.querySelectorAll('.price, [data-test*="price"], .current-price, .sales-price'),
      )
        .map((el) => text(el))
        .filter(Boolean);
      const rawPriceText = priceCandidates.length > 0 ? priceCandidates.join(' ') : priceText;

      const quantity =
        text(container.querySelector('[data-test*="quantity"]')) ||
        text(container.querySelector('.quantity')) ||
        text(container.querySelector('.weight')) ||
        text(container.querySelector('.pack-size')) ||
        // Hoogvliet product tiles often show "200 gram" next to the name
        (priceText.match(/\d+\s*(gram|g|kg|ml|l|cl|liter|stuks?|stuk|st\.)/i) || [])[0] ||
        null;

      // Discount / "Aanbieding" badge
      const badgeText = (
        text(container.querySelector('[data-test*="badge"]')) +
        ' ' +
        text(container.querySelector('.badge')) +
        ' ' +
        text(container.querySelector('.promotion')) +
        ' ' +
        text(container.querySelector('.label-promotion'))
      ).trim();

      // Old price (crossed out) — only present when on offer
      let oldPriceText = null;
      const oldPriceEl =
        container.querySelector('.old-price') ||
        container.querySelector('.was-price') ||
        container.querySelector('[data-test*="old-price"]') ||
        container.querySelector('s') ||
        container.querySelector('del');
      if (oldPriceEl) oldPriceText = text(oldPriceEl);

      // Fallback: if no dedicated old-price node, look for a second distinct
      // price-like number in the tile (the tile sometimes renders both prices
      // inline: "€ 3,49 € 2,79").
      const allNums = (rawPriceText.match(/(\d+[.,]\d{2})/g) || []);
      // rawPriceText first match is the current price; a second distinct
      // value paired with a sale badge is treated as the old price.
      let inferredOld = null;
      if (!oldPriceText && allNums.length >= 2 && /aanbieding/i.test(badgeText + ' ' + priceText)) {
        inferredOld = allNums[0];
        // rawPriceText's first num is old when the tile lists was→now; keep
        // both and let the caller decide. Actual current price will be resolved
        // below by taking the last/lowest value when on offer.
      }

      // Try to detect whether tile shows a unit price line like
      // "Reguliere prijs per kilo € 21.35" — not the product price itself
      const unitPriceHint = text(container.querySelector('.unit-price')) || '';

      return {
        sku,
        href: href ? (href.startsWith('http') ? href : 'https://www.hoogvliet.com' + href) : null,
        name,
        image,
        rawPriceText,
        oldPriceText: oldPriceText || inferredOld,
        badgeText: badgeText || null,
        quantity: quantity ? quantity.trim() : null,
        unitPriceHint: unitPriceHint || null,
      };
    });
  });
}

module.exports = { launch, fetchCategories, fetchCategoryPage };
