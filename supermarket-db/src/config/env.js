const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '..', '..', '.env') });

function required(name, fallback) {
  const value = process.env[name] ?? fallback;
  if (value === undefined) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

const config = {
  env: process.env.NODE_ENV || 'development',
  // Shared secret for the /admin endpoints. When unset, they are disabled
  // entirely rather than left open (mirrors the sync server's LUMA_ADMIN_KEY).
  adminKey: process.env.ADMIN_KEY || '',
  db: {
    host: required('DB_HOST', '127.0.0.1'),
    port: Number(process.env.DB_PORT || 3306),
    user: required('DB_USER', 'root'),
    password: process.env.DB_PASSWORD || '',
    database: required('DB_NAME', 'luma_supermarkets'),
    connectionLimit: Number(process.env.DB_CONNECTION_LIMIT || 10),
  },
};

module.exports = config;
