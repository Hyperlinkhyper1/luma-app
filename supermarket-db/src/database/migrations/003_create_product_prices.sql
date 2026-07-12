CREATE TABLE IF NOT EXISTS product_prices (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  product_id BIGINT UNSIGNED NOT NULL,
  price DECIMAL(10,2) NOT NULL,
  old_price DECIMAL(10,2) NULL,
  currency CHAR(3) NOT NULL DEFAULT 'EUR',
  is_discounted TINYINT(1) NOT NULL DEFAULT 0,
  discount_percentage DECIMAL(5,2) NULL,
  discount_text VARCHAR(255) NULL,
  valid_from DATETIME NULL,
  valid_until DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_product_prices_product FOREIGN KEY (product_id)
    REFERENCES products(id) ON DELETE CASCADE,
  KEY idx_product_prices_product (product_id),
  KEY idx_product_prices_valid (valid_from, valid_until)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
