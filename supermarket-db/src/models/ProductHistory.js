const { getPool } = require('../database/connection');

class ProductHistory {
  static async create({ product_id, old_price, new_price }) {
    const [result] = await getPool().query(
      `INSERT INTO product_history (product_id, old_price, new_price)
       VALUES (:product_id, :old_price, :new_price)`,
      { product_id, old_price, new_price }
    );
    return result.insertId;
  }

  static async findByProductId(productId, { limit = 50 } = {}) {
    const [rows] = await getPool().query(
      'SELECT * FROM product_history WHERE product_id = :productId ORDER BY changed_at DESC LIMIT :limit',
      { productId, limit }
    );
    return rows;
  }
}

module.exports = ProductHistory;
