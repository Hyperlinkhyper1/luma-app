const { Supermarket, Product, ProductPrice, ProductHistory, SyncLog } = require('../models');

/**
 * Shared sync interface every supermarket module must implement.
 * Subclasses only need to implement `fetchProducts()` — everything
 * else (upserting, price-change detection, stale-product cleanup,
 * logging) is handled here so every supermarket behaves consistently.
 */
class BaseSync {
  constructor({ slug, name, websiteUrl = null, logoUrl = null }) {
    this.slug = slug;
    this.defaults = { name, website_url: websiteUrl, logo_url: logoUrl };
    this.supermarket = null;
  }

  async init() {
    if (!this.supermarket) {
      this.supermarket = await Supermarket.findOrCreateBySlug(this.slug, this.defaults);
    }
    return this.supermarket;
  }

  /**
   * Must be implemented per supermarket. Returns an array of raw
   * product records as fetched from that supermarket's API/feed, e.g.:
   * [{ external_id, barcode, name, brand, description, category,
   *    subcategory, image_url, product_url, quantity, unit,
   *    price, old_price, is_discounted, discount_percentage,
   *    discount_text, valid_from, valid_until }]
   */
  async fetchProducts() {
    throw new Error(`fetchProducts() is not implemented for supermarket "${this.slug}"`);
  }

  async getProducts(options = {}) {
    await this.init();
    return Product.findBySupermarket(this.supermarket.id, options);
  }

  /**
   * Upserts a batch of raw product records: inserts new products,
   * updates existing ones, records price snapshots, and logs price
   * changes into product_history.
   */
  async updateProducts(rawProducts) {
    await this.init();

    const stats = { checked: 0, added: 0, updated: 0, failed: 0 };

    for (const raw of rawProducts) {
      stats.checked += 1;
      try {
        const { id: productId, wasInserted } = await Product.upsert(
          this.supermarket.id,
          raw.external_id,
          raw
        );

        if (wasInserted) {
          stats.added += 1;
        } else {
          stats.updated += 1;
        }

        if (raw.price !== undefined && raw.price !== null) {
          const previousPrice = await ProductPrice.findLatestByProductId(productId);

          await ProductPrice.create({
            product_id: productId,
            price: raw.price,
            old_price: raw.old_price ?? previousPrice?.price ?? null,
            currency: raw.currency ?? 'EUR',
            is_discounted: Boolean(raw.is_discounted),
            discount_percentage: raw.discount_percentage ?? null,
            discount_text: raw.discount_text ?? null,
            valid_from: raw.valid_from ?? null,
            valid_until: raw.valid_until ?? null,
          });

          if (previousPrice && Number(previousPrice.price) !== Number(raw.price)) {
            await ProductHistory.create({
              product_id: productId,
              old_price: previousPrice.price,
              new_price: raw.price,
            });
          }
        }
      } catch (error) {
        stats.failed += 1;
        console.error(`Failed to upsert product ${raw.external_id} for ${this.slug}:`, error.message);
      }
    }

    return stats;
  }

  async syncProducts() {
    await this.init();
    const syncStartedAt = new Date();
    const logId = await SyncLog.start(this.supermarket.id);

    try {
      const rawProducts = await this.fetchProducts();
      if (rawProducts.length === 0) {
        // An empty result set means the fetch was silently blocked or the
        // site markup changed — never a real "the store sells nothing".
        // Fail the run instead of marking the whole catalog unavailable.
        throw new Error('fetchProducts returned 0 products; aborting sync to protect existing data');
      }
      const stats = await this.updateProducts(rawProducts);
      const staleCount = await Product.markStaleAsUnavailable(this.supermarket.id, syncStartedAt);

      await SyncLog.finish(logId, {
        products_checked: stats.checked,
        products_added: stats.added,
        products_updated: stats.updated,
        products_failed: stats.failed,
        status: 'success',
      });

      return { ...stats, markedUnavailable: staleCount };
    } catch (error) {
      await SyncLog.finish(logId, {
        status: 'failed',
        error_message: error.message,
      });
      throw error;
    }
  }
}

module.exports = BaseSync;
