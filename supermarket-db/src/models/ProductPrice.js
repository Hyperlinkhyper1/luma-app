const { getPool } = require('../database/connection');

class ProductPrice {
  static async findLatestByProductId(productId) {
    const [rows] = await getPool().query(
      `SELECT * FROM product_prices
       WHERE product_id = :productId
       ORDER BY created_at DESC
       LIMIT 1`,
      { productId }
    );
    return rows[0] || null;
  }

  static async create({
    product_id,
    price,
    old_price = null,
    currency = 'EUR',
    is_discounted = false,
    discount_percentage = null,
    discount_text = null,
    valid_from = null,
    valid_until = null,
  }) {
    const [result] = await getPool().query(
      `INSERT INTO product_prices
        (product_id, price, old_price, currency, is_discounted, discount_percentage, discount_text, valid_from, valid_until)
       VALUES
        (:product_id, :price, :old_price, :currency, :is_discounted, :discount_percentage, :discount_text, :valid_from, :valid_until)`,
      {
        product_id,
        price,
        old_price,
        currency,
        is_discounted,
        discount_percentage,
        discount_text,
        valid_from,
        valid_until,
      }
    );
    return result.insertId;
  }

  static async findByProductId(productId, { limit = 50 } = {}) {
    const [rows] = await getPool().query(
      'SELECT * FROM product_prices WHERE product_id = :productId ORDER BY created_at DESC LIMIT :limit',
      { productId, limit }
    );
    return rows;
  }
}

module.exports = ProductPrice;
