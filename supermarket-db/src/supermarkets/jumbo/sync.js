const BaseSync = require('../baseSync');
const { launch, fetchCategories, fetchCategoryPage } = require('./jumboClient');
const { sleep } = require('../util');

const REQUEST_DELAY_MS = 400;
const PAGE_SIZE = 24; // Jumbo's own grid page size, confirmed via offSet increments
const MAX_PAGES_PER_CATEGORY = 10;

function parsePrice(text) {
  const match = text && text.match(/(\d+),(\d{2})/);
  return match ? parseFloat(`${match[1]}.${match[2]}`) : null;
}

// Best-effort pull of a size/quantity chunk out of the card subtitle, e.g.
// "2+ dagen houdbaar • 4 x 2.4 liter" -> "4 x 2.4 liter". Not every product
// has one (sponsored cards sometimes only show durability text).
function extractQuantity(subtitle) {
  if (!subtitle) return null;
  const parts = subtitle.split('•').map((s) => s.trim()).filter(Boolean);
  return parts.find((p) => /\d/.test(p) && /\b(gram|kg|g|ml|l|cl|liter|stuks?|st\.|x\s*\d)\b/i.test(p)) || null;
}

function mapProduct(raw, { category, subcategory }) {
  const price = parsePrice(raw.currentPriceText);
  const oldPrice = raw.oldPriceText ? parsePrice(raw.oldPriceText) : null;
  const isDiscounted = oldPrice !== null;
  const discountMatch = raw.tagLines.join(' ').match(/(\d+)%\s*korting/i);
  return {
    external_id: raw.id,
    barcode: null,
    name: raw.name,
    brand: null, // Not exposed on the listing card; folded into `name` instead (e.g. "Campina ...").
    description: null, // Only on the product detail page — out of scope for a listing crawl.
    category,
    subcategory,
    image_url: raw.image,
    product_url: raw.url ? `https://www.jumbo.com${raw.url}` : null,
    quantity: extractQuantity(raw.subtitle),
    unit: null,
    price,
    old_price: isDiscounted ? oldPrice : null,
    currency: 'EUR',
    is_discounted: isDiscounted,
    discount_percentage: discountMatch ? Number(discountMatch[1]) : null,
    discount_text: raw.tagLines.length ? raw.tagLines.join(' ') : null,
    // The promo-period label on the card (e.g. "wo 17 jun t/m di 14 jul")
    // has no year and uses Dutch day/month abbreviations — not reliable
    // enough to parse into real dates, so these stay null like AH does
    // for non-promotional items.
    valid_from: null,
    valid_until: null,
  };
}

// Flattens the category tree to a crawl list: subcategories where they
// exist (giving each product a real category + subcategory), otherwise the
// top-level category itself (e.g. "Alles voor je BBQ!" has no subpages).
function flattenCategories(tree) {
  const leaves = [];
  for (const top of tree) {
    if (top.subpages && top.subpages.length > 0) {
      for (const sub of top.subpages) {
        leaves.push({ category: top.title, subcategory: sub.title, link: sub.link });
      }
    } else {
      leaves.push({ category: top.title, subcategory: null, link: top.link });
    }
  }
  return leaves;
}

class JumboSync extends BaseSync {
  constructor() {
    super({ slug: 'jumbo', name: 'Jumbo', websiteUrl: 'https://www.jumbo.com' });
  }

  async fetchProducts() {
    const { browser, page } = await launch();
    const byId = new Map();

    try {
      const tree = await fetchCategories(page);
      const leaves = flattenCategories(tree);

      for (const leaf of leaves) {
        let offset = 0;
        let pagesFetched = 0;

        while (pagesFetched < MAX_PAGES_PER_CATEGORY) {
          let items;
          try {
            items = await fetchCategoryPage(page, { link: leaf.link, offset });
          } catch (error) {
            const label = leaf.subcategory ? `${leaf.category} / ${leaf.subcategory}` : leaf.category;
            console.error(`Jumbo sync: failed on category ${label}, offset ${offset}:`, error.message);
            break; // Move on to the next category rather than aborting the whole sync.
          }

          if (items.length === 0) break;

          for (const raw of items) {
            if (!raw.id) continue;
            byId.set(raw.id, mapProduct(raw, leaf));
          }

          await this.reportProgress(byId.size);

          if (items.length < PAGE_SIZE) break; // last page for this category
          offset += PAGE_SIZE;
          pagesFetched += 1;
          await sleep(REQUEST_DELAY_MS);
        }
      }
    } finally {
      await browser.close();
    }

    return Array.from(byId.values());
  }
}

module.exports = new JumboSync();
