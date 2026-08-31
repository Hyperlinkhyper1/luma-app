/**
 * Client for Picnic NL's storefront API (undocumented, reverse engineered —
 * the same endpoints used by community projects like
 * MikeBrink/python-picnic-api and Home Assistant's Picnic integration).
 *
 * Unlike every other store in this project, Picnic has no anonymous access
 * at all: it's a delivery-app-only grocer (picnic.app is pure marketing /
 * download-the-app content, no browsable web catalog), so every request
 * needs a real logged-in account. The catalog and prices you get back are
 * whatever that account's registered delivery address sees — there's no
 * separate store/location selection step the way Lidl's site has.
 */

const crypto = require('crypto');

const BASE_URL = 'https://storefront-prod.nl.picnicinternational.com/api/15';
// Mirrors the Android app's own HTTP client — same header/client_id values
// python-picnic-api uses, since Picnic's backend expects real app traffic
// (parallel to ahClient.js mimicking AH's Android app for the same reason).
const USER_AGENT = 'okhttp/3.9.0';
const CLIENT_ID = 30100;

let cachedAuthToken = null;

function md5(value) {
  return crypto.createHash('md5').update(value, 'utf8').digest('hex');
}

/**
 * Logs in and caches the auth token for subsequent requests. The token
 * comes back as a response HEADER (`x-picnic-auth`), not in the JSON body.
 */
async function login(username, password) {
  const response = await fetch(`${BASE_URL}/user/login`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json; charset=UTF-8',
      'User-Agent': USER_AGENT,
    },
    body: JSON.stringify({ key: username, secret: md5(password), client_id: CLIENT_ID }),
  });
  const token = response.headers.get('x-picnic-auth');
  if (!response.ok || !token) {
    const body = await response.text().catch(() => '');
    throw new Error(`Picnic login failed: HTTP ${response.status} ${body.slice(0, 300)}`);
  }
  cachedAuthToken = token;
  return token;
}

async function authedGet(path, { username, password, _retried = false } = {}) {
  if (!cachedAuthToken) {
    await login(username, password);
  }
  const response = await fetch(`${BASE_URL}${path}`, {
    headers: { 'x-picnic-auth': cachedAuthToken, 'User-Agent': USER_AGENT },
  });
  const data = await response.json().catch(() => null);
  const authErrorCode = data && data.error && data.error.code;
  const isAuthError = authErrorCode === 'AUTH_ERROR' || authErrorCode === 'AUTH_INVALID_CRED';

  if (isAuthError && !_retried) {
    // Cached token expired/invalidated server-side — log in again and
    // retry exactly once rather than failing the whole sync.
    cachedAuthToken = null;
    await login(username, password);
    return authedGet(path, { username, password, _retried: true });
  }
  if (!response.ok || isAuthError) {
    throw new Error(
      `Picnic request failed: HTTP ${response.status} for ${path} ${JSON.stringify(data).slice(0, 300)}`
    );
  }
  return data;
}

/**
 * Full nested category tree with product leaves inline. `depth` controls
 * how many levels down real products (`type: "SINGLE_ARTICLE"`, nested
 * inside `type: "CATEGORY"` groups via an `items` array) get included —
 * too shallow and you only get category names back with no products.
 *
 * Not verified against a live account (none was available while writing
 * this — Picnic requires a real signed-up account with a delivery address,
 * see PICNIC_USERNAME/PICNIC_PASSWORD in .env.example). If a real sync
 * comes back thin or empty, try raising `depth` first.
 */
async function fetchCatalog({ username, password, depth = 6 } = {}) {
  const data = await authedGet(`/my_store?depth=${depth}`, { username, password });
  return data.catalog || [];
}

function imageUrl(imageId, size = 'medium') {
  if (!imageId) return null;
  return `https://storefront-prod.nl.picnicinternational.com/static/images/${imageId}/${size}.png`;
}

module.exports = { fetchCatalog, imageUrl };
