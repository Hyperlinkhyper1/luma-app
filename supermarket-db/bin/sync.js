const { closePool } = require('../src/database/connection');
const syncService = require('../src/services/syncService');

async function main() {
  const target = process.argv[2] || 'all';

  if (target === 'all') {
    const results = await syncService.syncAll();
    console.log(JSON.stringify(results, null, 2));
    return;
  }

  const result = await syncService.syncOne(target);
  console.log(JSON.stringify(result, null, 2));
}

main()
  .catch((error) => {
    console.error('Sync failed:', error);
    process.exitCode = 1;
  })
  .finally(() => closePool());
