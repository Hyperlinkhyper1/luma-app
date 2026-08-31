/**
 * Client for Picnic NL's storefront API (undocumented, reverse engineered).
 *
 * Picnic rebuilt this API at some point after the older community
 * libraries (python-picnic-api etc.) were written: the classic `/my_store`
 * catalog endpoint is gone (confirmed 404 live, 2026-08-31), replaced by a
 * single generic `GET /pages/<page-id>` endpoint that returns a page's UI
 * as a tree of typed components ("PML" — Picnic Markup Language). Login
 * (`/user/login`) is unchanged and still works the same way.
 *
 * Every product tile anywhere on any page — search results, category
 * pages, wherever — is a `SELLING_UNIT_TILE` component wrapping a
 * `sellingUnit` object, regardless of how deep it's nested. That's
 * confirmed by the actively-maintained MRVDH/picnic-api client, which
 * extracts search results the exact same way (`jsonpath-plus`'s
 * `$..sellingUnit`) and tests it against the live API. `findSellingUnits`
 * below reimplements that one fixed lookup directly to avoid pulling in
 * jsonpath-plus for a single use.
 *
 * Picnic has no reverse-engineered "list the whole catalog" page left
 * anywhere public, so sync.js covers the assortment by searching a broad
 * set of category terms instead — see CATEGORY_SEARCH_TERMS there.
 */

const crypto = require('crypto');

const BASE_URL = 'https://storefront-prod.nl.picnicinternational.com/api/15';
const USER_AGENT = 'okhttp/4.9.0';
const CLIENT_ID = 30100;
// `/pages/...` requests 500 without these — Picnic's backend needs a
// device identity on top of the auth token (parallel to ahClient.js's
// 'x-application' header, required for the same reason: without it the
// endpoint 500s rather than routing the request). Fixed dummy values, not
// tied to a real device — the same ones community clients use.
const PICNIC_AGENT = '30100;1.236.1-15553;';
const PICNIC_DEVICE_ID = '3C417201548B2E3B';

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
    headers: {
      'x-picnic-auth': cachedAuthToken,
      'x-picnic-agent': PICNIC_AGENT,
      'x-picnic-did': PICNIC_DEVICE_ID,
      'User-Agent': USER_AGENT,
      'Accept-Language': 'nl',
      // Sent on every request by the reference app client, GETs included —
      // matching the full header set exactly in case a gateway/WAF in
      // front of `/pages/*` fingerprints requests missing it.
      'Content-Type': 'application/json; charset=UTF-8',
    },
  });

  // Read the body as text first so a failure can show what actually came
  // back (an error JSON's `message`, an HTML block page, an empty body,
  // whatever it is) instead of silently swallowing a JSON.parse failure.
  const rawBody = await response.text();
  let data = null;
  try {
    data = JSON.parse(rawBody);
  } catch (_) {
    // Not JSON — data stays null, rawBody carries the diagnostic value.
  }

  const errorCode = data && data.error && data.error.code;
  const isAuthError = errorCode === 'AUTH_ERROR' || errorCode === 'AUTH_INVALID_CRED';

  if (isAuthError && !_retried) {
    // Cached token expired/invalidated server-side — log in again and
    // retry exactly once rather than failing the whole sync.
    cachedAuthToken = null;
    await login(username, password);
    return authedGet(path, { username, password, _retried: true });
  }
  if (!response.ok || isAuthError) {
    throw new Error(
      `Picnic request failed: HTTP ${response.status} for ${path} — ${rawBody.slice(0, 500)}`
    );
  }
  return data;
}

/**
 * Deep-scans a Fusion page response for every `sellingUnit` object,
 * regardless of nesting depth or which components wrap it.
 */
function findSellingUnits(node, out = []) {
  if (Array.isArray(node)) {
    for (const item of node) findSellingUnits(item, out);
    return out;
  }
  if (node && typeof node === 'object') {
    if (node.sellingUnit && typeof node.sellingUnit === 'object') {
      out.push(node.sellingUnit);
    }
    for (const value of Object.values(node)) {
      findSellingUnits(value, out);
    }
  }
  return out;
}

/** One page of search results for `term`, as raw `SellingUnit` objects. */
async function searchProducts(term, { username, password } = {}) {
  const page = await authedGet(
    `/pages/search-page-results?search_term=${encodeURIComponent(term)}`,
    { username, password }
  );
  return findSellingUnits(page);
}

module.exports = { searchProducts };
