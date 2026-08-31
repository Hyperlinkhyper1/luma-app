const BaseSync = require('../baseSync');
const config = require('../../config/env');
const { fetchCatalog, imageUrl } = require('./picnicClient');

function mapProduct(node, { category, subcategory }) {
  // Both prices arrive as integer cents; `display_price` is the shown/list
  // price and `price` is what's actually charged — equal when there's no
  // discount, `price < display_price` when there is one.
  const price = typeof node.price === 'number' ? node.price / 100 : null;
  const displayPrice = typeof node.display_price === 'number' ? node.display_price / 100 : null;
  const isDiscounted = price !== null && displayPrice !== null && displayPrice > price;

  return {
    external_id: String(node.id),
    barcode: null,
    name: node.name,
    brand: null,
    description: null,
    category,
    subcategory,
    image_url: imageUrl(node.image_id),
    // Picnic has no per-product web page (app-only), so there's nothing to
    // link to.
    product_url: null,
    quantity: node.unit_quantity || null,
    unit: null,
    price,
    old_price: isDiscounted ? displayPrice : null,
    currency: 'EUR',
    is_discounted: isDiscounted,
    discount_percentage: isDiscounted
      ? Math.round(((displayPrice - price) / displayPrice) * 100)
      : null,
    discount_text: null,
    valid_from: null,
    valid_until: null,
  };
}

/**
 * Recursively walks the `/my_store` category tree, collecting every
 * `SINGLE_ARTICLE` leaf. Category nesting is flattened to the same
 * two-level category/subcategory pair Jumbo/Hoogvliet use: the top-level
 * group name is `category`, and the first level below that is
 * `subcategory` — any deeper nesting keeps that same subcategory rather
 * than overwriting it, since BaseSync's schema has no room for a deeper
 * taxonomy.
 */
function walkCatalog(nodes, path, out) {
  for (const node of nodes || []) {
    if (node.type === 'SINGLE_ARTICLE') {
      out.push(mapProduct(node, path));
      continue;
    }
    if (!Array.isArray(node.items) || node.items.length === 0) continue;

    const nextPath =
      path.category === null
        ? { category: node.name, subcategory: null }
        : { category: path.category, subcategory: path.subcategory ?? node.name };
    walkCatalog(node.items, nextPath, out);
  }
}

class PicnicSync extends BaseSync {
  constructor() {
    super({ slug: 'picnic', name: 'Picnic', websiteUrl: 'https://picnic.app' });
  }

  async fetchProducts() {
    if (!config.picnic.username || !config.picnic.password) {
      throw new Error(
        'Picnic sync needs PICNIC_USERNAME/PICNIC_PASSWORD set in .env — Picnic has no ' +
          'anonymous API, so a real signed-up account is required first.'
      );
    }

    const catalog = await fetchCatalog({
      username: config.picnic.username,
      password: config.picnic.password,
    });

    const products = [];
    walkCatalog(catalog, { category: null, subcategory: null }, products);

    if (products.length === 0) {
      throw new Error(
        'Picnic: catalog crawl returned 0 products — login may have failed, or the ' +
          'category depth needs raising (see fetchCatalog in picnicClient.js)'
      );
    }

    await this.reportProgress(products.length);
    return products;
  }
}

module.exports = new PicnicSync();
