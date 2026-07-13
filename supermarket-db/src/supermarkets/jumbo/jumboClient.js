/**
 * Playwright-driven client for Jumbo's website (www.jumbo.com).
 *
 * Jumbo's mobile-app API (mobileapi.jumbo.com) sits behind Akamai bot
 * mitigation that blocks plain HTTP clients outright — every request came
 * back 404 then 403 within seconds in production, regardless of the
 * client's IP (see git history). The public website isn't gated the same
 * way against a real browser, so this drives an actual headless Chromium
 * instance instead: category pages render server-side (Nuxt SSR) with the
 * product grid already in the DOM, which is scraped directly rather than
 * depending on an internal API contract.
 */

const { chromium } = require('playwright');

const BASE_URL = 'https://www.jumbo.com';
const USER_AGENT =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36';

// Jumbo's own web client sends these on every /api/graphql call — the
// endpoint responds with a "No client headers set" error without them.
const GRAPHQL_HEADERS = {
  'content-type': 'application/json',
  'apollographql-client-name': 'JUMBO_WEB-search',
  'apollographql-client-version': 'master-v34.5.1-web',
  'x-source': 'JUMBO_WEB-search',
};

const CATEGORIES_QUERY = `query CategoriesTree($exclusions: [String!], $depth: Int = 2, $megaMenuEnabled: Boolean = true) {
  categoriesTree(exclusions: $exclusions, depth: $depth, megaMenuEnabled: $megaMenuEnabled) {
    title: name
    link: seoURL
    subpages: children {
      title: name
      link: seoURL
      __typename
    }
    __typename
  }
}`;

/** Launches a single browser + page for the duration of a sync run. */
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
  return { browser, page };
}

/**
 * Full category tree (top-level categories + one level of subcategories),
 * fetched through the site's own GraphQL endpoint from inside the page so
 * the request carries a real browser session/cookies.
 */
async function fetchCategories(page) {
  await page.goto(`${BASE_URL}/producten/`, { waitUntil: 'load', timeout: 60000 });
  const result = await page.evaluate(
    async ({ query, headers }) => {
      const res = await fetch('/api/graphql', {
        method: 'POST',
        headers,
        body: JSON.stringify({
          operationName: 'CategoriesTree',
          variables: { depth: 2, megaMenuEnabled: true },
          query,
        }),
      });
      return res.json();
    },
    { query: CATEGORIES_QUERY, headers: GRAPHQL_HEADERS }
  );
  if (result.errors) {
    throw new Error(`Jumbo categories request failed: ${result.errors.map((e) => e.message).join('; ')}`);
  }
  return result.data?.categoriesTree || [];
}

/**
 * One page of a category's product grid (server-rendered), scraped
 * straight from the DOM. Returns [] once `offset` runs past the last page.
 */
async function fetchCategoryPage(page, { link, offset = 0 } = {}) {
  const url = `${BASE_URL}${link}?offSet=${offset}`;
  const response = await page.goto(url, { waitUntil: 'load', timeout: 45000 });
  if (response && !response.ok()) {
    throw new Error(`Jumbo request failed: HTTP ${response.status()} for ${link}`);
  }
  await page.waitForTimeout(1200); // let the grid hydrate after SSR

  return page.evaluate(() => {
    const cards = Array.from(document.querySelectorAll('[data-testid^="product-card-"]'));
    return cards.map((card) => {
      const priceBlock = card.querySelector('[data-testid="product-price"]');
      const currentPriceText =
        priceBlock?.querySelector('.current-price .screenreader-only')?.textContent || null;
      const oldPriceText =
        priceBlock?.querySelector('.promo-price .screenreader-only')?.textContent || null;
      const tagLines = Array.from(card.querySelectorAll('.product-tags .tag-line')).map((el) =>
        el.textContent.trim()
      );
      return {
        id: card.getAttribute('data-product-id'),
        name: card.querySelector('.title-link')?.textContent?.trim() || null,
        url: card.querySelector('.title-link')?.getAttribute('href') || null,
        image: card.querySelector('[data-testid="jum-product-image"]')?.getAttribute('src') || null,
        subtitle: card.querySelector('[data-testid="jum-card-subtitle"] .text')?.textContent?.trim() || null,
        currentPriceText,
        oldPriceText,
        tagLines,
      };
    });
  });
}

module.exports = { launch, fetchCategories, fetchCategoryPage };
