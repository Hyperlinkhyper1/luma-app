const BaseSync = require('../baseSync');
const { launch, fetchCategories, fetchCategoryPage } = require('./hoogvlietClient');
const { sleep } = require('../util');

const REQUEST_DELAY_MS = 350;
const PAGE_SIZE = 48;
const MAX_PAGES_PER_CATEGORY = 40;

function parsePrice(text) {
  if (!text) return null;
  // Hoogvliet tiles may render "4 . 27" (integer, dot, superscript cents) or
  // "2,39" — join all numeric fragments then normalize.
  // Prefer the last price-like number in the string when multiple are present
  // (the product price is usually the last prominent number; earlier ones are
  // often "prijs per kilo" helpers).
  const matches = text.match(/(\d+)\s*[.,]\s*(\d{2})/g);
  if (!matches || matches.length === 0) return null;
  const last = matches[matches.length - 1];
  const m = last.match(/(\d+)\s*[.,]\s*(\d{2})/);
  return m ? parseFloat(`${m[1]}.${m[2]}`) : null;
}

function parseOldPrice(raw) {
  if (!raw.oldPriceText) return null;
  return parsePrice(raw.oldPriceText);
}

function mapProduct(raw, { category }) {
  // Current price: try rawPriceText, falling back to oldPrice inference swap
  let price = parsePrice(raw.rawPriceText);
  let oldPrice = parseOldPrice(raw);

  // When tile shows both was and now inline (e.g. "€ 3,49 € 2,79"), the
  // scraping yields two numbers. If badge says Aanbieding and we only got
  // one combined string with two matches, the first is was, last is now.
  const nums = (raw.rawPriceText || '').match(/(\d+)\s*[.,]\s*(\d{2})/g) || [];
  if (nums.length >= 2 && raw.badgeText && /aanbieding/i.test(raw.badgeText)) {
    // rawPriceText contains e.g. "3,49 2,79" — first was old, last is current
    const first = parsePrice(nums[0]);
    const last = parsePrice(nums[nums.length - 1]);
    // Keep the lower one as current (discount is always cheaper), higher as old
    if (first !== null && last !== null) {
      if (first > last) {
        oldPrice = first;
        price = last;
      }
    }
  }

  const isDiscounted = oldPrice !== null && price !== null && oldPrice > price;
  const discountPct =
    isDiscounted && oldPrice > 0
      ? Math.round(((oldPrice - price) / oldPrice) * 100)
      : null;

  // Quantity: Hoogvliet tiles show pack size near name or as "200 gram".
  // Already extracted as a short "200 gram" string by the client.
  const quantity = raw.quantity || null;

  return {
    external_id: raw.sku || raw.href || raw.name,
    barcode: null,
    name: raw.name || 'Hoogvliet product',
    brand: null, // folded into name on listing tiles, like Jumbo
    description: null,
    category,
    subcategory: null,
    image_url: raw.image,
    product_url: raw.href || null,
    quantity,
    unit: null,
    price,
    old_price: isDiscounted ? oldPrice : null,
    currency: 'EUR',
    is_discounted: isDiscounted,
    discount_percentage: discountPct,
    discount_text: raw.badgeText || null,
    valid_from: null,
    valid_until: null,
  };
}

class HoogvlietSync extends BaseSync {
  constructor() {
    super({
      slug: 'hoogvliet',
      name: 'Hoogvliet',
      websiteUrl: 'https://www.hoogvliet.com',
    });
  }

  async fetchProducts() {
    const { browser, page } = await launch();
    const byId = new Map();

    try {
      const categories = await fetchCategories(page);
      if (categories.length === 0) {
        throw new Error('Hoogvliet: no categories found — homepage may have changed or bot challenge failed');
      }

      for (const cat of categories) {
        const label = `${cat.title || cat.categoryName} (${cat.categoryName})`;
        let pageNumber = 0;

        while (pageNumber < MAX_PAGES_PER_CATEGORY) {
          let tiles;
          try {
            tiles = await fetchCategoryPage(page, {
              categoryName: cat.categoryName,
              categoryTitle: cat.categoryTitle,
              pageNumber,
              pageSize: PAGE_SIZE,
            });
          } catch (error) {
            console.error(`Hoogvliet sync: failed on ${label} page ${pageNumber}:`, error.message);
            break;
          }

          if (tiles.length === 0) break;

          // Tiles that couldn't be given a usable id still get a fallback key
          // so they don't silently vanish from the sync entirely — the
          // external_id fallback to href/name keeps them addressable.
          for (const raw of tiles) {
            const id = raw.sku || raw.href || raw.name;
            if (!id) continue;
            // Prefer a tile that actually has a name/price over an empty stub
            const existing = byId.get(id);
            if (existing && !raw.name && existing.name) continue;
            if (!existing || raw.name) {
              byId.set(id, mapProduct(raw, { category: cat.title || cat.categoryName }));
            }
          }

          await this.reportProgress(byId.size);

          if (tiles.length < PAGE_SIZE) break; // last page for this category
          pageNumber += 1;
          await sleep(REQUEST_DELAY_MS);
        }
      }
    } finally {
      await browser.close();
    }

    return Array.from(byId.values());
  }
}

module.exports = new HoogvlietSync();
