const BaseSync = require('../baseSync');
const { fetchCategories, fetchCategoryPage } = require('./hoogvlietClient');
const { sleep } = require('../util');

const MAX_PAGES_PER_CATEGORY = 200;

function mapProduct(raw, category) {
  const prices = raw.price_range?.minimum_price;
  const price = prices?.final_price?.value;
  const regular = prices?.regular_price?.value;
  if (!raw.sku || !raw.name || !Number.isFinite(price) || price < 0) {
    throw new Error(`Hoogvliet: invalid product ${raw.sku || '(missing SKU)'}`);
  }
  const discounted = Number.isFinite(regular) && regular > price;
  const quantity = raw.sub_title_attributes;
  return {
    external_id: String(raw.sku),
    barcode: raw.gtin13 || null,
    name: raw.display_name || raw.name,
    brand: raw.brand?.value || null,
    category,
    subcategory: raw.categories?.find((item) => item.level === 3)?.name || null,
    image_url: raw.small_image?.url || null,
    product_url: raw.product_link || raw.url_key
      ? new URL(raw.product_link || raw.url_key, 'https://hoogvliet.nl/').href : null,
    quantity: quantity ? [quantity.volume, quantity.unit].filter(Boolean).join(' ') || null : null,
    unit: quantity?.unit || null,
    price,
    old_price: discounted ? regular : null,
    currency: prices.final_price.currency || 'EUR',
    is_discounted: discounted,
    discount_percentage: discounted ? Math.round((regular - price) / regular * 100) : null,
    discount_text: raw.is_promotion ? raw.discount_label || null : null,
    valid_from: raw.is_promotion ? raw.promotion_meta_data?.valid_from || null : null,
    valid_until: raw.is_promotion ? raw.promotion_meta_data?.valid_to || null : null,
  };
}

class HoogvlietSync extends BaseSync {
  constructor() {
    super({ slug: 'hoogvliet', name: 'Hoogvliet', websiteUrl: 'https://hoogvliet.nl' });
  }

  async fetchProducts() {
    const categories = await fetchCategories();
    const byId = new Map();
    for (const category of categories) {
      const categoryIds = new Set();
      let totalPages = 1;
      let totalCount;
      for (let pageNumber = 1; pageNumber <= totalPages; pageNumber += 1) {
        const listing = await fetchCategoryPage({ path: category.path, pageNumber, expectedTotal: totalCount });
        if (listing.totalPages > MAX_PAGES_PER_CATEGORY) {
          throw new Error(`Hoogvliet: ${category.path} exceeds the ${MAX_PAGES_PER_CATEGORY}-page limit`);
        }
        if (totalCount !== undefined && listing.total_count !== totalCount) {
          throw new Error(`Hoogvliet: ${category.path} catalogue count changed from ${totalCount} to ${listing.total_count} on page ${pageNumber}; aborting to protect existing data`);
        }
        totalPages = listing.totalPages;
        totalCount = listing.total_count;
        const previousCount = categoryIds.size;
        for (const raw of listing.items) {
          const product = mapProduct(raw, category.name);
          categoryIds.add(product.external_id);
          byId.set(product.external_id, product);
        }
        if (categoryIds.size === previousCount) {
          throw new Error(`Hoogvliet: repeated catalogue page for ${category.path} page ${pageNumber}`);
        }
        await this.reportProgress(byId.size);
        await sleep(350);
      }
      if (categoryIds.size !== totalCount) {
        throw new Error(`Hoogvliet: incomplete ${category.path} catalogue (${categoryIds.size}/${totalCount})`);
      }
    }
    return Array.from(byId.values());
  }
}

module.exports = new HoogvlietSync();
