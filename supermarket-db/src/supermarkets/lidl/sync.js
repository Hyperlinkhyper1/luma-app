const BaseSync = require('../baseSync');

class LidlSync extends BaseSync {
  constructor() {
    super({ slug: 'lidl', name: 'Lidl', websiteUrl: 'https://www.lidl.nl' });
  }

  async fetchProducts() {
    // Still a stub, unlike jumbo/ and ah/ — Lidl NL doesn't run a general
    // online grocery catalog/webshop the way AH and Jumbo do (their NL app
    // is mainly weekly-flyer deals + the separate "Lidl Plus" loyalty
    // program, which is about a signed-in user's own receipts/coupons, not
    // product browsing). No free/public product-search API was found;
    // every option surfaced during research was a paid third-party
    // scraping service. Getting real Lidl data would mean either browser
    // automation against their site (fragile, needs a headless-browser
    // dependency, more ToS-sensitive) or paying for one of those services —
    // a meaningfully different, separate task from the Jumbo/AH work.
    return [];
  }
}

module.exports = new LidlSync();
