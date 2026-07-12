/**
 * Thin client for Jumbo's mobile-app API (undocumented, reverse engineered —
 * same endpoints used by community projects like RinseV/jumbo-wrapper and
 * bartmachielsen/SupermarktConnector).
 *
 * NOTE: this could not be live-tested from the sandbox this was written in —
 * Jumbo's Akamai edge returned a flat 403 for every request from that
 * network (bot mitigation on a datacenter IP), even for a plain page load
 * of jumbo.com. The request shapes below are taken directly from two
 * independently-maintained open-source clients that agree with each other,
 * but this needs a real smoke test once it's running on your own server's
 * (residential) connection — see the module comment in sync.js.
 */

const BASE_URL = 'https://mobileapi.jumbo.com/v17';

const HEADERS = {
  'User-Agent':
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:102.0) Gecko/20100101 Firefox/102.0',
  Accept: 'application/json',
};

async function get(path, params = {}) {
  const url = new URL(`${BASE_URL}${path}`);
  for (const [key, value] of Object.entries(params)) {
    if (value !== undefined && value !== null) url.searchParams.set(key, value);
  }
  const response = await fetch(url, { headers: HEADERS });
  if (!response.ok) {
    throw new Error(`Jumbo request failed: HTTP ${response.status} for ${path}`);
  }
  return response.json();
}

/** One page of products matching a free-text search term. */
async function searchProducts({ query, offset = 0, limit = 30 } = {}) {
  const data = await get('/search', { q: query, offset, limit });
  return data.products; // { data: ProductData[], total, offset }
}

module.exports = { searchProducts };
