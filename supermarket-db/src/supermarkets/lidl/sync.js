const BaseSync = require('../baseSync');

class LidlSync extends BaseSync {
  constructor() {
    super({ slug: 'lidl', name: 'Lidl', websiteUrl: 'https://www.lidl.nl' });
  }

  async fetchProducts() {
    // TODO: integrate with the Lidl product API/feed and map its
    // response into the raw product shape documented in BaseSync.fetchProducts().
    return [];
  }
}

module.exports = new LidlSync();
