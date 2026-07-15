const { getPool } = require('../database/connection');

const UPSERTABLE_FIELDS = [
  'barcode',
  'name',
  'brand',
  'description',
  'category',
  'subcategory',
  'image_url',
  'product_url',
  'quantity',
  'unit',
];

class Product {
  static async findById(id) {
    const [rows] = await getPool().query('SELECT * FROM products WHERE id = :id', { id });
    return rows[0] || null;
  }

  static async findByExternalId(supermarketId, externalId) {
    const [rows] = await getPool().query(
      'SELECT * FROM products WHERE supermarket_id = :supermarketId AND external_id = :externalId',
      { supermarketId, externalId }
    );
    return rows[0] || null;
  }

  static async findByBarcode(barcode) {
    const [rows] = await getPool().query('SELECT * FROM products WHERE barcode = :barcode', { barcode });
    return rows;
  }

  static async findBySupermarket(supermarketId, { limit = 100, offset = 0 } = {}) {
    const [rows] = await getPool().query(
      'SELECT * FROM products WHERE supermarket_id = :supermarketId ORDER BY name LIMIT :limit OFFSET :offset',
      { supermarketId, limit, offset }
    );
    return rows;
  }

  static async upsert(supermarketId, externalId, fields) {
    const data = { supermarket_id: supermarketId, external_id: externalId };
    for (const key of UPSERTABLE_FIELDS) {
      data[key] = fields[key] ?? null;
    }

    const columns = Object.keys(data);
    const placeholders = columns.map((col) => `:${col}`).join(', ');
    const updates = UPSERTABLE_FIELDS.map((col) => `${col} = VALUES(${col})`).join(', ');

    const [result] = await getPool().query(
      `INSERT INTO products (${columns.join(', ')}, is_available, last_seen_at)
       VALUES (${placeholders}, 1, CURRENT_TIMESTAMP)
       ON DUPLICATE KEY UPDATE ${updates}, is_available = 1, last_seen_at = CURRENT_TIMESTAMP`,
      data
    );

    const id = result.insertId || (await this.findByExternalId(supermarketId, externalId)).id;
    return { id, wasInserted: result.affectedRows === 1 };
  }

  static async markStaleAsUnavailable(supermarketId, syncStartedAt) {
    const [result] = await getPool().query(
      `UPDATE products
       SET is_available = 0
       WHERE supermarket_id = :supermarketId
         AND is_available = 1
         AND (last_seen_at IS NULL OR last_seen_at < :syncStartedAt)`,
      { supermarketId, syncStartedAt }
    );
    return result.affectedRows;
  }

  /**
   * Searches available products across one or more supermarkets, joined with
   * their market and latest price. Backs GET /api/products/search.
   */
  static async search({
    query = null,
    marketSlugs = null,
    category = null,
    onlyDiscounted = false,
    sort = 'relevance',
    limit = 40,
    offset = 0,
  } = {}) {
    const conditions = ['p.is_available = 1'];
    const params = { limit, offset };

    if (query) {
      conditions.push('(p.name LIKE :query OR p.brand LIKE :query)');
      params.query = `%${query}%`;
    }

    if (marketSlugs && marketSlugs.length > 0) {
      const placeholders = marketSlugs.map((_, i) => `:market${i}`).join(', ');
      conditions.push(`sm.slug IN (${placeholders})`);
      marketSlugs.forEach((slug, i) => {
        params[`market${i}`] = slug;
      });
    }

    if (category) {
      conditions.push('p.category = :category');
      params.category = category;
    }

    if (onlyDiscounted) {
      conditions.push('latest_price.is_discounted = 1');
    }

    // "Relevance" has no text-match ranking to fall back on (name/brand LIKE
    // gives every match equal weight), so it approximates usefulness with the
    // one real signal this catalog has: put items on sale first (deepest
    // discount first when known), then alphabetical.
    const orderBy =
      {
        relevance: 'latest_price.is_discounted DESC, latest_price.discount_percentage DESC, p.name ASC',
        price_asc: 'latest_price.price ASC',
        price_desc: 'latest_price.price DESC',
        name_asc: 'p.name ASC',
      }[sort] || 'p.name ASC';

    const [rows] = await getPool().query(
      `SELECT
         p.id, p.name, p.brand, p.description, p.category, p.subcategory,
         p.image_url, p.product_url, p.quantity, p.unit, p.barcode,
         sm.id AS market_id, sm.slug AS market_slug, sm.name AS market_name,
         sm.logo_url AS market_logo_url,
         latest_price.price, latest_price.old_price, latest_price.currency,
         latest_price.is_discounted, latest_price.discount_percentage,
         latest_price.discount_text
       FROM products p
       INNER JOIN supermarkets sm ON sm.id = p.supermarket_id
       LEFT JOIN (
         SELECT pp.*
         FROM product_prices pp
         INNER JOIN (
           SELECT product_id, MAX(id) AS max_id FROM product_prices GROUP BY product_id
         ) latest ON latest.max_id = pp.id
       ) latest_price ON latest_price.product_id = p.id
       WHERE ${conditions.join(' AND ')}
       ORDER BY ${orderBy}
       LIMIT :limit OFFSET :offset`,
      params
    );
    return rows;
  }

  /**
   * Distinct top-level categories for the sidebar filter, largest first —
   * there's no curated department list for this catalog, so category size
   * doubles as a stand-in for "how central this department is". Backs
   * GET /api/products/categories.
   */
  static async categories({ marketSlugs = null } = {}) {
    const conditions = ['p.is_available = 1', 'p.category IS NOT NULL'];
    const params = {};

    if (marketSlugs && marketSlugs.length > 0) {
      const placeholders = marketSlugs.map((_, i) => `:market${i}`).join(', ');
      conditions.push(`sm.slug IN (${placeholders})`);
      marketSlugs.forEach((slug, i) => {
        params[`market${i}`] = slug;
      });
    }

    const [rows] = await getPool().query(
      `SELECT p.category AS category, COUNT(*) AS count
       FROM products p
       INNER JOIN supermarkets sm ON sm.id = p.supermarket_id
       WHERE ${conditions.join(' AND ')}
       GROUP BY p.category
       ORDER BY count DESC, p.category ASC`,
      params
    );
    return rows;
  }
}

module.exports = Product;
