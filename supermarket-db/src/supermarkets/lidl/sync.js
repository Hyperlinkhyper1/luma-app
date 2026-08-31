const BaseSync = require('../baseSync');
const { launch, fetchHighlightedDeals } = require('./lidlClient');

function parsePrice(text) {
  if (!text) return null;
  const match = text.match(/(\d+)[.,](\d{2})/);
  return match ? parseFloat(`${match[1]}.${match[2]}`) : null;
}

function parseDiscountPercentage(text) {
  if (!text) return null;
  const match = text.match(/-?(\d+)\s*%/);
  return match ? Number(match[1]) : null;
}

// Availability badges read "Alleen in de winkel [vanaf ]DD/MM - DD/MM" — the
// one real validity window Lidl's highlight tiles expose (Jumbo/AH/Hoogvliet
// have no equivalent and always leave these null, see their sync.js files).
// No year is printed, so the scrape year is assumed; a range that wraps
// past December rolls the end date into the following year.
function parseValidityWindow(text, referenceDate) {
  if (!text) return { validFrom: null, validUntil: null };
  const match = text.match(/(\d{2})\/(\d{2})\s*-\s*(\d{2})\/(\d{2})/);
  if (!match) return { validFrom: null, validUntil: null };
  const [, fromDay, fromMonth, untilDay, untilMonth] = match;
  const year = referenceDate.getFullYear();
  const untilYear = Number(untilMonth) < Number(fromMonth) ? year + 1 : year;
  return {
    validFrom: `${year}-${fromMonth}-${fromDay}`,
    validUntil: `${untilYear}-${untilMonth}-${untilDay}`,
  };
}

function mapProduct(raw, referenceDate) {
  const price = raw.price;
  const oldPrice = parsePrice(raw.oldPriceText);
  const hasMarkdown = oldPrice !== null && price !== null && oldPrice > price;
  const discountPercentage = parseDiscountPercentage(raw.discountText);
  const { validFrom, validUntil } = parseValidityWindow(raw.availabilityText, referenceDate);

  const discountParts = [];
  if (raw.discountText) discountParts.push(raw.discountText);
  if (raw.isLidlPlusPrice) discountParts.push('Met Lidl Plus');

  return {
    external_id: raw.id || raw.href || raw.name,
    barcode: null,
    name: raw.name || 'Lidl product',
    brand: null,
    description: raw.desc,
    category: raw.category,
    subcategory: null,
    image_url: raw.image,
    product_url: raw.href ? `https://www.lidl.nl${raw.href}` : null,
    quantity: raw.quantity,
    unit: null,
    price,
    old_price: hasMarkdown ? oldPrice : null,
    currency: 'EUR',
    // Every tile scraped here comes from the "this week's offers" hub page —
    // being featured there is the whole reason it was fetched, so it's
    // always a deal even when Lidl shows no separate "was" price. This
    // differs from Jumbo/AH/Hoogvliet, where is_discounted means a real
    // markdown against a stable catalog price; Lidl has no such catalog.
    is_discounted: true,
    discount_percentage: discountPercentage,
    discount_text: discountParts.length ? discountParts.join(' · ') : null,
    valid_from: validFrom,
    valid_until: validUntil,
  };
}

class LidlSync extends BaseSync {
  constructor() {
    super({ slug: 'lidl', name: 'Lidl', websiteUrl: 'https://www.lidl.nl' });
  }

  async fetchProducts() {
    const { browser, page } = await launch();
    try {
      const referenceDate = new Date();
      const rawDeals = await fetchHighlightedDeals(page);
      if (rawDeals.length === 0) {
        throw new Error(
          'Lidl: no highlighted deals found on the Aanbiedingen page — layout may have changed'
        );
      }

      const products = rawDeals
        .filter((raw) => raw.id && raw.name)
        .map((raw) => mapProduct(raw, referenceDate));

      await this.reportProgress(products.length);
      return products;
    } finally {
      await browser.close();
    }
  }
}

module.exports = new LidlSync();
