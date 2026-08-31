const BaseSync = require('../baseSync');
const { fetchHighlightedDeals } = require('./lidlClient');

function parseDiscountPercentage(text) {
  if (!text) return null;
  const match = text.match(/-?(\d+)\s*%/);
  return match ? Number(match[1]) : null;
}

// Lidl's storeStartDate/storeEndDate are Unix seconds for local Amsterdam
// midnight (e.g. 1788127200 = 2026-08-30T22:00:00Z = 2026-08-31T00:00:00
// Europe/Amsterdam) — formatting in UTC would silently shift every date
// back a day during CEST. en-CA gives a plain YYYY-MM-DD.
const dateFormatter = new Intl.DateTimeFormat('en-CA', {
  timeZone: 'Europe/Amsterdam',
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
});

function toIsoDate(epochSeconds) {
  if (!epochSeconds) return null;
  return dateFormatter.format(new Date(epochSeconds * 1000));
}

// Regular items carry their price directly under `price.price`. Lidl Plus
// member-only prices live one level deeper instead, under
// `lidlPlus[0].price` — the top-level `price` object is left with no
// `.price` field at all in that case (verified live 2026-08-31, e.g.
// "Kipdijfilet").
function resolvePrice(record) {
  if (record.price && record.price.price !== undefined) {
    return { priceObj: record.price, isLidlPlusPrice: false, lidlPlusText: null };
  }
  const lidlPlusEntry = record.lidlPlus && record.lidlPlus[0];
  if (lidlPlusEntry && lidlPlusEntry.price) {
    return {
      priceObj: lidlPlusEntry.price,
      isLidlPlusPrice: true,
      lidlPlusText: lidlPlusEntry.lidlPlusText,
    };
  }
  return { priceObj: null, isLidlPlusPrice: false, lidlPlusText: null };
}

function mapProduct(record) {
  const { priceObj, isLidlPlusPrice, lidlPlusText } = resolvePrice(record);
  const price = priceObj ? priceObj.price : null;
  const discount = priceObj ? priceObj.discount : null;
  // `deletedPrice`/`oldPrice` show up as `0` (not absent) on non-discounted
  // tiles — a real markdown always has a positive value above the current
  // price.
  const oldPrice = discount && discount.deletedPrice > 0 ? discount.deletedPrice : null;
  const hasMarkdown = oldPrice !== null && price !== null && oldPrice > price;

  const discountParts = [];
  if (discount && discount.discountText) discountParts.push(discount.discountText);
  if (isLidlPlusPrice) discountParts.push(lidlPlusText || 'Met Lidl Plus');

  return {
    external_id: String(record.productId ?? record.itemId),
    barcode: null,
    name: record.title || record.fullTitle || 'Lidl product',
    brand: null,
    description: record.imageList_V1?.[0]?.accessibility || null,
    category: record.keyfacts?.analyticsCategory || record.category || null,
    subcategory: null,
    image_url: record.image || null,
    product_url: record.canonicalUrl ? `https://www.lidl.nl${record.canonicalUrl}` : null,
    quantity: priceObj?.packaging?.text || null,
    unit: null,
    price,
    old_price: hasMarkdown ? oldPrice : null,
    currency: priceObj?.currencyCode || 'EUR',
    // Every record scraped here comes from the "this week's offers" hub
    // page — being featured there is the whole reason it was fetched, so
    // it's always a deal even when Lidl shows no separate "was" price.
    // This differs from Jumbo/AH/Hoogvliet, where is_discounted means a
    // real markdown against a stable catalog price; Lidl has no such
    // catalog.
    is_discounted: true,
    discount_percentage: parseDiscountPercentage(discount?.discountText),
    discount_text: discountParts.length ? discountParts.join(' · ') : null,
    valid_from: toIsoDate(record.storeStartDate),
    valid_until: toIsoDate(record.storeEndDate),
  };
}

class LidlSync extends BaseSync {
  constructor() {
    super({ slug: 'lidl', name: 'Lidl', websiteUrl: 'https://www.lidl.nl' });
  }

  async fetchProducts() {
    const records = await fetchHighlightedDeals();
    if (records.length === 0) {
      throw new Error(
        'Lidl: no deals found on the Aanbiedingen page — layout may have changed'
      );
    }

    const byId = new Map();
    for (const record of records) {
      const id = record.productId ?? record.itemId;
      if (!id || !record.title) continue;
      byId.set(id, mapProduct(record));
    }

    const products = Array.from(byId.values());
    await this.reportProgress(products.length);
    return products;
  }
}

module.exports = new LidlSync();
