// Read-only provider check: no database connection or product writes.
const ah = require('../src/supermarkets/ah/ahClient');
const hoogvliet = require('../src/supermarkets/hoogvliet/hoogvlietClient');

async function check(name, run) {
  try {
    console.log(`${name}: ${await run()}`);
  } catch (error) {
    console.error(`${name}: ${error.message}`);
    process.exitCode = 1;
  }
}

Promise.all([
  check('AH', async () => {
    const categories = await ah.fetchCategories();
    if (!Array.isArray(categories) || !categories.length) throw new Error('no categories');
    const listing = await ah.searchProducts({ taxonomyId: categories[0].id, size: 10 });
    if (!listing.products?.length) throw new Error('no products in first category');
    return `${categories.length} categories; ${listing.products.length} sample products`;
  }),
  check('Hoogvliet', async () => {
    if (process.argv.includes('--full')) {
      const products = await require('../src/supermarkets/hoogvliet/sync').fetchProducts();
      if (!products.length || products.some(product => !Number.isFinite(product.price))) {
        throw new Error('incomplete or unpriced catalogue');
      }
      return `${products.length} products with prices; full read-only crawl completed`;
    }
    const categories = await hoogvliet.fetchCategories();
    const listing = await hoogvliet.fetchCategoryPage({ path: categories[0].path, categoryId: categories[0].categoryId });
    return `${categories.length} categories; ${listing.items.length} sample products; ${listing.total_count} in ${categories[0].path}`;
  }),
]);
