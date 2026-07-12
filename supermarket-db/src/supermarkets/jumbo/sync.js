const BaseSync = require('../baseSync');
const { searchProducts } = require('./jumboClient');
const { sleep, stripHtml } = require('../util');

// Jumbo's search API only supports free-text queries (no confirmed
// "products by category" endpoint), so full-catalog coverage is
// approximated by searching a broad list of common Dutch grocery terms
// instead of a handful of keywords. Not exhaustive, but wide enough to
// pick up the bulk of the assortment; dedup by product id below covers
// terms that overlap.
const SEARCH_TERMS = [
  'zuivel', 'melk', 'kaas', 'yoghurt', 'boter',
  'groente', 'aardappelen', 'fruit', 'sla',
  'vlees', 'kip', 'vis', 'vega', 'vegan',
  'brood', 'bakkerij', 'beleg',
  'pasta', 'rijst', 'wereldkeuken',
  'diepvries', 'ijs',
  'snoep', 'chocolade', 'koek', 'chips',
  'frisdrank', 'sap', 'water', 'koffie', 'thee', 'bier', 'wijn',
  'soep', 'saus', 'conserven',
  'ontbijt', 'granen',
  'baby', 'drogisterij', 'huishouden', 'verzorging',
];

const REQUEST_DELAY_MS = 250;
const PAGE_SIZE = 30; // matches the mobile app's own page size
const MAX_PAGES_PER_TERM = 10;

function mapProduct(raw) {
  // Assumes prices.*.amount is already decimal euros (e.g. 2.29), matching
  // every other Dutch grocery API checked while building this (AH confirmed
  // live). Unverified for Jumbo specifically — Jumbo's endpoint couldn't be
  // reached from the sandbox this was written in (see jumboClient.js). If a
  // real sync shows prices ~100x too high, this is dividing by 100 that's
  // needed, not this euros assumption being fundamentally wrong.
  const basePrice = raw.prices?.price?.amount ?? null;
  const promoPrice = raw.prices?.promotionalPrice?.amount ?? null;
  const isDiscounted = promoPrice !== null;
  return {
    external_id: String(raw.id),
    barcode: null,
    name: raw.title,
    brand: raw.brandInfo?.brandDescription || null,
    description: stripHtml(raw.detailsText),
    category: raw.topLevelCategory || null,
    subcategory: null,
    image_url: raw.imageInfo?.primaryView?.[0]?.url || null,
    product_url: null,
    quantity: raw.quantity || null,
    unit: null,
    price: isDiscounted ? promoPrice : basePrice,
    old_price: isDiscounted ? basePrice : null,
    currency: raw.prices?.price?.currency || 'EUR',
    is_discounted: isDiscounted,
    discount_percentage: null,
    discount_text: null,
    valid_from: null,
    valid_until: null,
  };
}

class JumboSync extends BaseSync {
  constructor() {
    super({ slug: 'jumbo', name: 'Jumbo', websiteUrl: 'https://www.jumbo.com' });
  }

  async fetchProducts() {
    const byId = new Map();

    for (const term of SEARCH_TERMS) {
      let offset = 0;
      let total = Infinity;
      let pagesFetched = 0;

      while (offset < total && pagesFetched < MAX_PAGES_PER_TERM) {
        try {
          const result = await searchProducts({ query: term, offset, limit: PAGE_SIZE });
          total = result.total ?? 0;
          for (const raw of result.data || []) {
            byId.set(raw.id, mapProduct(raw));
          }
        } catch (error) {
          console.error(`Jumbo sync: failed on term "${term}", offset ${offset}:`, error.message);
          break; // Move on to the next term rather than aborting the whole sync.
        }
        offset += PAGE_SIZE;
        pagesFetched += 1;
        await sleep(REQUEST_DELAY_MS);
      }
    }

    return Array.from(byId.values());
  }
}

module.exports = new JumboSync();
