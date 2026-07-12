const BaseSync = require('../baseSync');

class AhSync extends BaseSync {
  constructor() {
    super({ slug: 'ah', name: 'Albert Heijn', websiteUrl: 'https://www.ah.nl' });
  }

  async fetchProducts() {
    // TODO: integrate with the Albert Heijn product API/feed and map its
    // response into the raw product shape documented in BaseSync.fetchProducts().
    return [];
  }
}

module.exports = new AhSync();
