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

  // Heartbeat while a run is in flight: bumps last_progress_at and the
  // live checked-count so a healthy long crawl is distinguishable from a
  // dead one. Only touches rows still marked running.
  static async progress(id, { products_checked = 0 } = {}) {
    await getPool().query(
      `UPDATE sync_logs
       SET last_progress_at = CURRENT_TIMESTAMP,
           products_checked = :products_checked
       WHERE id = :id AND status = 'running'`,
      { id, products_checked }
    );
  }

  // Startup recovery: syncs run inside the API process, so any row still
  // 'running' when the service boots belongs to a run that died with the
  // previous process (crash, OOM kill, restart/deploy).
  static async failAbandonedRuns() {
    const [result] = await getPool().query(
      `UPDATE sync_logs
       SET status = 'failed',
           finished_at = CURRENT_TIMESTAMP,
           error_message = 'Sync never finished — service restarted mid-run'
       WHERE status = 'running'`
    );
    return result.affectedRows;
  }

  // Hung-run recovery: a run that is still 'running' but hasn't reported
  // progress for a while (e.g. a wedged headless browser) gets failed so
  // the panel doesn't show it as running forever.
  static async failStaleRuns({ staleMinutes = 15 } = {}) {
    const [result] = await getPool().query(
      `UPDATE sync_logs
       SET status = 'failed',
           finished_at = CURRENT_TIMESTAMP,
           error_message = CONCAT('Sync stalled — no progress for over ', :staleMinutes, ' minutes')
       WHERE status = 'running'
         AND COALESCE(last_progress_at, started_at) < NOW() - INTERVAL :staleMinutes MINUTE`,
      { staleMinutes }
    );
    return result.affectedRows;
  }

  static async findRecentBySupermarket(supermarketId, { limit = 20 } = {}) {
    const [rows] = await getPool().query(
      `SELECT * FROM sync_logs WHERE supermarket_id = :supermarketId ORDER BY started_at DESC LIMIT :limit`,
      { supermarketId, limit }
    );
    return rows;
  }

  // Recent runs across every supermarket, newest first, with the market's
  // name/slug joined in. Backs the admin control panel's history table.
  static async findRecent({ limit = 20 } = {}) {
    const [rows] = await getPool().query(
      `SELECT sl.*, sm.name AS supermarket_name, sm.slug AS supermarket_slug
       FROM sync_logs sl
       INNER JOIN supermarkets sm ON sm.id = sl.supermarket_id
       ORDER BY sl.started_at DESC, sl.id DESC
       LIMIT :limit`,
      { limit }
    );
    return rows;
  }
}

module.exports = SyncLog;
