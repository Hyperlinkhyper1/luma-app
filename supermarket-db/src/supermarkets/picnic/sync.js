const BaseSync = require('../baseSync');
const config = require('../../config/env');
const { searchProducts } = require('./picnicClient');
const { sleep } = require('../util');

const REQUEST_DELAY_MS = 400;

// Picnic has no reverse-engineered "list the whole catalog" endpoint left
// (see picnicClient.js's header comment) — this covers the assortment by
// searching a broad set of Dutch grocery terms instead and deduplicating
// by product id. An approximation of the full catalog, not a guaranteed-
// complete crawl the way Jumbo/AH's category trees are.
const CATEGORY_SEARCH_TERMS = [
  'groente', 'fruit', 'aardappelen', 'sla',
  'melk', 'kaas', 'yoghurt', 'eieren', 'boter', 'room',
  'vlees', 'kip', 'vis', 'vegetarisch', 'worst', 'vleeswaren',
  'brood', 'beleg', 'ontbijtgranen', 'muesli',
  'pasta', 'rijst', 'noedels', 'wereldkeuken', 'saus',
  'diepvries', 'ijs',
  'snoep', 'chocolade', 'koek', 'chips', 'noten',
  'koffie', 'thee', 'frisdrank', 'sap', 'water',
  'bier', 'wijn',
  'baby',
  'wasmiddel', 'schoonmaak', 'toiletpapier',
  'shampoo', 'tandpasta', 'deodorant',
  'hondenvoer', 'kattenvoer',
];

function mapProduct(unit, category) {
  const displayPrice = typeof unit.display_price === 'number' ? unit.display_price / 100 : null;
  // `price_ranges` holds per-quantity price tiers; the from_quantity: 1 tier
  // is the actual current per-unit charge, which sits below `display_price`
  // when the item is discounted. No `price_ranges` at all means there's no
  // separate current price to compare against.
  const baseTier = Array.isArray(unit.price_ranges)
    ? unit.price_ranges.find((tier) => tier.from_quantity === 1)
    : null;
  const price = baseTier ? baseTier.price / 100 : displayPrice;
  const isDiscounted = price !== null && displayPrice !== null && displayPrice > price;

  return {
    external_id: String(unit.id),
    barcode: null,
    name: unit.name,
    brand: null,
    description: null,
    category,
    subcategory: null,
    image_url: unit.image_id
      ? `https://storefront-prod.nl.picnicinternational.com/static/images/${unit.image_id}/medium.png`
      : null,
    // Picnic has no per-product web page (app-only).
    product_url: null,
    quantity: unit.unit_quantity || null,
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

    const byId = new Map();
    let sawAnySuccess = false;

    for (const term of CATEGORY_SEARCH_TERMS) {
      try {
        const units = await searchProducts(term, {
          username: config.picnic.username,
          password: config.picnic.password,
        });
        sawAnySuccess = true;
        for (const unit of units) {
          if (!unit.id || !unit.name) continue;
          byId.set(unit.id, mapProduct(unit, term));
        }
        await this.reportProgress(byId.size);
      } catch (error) {
        if (!sawAnySuccess) {
          // Every other term would fail identically (bad credentials, the
          // endpoint down, a changed response shape) — surface the real
          // error now instead of silently burning through all ~45 terms
          // just to land on the same generic "0 products" message anyway.
          throw new Error(`Picnic: search "${term}" failed: ${error.message}`);
        }
        // A later term failing on its own doesn't necessarily mean the
        // rest will too — log it and keep going rather than losing
        // everything collected so far.
        console.error(`Picnic sync: search "${term}" failed:`, error.message);
      }
      await sleep(REQUEST_DELAY_MS);
    }

    const products = Array.from(byId.values());
    if (products.length === 0) {
      throw new Error(
        'Picnic: every search request succeeded but found 0 products — Picnic likely ' +
          'changed the search-page-results response shape again (see findSellingUnits ' +
          'in picnicClient.js)'
      );
    }
    return products;
  }
}

module.exports = new PicnicSync();
