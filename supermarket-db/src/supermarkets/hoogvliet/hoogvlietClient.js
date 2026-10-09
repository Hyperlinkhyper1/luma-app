const BASE_URL = 'https://hoogvliet.nl';
const { sleep } = require('../util');

// The current storefront embeds its structured catalogue in Next.js page data.
// The retired Intershop endpoint redirects here without product tiles.
async function fetchPage(path, request = fetch) {
  // Some storefront page URLs serve stale, truncated search results even
  // while adjacent pages are current. A fresh query bypasses that page cache.
  const url = new URL(`${BASE_URL}/${path}`);
  url.searchParams.set('_luma_sync', String(Date.now()));
  const response = await request(url.href, {
    signal: AbortSignal.timeout(45000),
    headers: { 'Cache-Control': 'no-cache' },
  });
  if (!response.ok) throw new Error(`Hoogvliet request failed: HTTP ${response.status} for ${path}`);
  const html = await response.text();
  const match = html.match(/<script\b[^>]*\bid="__NEXT_DATA__"[^>]*>([\s\S]*?)<\/script>/);
  if (!match) throw new Error(`Hoogvliet: missing catalogue page data for ${path}`);
  const props = JSON.parse(match[1]).props?.pageProps;
  if (!props) throw new Error(`Hoogvliet: invalid catalogue page data for ${path}`);
  return props;
}

async function fetchCategories(request = fetch) {
  const props = await fetchPage('producten', request);
  const children = props.entity?.children;
  if (!Array.isArray(children) || children.length === 0) throw new Error('Hoogvliet: no catalogue categories found');
  return children.map((category) => {
    if (!category.name || !category.url_path || !/^[a-z0-9/-]+$/.test(category.url_path)) {
      throw new Error('Hoogvliet: invalid catalogue category');
    }
    return { name: category.name, path: category.url_path };
  });
}

async function fetchCategoryPage({ path, pageNumber = 1, expectedTotal }, request = fetch) {
  for (let attempt = 0; attempt < 3; attempt += 1) {
    try {
      const props = await fetchPage(`${path}${pageNumber > 1 ? `/q/page/${pageNumber}` : ''}`, request);
      const listing = typeof props.fallbackData === 'string' ? JSON.parse(props.fallbackData) : props.fallbackData;
      if (!listing || !Array.isArray(listing.items) || listing.page !== pageNumber ||
          !Number.isInteger(listing.totalPages) || listing.totalPages < pageNumber ||
          !Number.isInteger(listing.total_count) || listing.total_count < 1 || listing.items.length === 0 ||
          (expectedTotal !== undefined && listing.total_count !== expectedTotal)) {
        throw new Error(`Hoogvliet: incomplete catalogue listing for ${path} page ${pageNumber}`);
      }
      return listing;
    } catch (error) {
      if (attempt === 2) throw error;
      await sleep(350 * (attempt + 1));
    }
  }
}

module.exports = { fetchCategories, fetchCategoryPage };
