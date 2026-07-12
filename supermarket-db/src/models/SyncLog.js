const { getPool } = require('../database/connection');

class SyncLog {
  static async start(supermarketId) {
    const [result] = await getPool().query(
      `INSERT INTO sync_logs (supermarket_id, status) VALUES (:supermarketId, 'running')`,
      { supermarketId }
    );
    return result.insertId;
  }

  static async finish(id, {
    products_checked = 0,
    products_added = 0,
    products_updated = 0,
    products_failed = 0,
    status = 'success',
    error_message = null,
  }) {
    await getPool().query(
      `UPDATE sync_logs
       SET finished_at = CURRENT_TIMESTAMP,
           products_checked = :products_checked,
           products_added = :products_added,
           products_updated = :products_updated,
           products_failed = :products_failed,
           status = :status,
           error_message = :error_message
       WHERE id = :id`,
      { id, products_checked, products_added, products_updated, products_failed, status, error_message }
    );
  }

  static async findRecentBySupermarket(supermarketId, { limit = 20 } = {}) {
    const [rows] = await getPool().query(
      `SELECT * FROM sync_logs WHERE supermarket_id = :supermarketId ORDER BY started_at DESC LIMIT :limit`,
      { supermarketId, limit }
    );
    return rows;
  }
}

module.exports = SyncLog;
