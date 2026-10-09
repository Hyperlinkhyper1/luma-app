const jumboSync = require('../supermarkets/jumbo/sync');
const ahSync = require('../supermarkets/ah/sync');
const lidlSync = require('../supermarkets/lidl/sync');
const hoogvlietSync = require('../supermarkets/hoogvliet/sync');

const MODULES = {
  jumbo: jumboSync,
  ah: ahSync,
  lidl: lidlSync,
  hoogvliet: hoogvlietSync,
};

class SyncService {
  constructor() {
    this.running = new Set();
  }

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

  async syncOne(slug) {
    const module = this.getModule(slug);
    if (this.isRunning(slug)) {
      throw new Error(`A ${slug} sync is already running; not starting another one.`);
    }
    this.running.add(slug);
    try {
      return await module.syncProducts();
    } finally {
      this.running.delete(slug);
    }
  }

  isRunning(slug) {
    return this.running.has(slug) || Boolean(this.getModule(slug).isRunning);
  }

  async syncAll() {
    const results = {};
    await Promise.all(this.slugs.map(async (slug) => {
      try {
        results[slug] = await this.syncOne(slug);
      } catch (error) {
        results[slug] = { error: error.message };
      }
    }));
    return results;
  }
}

module.exports = new SyncService();
