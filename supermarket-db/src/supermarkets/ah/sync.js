const BaseSync = require('../baseSync');
const { fetchCategories, searchProducts } = require('./ahClient');
const { sleep, stripHtml } = require('../util');

// Be a reasonable citizen against an undocumented API: small delay between
// paged requests, and a hard cap on pages/category as a sanity backstop
// (categories here max out around a few thousand products at size=100).
const REQUEST_DELAY_MS = 200;
const MAX_PAGES_PER_CATEGORY = 200;
const MAX_EMPTY_CATEGORY_RATIO = 0.2;
const PAGE_SIZE = 100;

// AH only serves the first 3000 results of any one search: a page starting at
// or past it answers HTTP 400. A bigger category (Soepen, sauzen, kruiden,
// olie has ~3300) is read from both ends instead, cheapest-first and then
// dearest-first, which reaches up to twice the window. Subcategory searches
// are no substitute: a subcategory searched on its own also returns products
// filed under other top-level categories, so nothing could prove the union
// covered the category. Here every result is in the category, so the unique
// count has to reach AH's total exactly.
const MAX_RESULT_WINDOW = 3000;
const BOTH_ENDS = ['PRICELOWHIGH', 'PRICEHIGHLOW'];

function bestImage(images) {
  if (!images || images.length === 0) return null;
  // Prefer a mid-size image; falls back to the first one available.
  const preferred = images.find((img) => img.width === 400) || images[0];
  return preferred.url;
}

function mapProduct(raw) {
  const price = raw.currentPrice ?? raw.priceBeforeBonus ?? null;
  const isDiscounted = Boolean(raw.isBonus);
  return {
    external_id: String(raw.webshopId),
    barcode: null,
    name: raw.title,
    brand: raw.brand || null,
    description: stripHtml(raw.descriptionHighlights),
    category: raw.mainCategory || null,
    subcategory: raw.subCategory || null,
    image_url: bestImage(raw.images),
    product_url: `https://www.ah.nl/producten/product/wi${raw.webshopId}`,
    quantity: raw.salesUnitSize || null,
    unit: null,
    price,
    old_price: isDiscounted ? raw.priceBeforeBonus ?? null : null,
    currency: 'EUR',
    is_discounted: isDiscounted,
    discount_percentage: null,
    discount_text: raw.bonusMechanism || raw.bonusPeriodDescription || null,
    valid_from: raw.bonusStartDate || null,
    valid_until: raw.bonusEndDate || null,
  };
}

class AhSync extends BaseSync {
  constructor() {
    super({ slug: 'ah', name: 'Albert Heijn', websiteUrl: 'https://www.ah.nl' });
  }

  async fetchProducts() {
    const categories = await fetchCategories();
    const byId = new Map();
    const emptyCategories = [];

    for (const category of categories) {
      const seenInCategory = new Set();
      const state = { category, byId, seenInCategory, pages: 0 };
      const total = await this.crawlCategory(state);
      if (seenInCategory.size === 0) emptyCategories.push(category.name);
      else if (total > MAX_RESULT_WINDOW && seenInCategory.size < total) {
        throw new Error(
          `AH sync: incomplete category ${category.name}: AH reports ${total} products but only ` +
            `${seenInCategory.size} were reachable reading its ${MAX_RESULT_WINDOW}-result search ` +
            'window from both ends'
        );
      }
    }

    if (emptyCategories.length > categories.length * MAX_EMPTY_CATEGORY_RATIO) {
      throw new Error(
        `AH sync: ${emptyCategories.length} of ${categories.length} categories returned ` +
          'no products (AH is most likely refusing tokens); aborting rather than ' +
          `syncing a partial catalog. First few: ${emptyCategories.slice(0, 5).join(', ')}`
      );
    }

    return Array.from(byId.values());
  }

  async searchPage(state, page, sortOn) {
    if (state.pages >= MAX_PAGES_PER_CATEGORY) {
      throw new Error(`AH sync: category ${state.category.name} needed more than ${MAX_PAGES_PER_CATEGORY} pages`);
    }
    state.pages += 1;
    try {
      const result = await searchProducts({ taxonomyId: state.category.id, page, size: PAGE_SIZE, sortOn });
      for (const raw of result.products || []) {
        state.byId.set(raw.webshopId, mapProduct(raw));
        state.seenInCategory.add(raw.webshopId);
      }
      await this.reportProgress(state.byId.size);
      await sleep(REQUEST_DELAY_MS);
      return result;
    } catch (error) {
      const order = sortOn ? ` (${sortOn})` : '';
      console.error(
        `AH sync: failed on category ${state.category.name} (id ${state.category.id}), page ${page}${order}:`,
        error.message
      );
      throw new Error(`AH sync: incomplete category ${state.category.name}, page ${page}${order}: ${error.message}`);
    }
  }

  /** Crawls one top-level category; returns the total AH reports for it. */
  async crawlCategory(state) {
    const reachable = Math.floor(MAX_RESULT_WINDOW / PAGE_SIZE);
    const first = await this.searchPage(state, 0);
    const total = first.page?.totalElements ?? 0;
    if (total <= MAX_RESULT_WINDOW) {
      const totalPages = Math.min(first.page?.totalPages ?? 1, reachable);
      for (let page = 1; page < totalPages; page += 1) await this.searchPage(state, page);
      return total;
    }
    if (total > 2 * MAX_RESULT_WINDOW) {
      throw new Error(
        `AH sync: category ${state.category.name} has ${total} products, more than reading its ` +
          `${MAX_RESULT_WINDOW}-result search window from both ends can reach`
      );
    }
    for (const sortOn of BOTH_ENDS) {
      for (let page = 0; page < reachable && state.seenInCategory.size < total; page += 1) {
        await this.searchPage(state, page, sortOn);
      }
    }
    return total;
  }
}

module.exports = new AhSync();
