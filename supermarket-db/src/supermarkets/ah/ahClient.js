/**
 * Thin client for Albert Heijn's mobile-app API (undocumented, reverse
 * engineered — same endpoints used by community projects like
 * bartmachielsen/SupermarktConnector). Gets an anonymous access token and
 * uses it to browse categories and search products.
 */

const BASE_URL = 'https://api.ah.nl';
// Mimic the official Android app — Node's default "node" user agent is an
// easy flag for Akamai on IPs it's already suspicious of.
const USER_AGENT = 'Appie/8.22.3 Model/phone Android/12-API31';

let cachedToken = null;
let cachedTokenExpiresAt = 0;

// AH advertises a week-long expiry for anonymous tokens but invalidates them
// server-side long before that, so cap how long we trust one.
const MAX_TOKEN_AGE_MS = 30 * 60 * 1000;

// A token AH has dropped comes back as an OAuth error body on the data
// endpoint — as a 400 `invalid_grant` ("member not active") just as often as
// a 401, so both have to be treated as "get a new token".
function isAuthFailure(status, body) {
  if (status === 401) return true;
  if (status !== 400 && status !== 403) return false;
  return /invalid_grant|invalid_token|member not active/i.test(body);
}

async function getAccessToken({ forceRefresh = false } = {}) {
  if (!forceRefresh && cachedToken && Date.now() < cachedTokenExpiresAt) {
    return cachedToken;
  }
  const response = await fetch(`${BASE_URL}/mobile-auth/v1/auth/token/anonymous`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'User-Agent': USER_AGENT },
    body: JSON.stringify({ clientId: 'appie' }),
  });
  if (!response.ok) {
    const body = await response.text().catch(() => '');
    throw new Error(`AH auth failed: HTTP ${response.status} ${body.slice(0, 300)}`);
  }
  const data = await response.json();
  cachedToken = data.access_token;
  // Refresh a little early so we never call the API with an expired token.
  cachedTokenExpiresAt =
    Date.now() + Math.min((data.expires_in - 60) * 1000, MAX_TOKEN_AGE_MS);
  return cachedToken;
}

async function authedGet(path, params = {}, { _retried = false } = {}) {
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
      'User-Agent': USER_AGENT,
    },
  });
  if (!response.ok) {
    const body = await response.text().catch(() => '');
    if (!_retried && isAuthFailure(response.status, body)) {
      // The anonymous token can get invalidated server-side before its
      // advertised expiry (e.g. after a very large burst of requests, like a
      // full-catalog sync) — get a fresh one and try exactly once more rather
      // than failing the whole sync.
      await getAccessToken({ forceRefresh: true });
      return authedGet(path, params, { _retried: true });
    }
    throw new Error(`AH request failed: HTTP ${response.status} for ${path} ${body.slice(0, 300)}`);
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
