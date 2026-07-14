const jumboSync = require('../supermarkets/jumbo/sync');
const ahSync = require('../supermarkets/ah/sync');
const lidlSync = require('../supermarkets/lidl/sync');

const MODULES = {
  jumbo: jumboSync,
  ah: ahSync,
  lidl: lidlSync,
};

class SyncService {
  get slugs() {
    return Object.keys(MODULES);
  }

  getModule(slug) {
    const module = MODULES[slug];
    if (!module) {
      throw new Error(`Unknown supermarket "${slug}". Available: ${Object.keys(MODULES).join(', ')}`);
    }
    return module;
  }

  isRunning(slug) {
    return this.getModule(slug).isRunning;
  }

  async syncOne(slug) {
    const module = this.getModule(slug);
    return module.syncProducts();
  }

  async syncAll() {
    const results = {};
    for (const slug of Object.keys(MODULES)) {
      if (this.isRunning(slug)) {
        results[slug] = { skipped: 'already running' };
        continue;
      }
      try {
        results[slug] = await this.syncOne(slug);
      } catch (error) {
        results[slug] = { error: error.message };
      }
    }
    return results;
  }
}

module.exports = new SyncService();
