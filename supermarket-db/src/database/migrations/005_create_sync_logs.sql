CREATE TABLE IF NOT EXISTS sync_logs (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  supermarket_id INT UNSIGNED NOT NULL,
  started_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  finished_at TIMESTAMP NULL,
  products_checked INT UNSIGNED NOT NULL DEFAULT 0,
  products_added INT UNSIGNED NOT NULL DEFAULT 0,
  products_updated INT UNSIGNED NOT NULL DEFAULT 0,
  products_failed INT UNSIGNED NOT NULL DEFAULT 0,
  status ENUM('running', 'success', 'failed') NOT NULL DEFAULT 'running',
  error_message TEXT NULL,
  CONSTRAINT fk_sync_logs_supermarket FOREIGN KEY (supermarket_id)
    REFERENCES supermarkets(id) ON DELETE CASCADE,
  KEY idx_sync_logs_supermarket (supermarket_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
