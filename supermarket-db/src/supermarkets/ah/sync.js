const BaseSync = require('../baseSync');
const { fetchCategories, searchProducts } = require('./ahClient');
const { sleep, stripHtml } = require('../util');

// Be a reasonable citizen against an undocumented API: small delay between
// paged requests, and a hard cap on pages/category as a sanity backstop
// (categories here max out around a few thousand products at size=100).
const REQUEST_DELAY_MS = 200;
const MAX_PAGES_PER_CATEGORY = 200;

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

    for (const category of categories) {
      let page = 0;
      let totalPages = 1;

      while (page < totalPages && page < MAX_PAGES_PER_CATEGORY) {
        try {
          const result = await searchProducts({
            taxonomyId: category.id,
            page,
            size: 100,
          });
          totalPages = result.page?.totalPages ?? 1;
          for (const raw of result.products || []) {
            byId.set(raw.webshopId, mapProduct(raw));
          }
          await this.reportProgress(byId.size);
        } catch (error) {
          console.error(
            `AH sync: failed on category ${category.name} (id ${category.id}), page ${page}:`,
            error.message
          );
          break; // Move on to the next category rather than aborting the whole sync.
        }
        page += 1;
        await sleep(REQUEST_DELAY_MS);
      }
    }

    return Array.from(byId.values());
  }
}

module.exports = new AhSync();
