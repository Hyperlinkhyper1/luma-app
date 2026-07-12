const mysql = require('mysql2/promise');
const config = require('../config/env');

let pool;

function getPool() {
  if (!pool) {
    pool = mysql.createPool({
      host: config.db.host,
      port: config.db.port,
      user: config.db.user,
      password: config.db.password,
      database: config.db.database,
      connectionLimit: config.db.connectionLimit,
      dateStrings: true,
      namedPlaceholders: true,
    });
  }
  return pool;
}

async function closePool() {
  if (pool) {
    await pool.end();
    pool = undefined;
  }
}

module.exports = { getPool, closePool };
