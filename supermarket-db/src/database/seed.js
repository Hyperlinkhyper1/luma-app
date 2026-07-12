const { getPool, closePool } = require('./connection');

const SUPERMARKETS = [
  { name: 'Jumbo', slug: 'jumbo', website_url: 'https://www.jumbo.com' },
  { name: 'Albert Heijn', slug: 'ah', website_url: 'https://www.ah.nl' },
  { name: 'Lidl', slug: 'lidl', website_url: 'https://www.lidl.nl' },
];

async function seedSupermarkets() {
  const pool = getPool();
  for (const supermarket of SUPERMARKETS) {
    await pool.query(
      `INSERT INTO supermarkets (name, slug, website_url)
       VALUES (:name, :slug, :website_url)
       ON DUPLICATE KEY UPDATE name = VALUES(name), website_url = VALUES(website_url)`,
      supermarket
    );
  }
  console.log('Seeded supermarkets:', SUPERMARKETS.map((s) => s.slug).join(', '));
}

if (require.main === module) {
  seedSupermarkets()
    .catch((error) => {
      console.error('Seed failed:', error);
      process.exitCode = 1;
    })
    .finally(() => closePool());
}

module.exports = { seedSupermarkets };
