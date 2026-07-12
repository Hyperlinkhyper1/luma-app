const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');
const config = require('../config/env');

const MIGRATIONS_DIR = path.resolve(__dirname, 'migrations');

async function ensureMigrationsTable(connection) {
  await connection.query(`
    CREATE TABLE IF NOT EXISTS _migrations (
      id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
      name VARCHAR(255) NOT NULL UNIQUE,
      applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
  `);
}

async function getAppliedMigrations(connection) {
  const [rows] = await connection.query('SELECT name FROM _migrations');
  return new Set(rows.map((row) => row.name));
}

async function runMigrations() {
  const connection = await mysql.createConnection({
    host: config.db.host,
    port: config.db.port,
    user: config.db.user,
    password: config.db.password,
    database: config.db.database,
    multipleStatements: true,
  });

  try {
    await ensureMigrationsTable(connection);
    const applied = await getAppliedMigrations(connection);

    const files = fs
      .readdirSync(MIGRATIONS_DIR)
      .filter((file) => file.endsWith('.sql'))
      .sort();

    for (const file of files) {
      if (applied.has(file)) {
        continue;
      }

      const sql = fs.readFileSync(path.join(MIGRATIONS_DIR, file), 'utf8');
      console.log(`Applying migration: ${file}`);
      await connection.query(sql);
      await connection.query('INSERT INTO _migrations (name) VALUES (?)', [file]);
    }

    console.log('Migrations complete.');
  } finally {
    await connection.end();
  }
}

if (require.main === module) {
  runMigrations().catch((error) => {
    console.error('Migration failed:', error);
    process.exitCode = 1;
  });
}

module.exports = { runMigrations };
