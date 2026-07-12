const BaseSync = require('../baseSync');

class JumboSync extends BaseSync {
  constructor() {
    super({ slug: 'jumbo', name: 'Jumbo', websiteUrl: 'https://www.jumbo.com' });
  }

  async fetchProducts() {
    // TODO: integrate with the Jumbo product API/feed and map its
    // response into the raw product shape documented in BaseSync.fetchProducts().
    return [];
  }
}

module.exports = new JumboSync();
