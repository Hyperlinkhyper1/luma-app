const crypto = require('crypto');
const express = require('express');

const config = require('../config/env');
const { getPool } = require('../database/connection');
const { SyncLog } = require('../models');
const syncService = require('../services/syncService');

// Constant-time key check (hash both sides so lengths always match).
function keyMatches(provided) {
  if (!config.adminKey || !provided) return false;
  const a = crypto.createHash('sha256').update(String(provided)).digest();
  const b = crypto.createHash('sha256').update(config.adminKey).digest();
  return crypto.timingSafeEqual(a, b);
}

function requireAdmin(req, res, next) {
  if (!config.adminKey) {
    // No key configured — pretend the endpoints don't exist at all.
    res.status(404).json({ error: 'Not found' });
    return;
  }
  const provided = req.headers['x-admin-key'] || req.query.key;
  if (!keyMatches(provided)) {
    res.status(401).json({ error: 'Invalid or missing admin key.' });
    return;
  }
  next();
}

async function collectStatus() {
  const pool = getPool();
  const [[productCounts]] = await pool.query(
    `SELECT COUNT(*) AS total, COALESCE(SUM(is_available), 0) AS available
     FROM products`
  );
  const [[priceCounts]] = await pool.query(
    'SELECT COUNT(*) AS total FROM product_prices'
  );
  const logs = await SyncLog.findRecent({ limit: 20 });
  return {
    products: {
      total: Number(productCounts.total),
      available: Number(productCounts.available),
    },
    priceSnapshots: Number(priceCounts.total),
    markets: syncService.slugs,
    running: logs.some((l) => l.status === 'running'),
    syncs: logs.map((l) => ({
      id: l.id,
      market: l.supermarket_slug,
      marketName: l.supermarket_name,
      startedAt: l.started_at,
      finishedAt: l.finished_at,
      checked: l.products_checked,
      added: l.products_added,
      updated: l.products_updated,
      failed: l.products_failed,
      status: l.status,
      error: l.error_message,
    })),
  };
}

function startSync(market) {
  // Fire and forget: progress and errors land in sync_logs (see BaseSync),
  // which is what the control panel polls — the HTTP request doesn't wait.
  const run = market ? syncService.syncOne(market) : syncService.syncAll();
  run.catch((error) => console.error('Admin-triggered sync failed:', error));
}

function esc(value) {
  return String(value ?? '').replace(/[&<>"']/g, (ch) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  })[ch]);
}

function controlPanelHtml(status, key) {
  const encodedKey = encodeURIComponent(key);
  const marketButtons = status.markets.map((slug) =>
    `<form method="post" action="/admin/sync?key=${encodedKey}" style="margin:0">` +
    `<input type="hidden" name="market" value="${esc(slug)}">` +
    `<button type="submit" class="ghost">Sync ${esc(slug)}</button></form>`
  ).join('');

  const rows = status.syncs.map((s) => {
    const color = s.status === 'success' ? '#7ee08a'
      : s.status === 'running' ? '#e0c87e' : '#e07e7e';
    return '<tr>' +
      `<td>${esc(s.marketName)}</td>` +
      `<td><span style="color:${color}">${esc(s.status)}</span></td>` +
      `<td>${esc(s.startedAt)}</td>` +
      `<td>${esc(s.finishedAt ?? '—')}</td>` +
      `<td>${s.checked}</td><td>${s.added}</td><td>${s.updated}</td><td>${s.failed}</td>` +
      `<td>${esc(s.error ?? '')}</td>` +
      '</tr>';
  }).join('');

  const refresh = status.running
    ? '<meta http-equiv="refresh" content="3">'
    : '';

  return `<!doctype html><html><head><meta charset="utf-8">${refresh}
<title>luma groceries — control panel</title>
<style>
body{background:#161320;color:#e8e4f3;font-family:system-ui,sans-serif;margin:0;padding:32px}
h1{font-size:20px;margin:0 0 24px}h2{font-size:15px;margin:28px 0 12px}
.stats{display:flex;gap:16px;flex-wrap:wrap;margin-bottom:28px}
.stat{background:#1e1a2b;border-radius:8px;padding:16px 20px;min-width:140px}
.stat .n{font-size:22px;font-weight:600}.stat .l{font-size:12px;color:#a49fb8;margin-top:4px}
.actions{display:flex;gap:10px;flex-wrap:wrap;align-items:center}
button{background:#8a7ee0;color:#161320;border:none;border-radius:8px;padding:8px 16px;
font-size:13px;font-weight:600;cursor:pointer;font-family:inherit}
button.ghost{background:#1e1a2b;color:#a49fb8;border:1px solid #2c2640;font-weight:500}
table{border-collapse:collapse;width:100%;font-size:13px}
th{text-align:left;color:#a49fb8;font-weight:500;padding:8px 12px;border-bottom:1px solid #2c2640}
td{padding:8px 12px;border-bottom:1px solid #201c2c}
.note{color:#a49fb8;font-size:12px;margin-top:8px}
</style></head><body>
<h1>luma groceries — control panel</h1>
<div class="stats">
<div class="stat"><div class="n">${status.products.total}</div><div class="l">Products</div></div>
<div class="stat"><div class="n">${status.products.available}</div><div class="l">Available</div></div>
<div class="stat"><div class="n">${status.priceSnapshots}</div><div class="l">Price snapshots</div></div>
</div>
<h2>Reload / update database</h2>
<div class="actions">
<form method="post" action="/admin/sync?key=${encodedKey}" style="margin:0">
<button type="submit">Sync all markets</button></form>
${marketButtons}
</div>
<div class="note">Fetches the latest products and prices from each supermarket,
adds new products, updates existing ones, records price changes, and marks
products that disappeared as unavailable.${status.running
    ? ' <strong>A sync is running — this page refreshes automatically.</strong>' : ''}</div>
<h2>Recent syncs</h2>
<table><thead><tr><th>Market</th><th>Status</th><th>Started</th><th>Finished</th>
<th>Checked</th><th>Added</th><th>Updated</th><th>Failed</th><th>Error</th></tr></thead>
<tbody>${rows || '<tr><td colspan="9" style="color:#a49fb8">No syncs yet.</td></tr>'}</tbody></table>
</body></html>`;
}

function registerAdminRoutes(app) {
  const form = express.urlencoded({ extended: false });

  app.get('/admin', requireAdmin, async (req, res, next) => {
    try {
      const status = await collectStatus();
      res
        .type('html')
        .send(controlPanelHtml(status, String(req.query.key || '')));
    } catch (error) {
      next(error);
    }
  });

  app.get('/admin/sync/status', requireAdmin, async (req, res, next) => {
    try {
      res.json(await collectStatus());
    } catch (error) {
      next(error);
    }
  });

  app.post('/admin/sync', requireAdmin, form, (req, res) => {
    const market = typeof req.body.market === 'string' && req.body.market.trim()
      ? req.body.market.trim()
      : null;
    if (market && !syncService.slugs.includes(market)) {
      res.status(400).json({ error: `Unknown market "${market}".` });
      return;
    }
    startSync(market);
    // Browser form POSTs land back on the panel; API callers get JSON.
    if ((req.headers.accept || '').includes('text/html')) {
      res.redirect(303, `/admin?key=${encodeURIComponent(String(req.query.key || ''))}`);
    } else {
      res.status(202).json({ started: true, market: market || 'all' });
    }
  });
}

module.exports = { registerAdminRoutes };
