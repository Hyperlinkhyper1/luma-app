/**
 * Thin client for Albert Heijn's mobile-app API (undocumented, reverse
 * engineered — same endpoints used by community projects like
 * bartmachielsen/SupermarktConnector). Gets an anonymous access token and
 * uses it to browse categories and search products.
 */

const BASE_URL = 'https://api.ah.nl';

let cachedToken = null;
let cachedTokenExpiresAt = 0;

async function getAccessToken() {
  if (cachedToken && Date.now() < cachedTokenExpiresAt) {
    return cachedToken;
  }
  const response = await fetch(`${BASE_URL}/mobile-auth/v1/auth/token/anonymous`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ clientId: 'appie' }),
  });
  if (!response.ok) {
    throw new Error(`AH auth failed: HTTP ${response.status}`);
  }
  const data = await response.json();
  cachedToken = data.access_token;
  // Refresh a little early so we never call the API with an expired token.
  cachedTokenExpiresAt = Date.now() + (data.expires_in - 60) * 1000;
  return cachedToken;
}

async function authedGet(path, params = {}) {
  const token = await getAccessToken();
  const url = new URL(`${BASE_URL}${path}`);
  for (const [key, value] of Object.entries(params)) {
    if (value !== undefined && value !== null) url.searchParams.set(key, value);
  }
  const response = await fetch(url, {
    headers: {
      Authorization: `Bearer ${token}`,
      // Required for the mobile-services endpoints to route correctly —
      // without it product/search returns a 500 "ApplicationContextNotFoundException".
      'x-application': 'AHWEBSHOP',
    },
  });
  if (!response.ok) {
    throw new Error(`AH request failed: HTTP ${response.status} for ${path}`);
  }
  return response.json();
}

/** Top-level product categories (taxonomy), e.g. "Groente, aardappelen". */
async function fetchCategories() {
  return authedGet('/mobile-services/v1/product-shelves/categories');
}

/**
 * One page of products in a category (or matching a free-text query if
 * `query` is given instead of `taxonomyId`).
 */
async function searchProducts({ taxonomyId, query, page = 0, size = 100 } = {}) {
  return authedGet('/mobile-services/product/search/v2', {
    taxonomyId,
    query,
    page,
    size,
  });
}

module.exports = { fetchCategories, searchProducts };
