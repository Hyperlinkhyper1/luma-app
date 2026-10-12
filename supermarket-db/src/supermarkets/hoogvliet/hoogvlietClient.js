const BASE_URL = 'https://hoogvliet.nl';
const { sleep } = require('../util');
const PAGE_SIZE = 1000;
const PRODUCT_QUERY = `query Catalogue($pageSize: Int!, $currentPage: Int!, $filters: ProductAttributeFilterInput!) {
  products(pageSize: $pageSize, currentPage: $currentPage, filter: $filters) {
    total_count
    page_info { current_page total_pages }
    items {
      sku name metadata product_link url_key url_suffix
      small_image { url }
      categories { name level }
      sub_title_attributes { volume unit }
      is_promotion
      promotion_meta_data { valid_from valid_to korting_label }
      price_range { minimum_price { regular_price { value currency } final_price { value currency } } }
    }
  }
}`;

// The current storefront embeds its category index in Next.js page data.
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
    if (!category.name || !category.url_path || !/^[a-z0-9/-]+$/.test(category.url_path) ||
        !/^\d+$/.test(String(category.metadata?.tweakwise_id))) {
      throw new Error('Hoogvliet: invalid catalogue category');
    }
    return { name: category.name, path: category.url_path, categoryId: String(category.metadata.tweakwise_id) };
  });
}

async function fetchCategoryPage({ path, categoryId, pageNumber = 1, expectedTotal }, request = fetch) {
  if (!/^\d+$/.test(String(categoryId))) throw new Error(`Hoogvliet: missing catalogue category ID for ${path}`);
  for (let attempt = 0; attempt < 3; attempt += 1) {
    try {
      // The storefront's cached HTML pages can disagree on totals. Its public
      // catalogue query returns complete current categories at this page size.
      const response = await request(`${BASE_URL}/api/graphql`, {
        method: 'POST', signal: AbortSignal.timeout(45000),
        headers: { 'Content-Type': 'application/json', 'Accept-Language': 'nl', 'Cache-Control': 'no-cache' },
        body: JSON.stringify({ query: PRODUCT_QUERY, variables: {
          pageSize: PAGE_SIZE, currentPage: pageNumber, filters: { category_id: { eq: String(categoryId) } },
        } }),
      });
      if (!response.ok) throw new Error(`Hoogvliet request failed: HTTP ${response.status} for ${path}`);
      const data = await response.json();
      if (data.errors?.length) throw new Error(`Hoogvliet: catalogue API error for ${path}`);
      const products = data.data?.products;
      const listing = products && { items: products.items, page: products.page_info?.current_page,
        totalPages: products.page_info?.total_pages, total_count: products.total_count };
      if (!listing || !Array.isArray(listing.items) || listing.page !== pageNumber ||
          !Number.isInteger(listing.totalPages) || listing.totalPages < pageNumber ||
          !Number.isInteger(listing.total_count) || listing.total_count < 1 || listing.items.length === 0 ||
          listing.totalPages !== Math.ceil(listing.total_count / PAGE_SIZE) ||
          (expectedTotal !== undefined && listing.total_count !== expectedTotal) ||
          listing.items.length !== Math.min(PAGE_SIZE, listing.total_count - (pageNumber - 1) * PAGE_SIZE)) {
        throw new Error(`Hoogvliet: incomplete catalogue listing for ${path} page ${pageNumber} ` +
          `(received page ${listing?.page}, ${listing?.items?.length ?? 0} items, total ${listing?.total_count}, expected ${expectedTotal ?? 'unknown'})`);
      }
      listing.items = listing.items.map(raw => {
        const metadata = typeof raw.metadata === 'string' ? JSON.parse(raw.metadata) : raw.metadata || {};
        return { ...raw, gtin13: metadata.ean ? String(metadata.ean) : null,
          brand: { value: metadata.merk || null },
          display_name: metadata.merk && !raw.name?.toLowerCase().startsWith(String(metadata.merk).toLowerCase())
            ? `${metadata.merk} ${raw.name}` : raw.name,
          product_link: raw.product_link || (raw.url_key ? `/product/${raw.url_key}${raw.url_suffix || ''}` : null),
          discount_label: raw.promotion_meta_data?.korting_label || null };
      });
      return listing;
    } catch (error) {
      if (attempt === 2) throw error;
      await sleep(350 * (attempt + 1));
    }
  }
}

module.exports = { fetchCategories, fetchCategoryPage };
