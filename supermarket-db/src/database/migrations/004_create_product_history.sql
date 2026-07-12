CREATE TABLE IF NOT EXISTS product_history (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  product_id BIGINT UNSIGNED NOT NULL,
  old_price DECIMAL(10,2) NULL,
  new_price DECIMAL(10,2) NOT NULL,
  changed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_product_history_product FOREIGN KEY (product_id)
    REFERENCES products(id) ON DELETE CASCADE,
  KEY idx_product_history_product (product_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
