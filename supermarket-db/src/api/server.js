const express = require('express');
const cors = require('cors');

const { Supermarket, Product } = require('../models');
const config = require('../config/env');

const VALID_SORTS = new Set(['relevance', 'price_asc', 'price_desc', 'name_asc']);
const MAX_LIMIT = 100;

function serializeProduct(row) {
  return {
    id: row.id,
    name: row.name,
    brand: row.brand,
    description: row.description,
    category: row.category,
    subcategory: row.subcategory,
    imageUrl: row.image_url,
    productUrl: row.product_url,
    quantity: row.quantity,
    unit: row.unit,
    barcode: row.barcode,
    market: {
      id: row.market_id,
      slug: row.market_slug,
      name: row.market_name,
      logoUrl: row.market_logo_url,
    },
    price: row.price === null || row.price === undefined ? null : Number(row.price),
    oldPrice: row.old_price === null || row.old_price === undefined ? null : Number(row.old_price),
    currency: row.currency,
    isDiscounted: Boolean(row.is_discounted),
    discountPercentage:
      row.discount_percentage === null || row.discount_percentage === undefined
        ? null
        : Number(row.discount_percentage),
    discountText: row.discount_text,
  };
}

function createApp() {
  const app = express();
  app.use(cors());
  app.use(express.json());

  app.get('/api/health', (req, res) => {
    res.json({ status: 'ok' });
  });

  app.get('/api/markets', async (req, res, next) => {
    try {
      const markets = await Supermarket.findAll();
      res.json({
        markets: markets.map((m) => ({
          id: m.id,
          slug: m.slug,
          name: m.name,
          logoUrl: m.logo_url,
          websiteUrl: m.website_url,
        })),
      });
    } catch (error) {
      next(error);
    }
  });

  app.get('/api/products/search', async (req, res, next) => {
    try {
      const query = typeof req.query.q === 'string' ? req.query.q.trim() : '';
      const marketParam = typeof req.query.market === 'string' ? req.query.market.trim() : '';
      const marketSlugs = marketParam
        ? marketParam.split(',').map((s) => s.trim()).filter(Boolean)
        : null;

      const sort = VALID_SORTS.has(req.query.sort) ? req.query.sort : 'relevance';
      const limit = Math.min(MAX_LIMIT, Math.max(1, Number.parseInt(req.query.limit, 10) || 40));
      const offset = Math.max(0, Number.parseInt(req.query.offset, 10) || 0);

      const rows = await Product.search({
        query: query || null,
        marketSlugs,
        sort,
        limit,
        offset,
      });

      res.json({
        products: rows.map(serializeProduct),
        limit,
        offset,
      });
    } catch (error) {
      next(error);
    }
  });

  // eslint-disable-next-line no-unused-vars
  app.use((error, req, res, next) => {
    console.error(error);
    res.status(500).json({ error: 'Internal server error' });
  });

  return app;
}

function start() {
  const app = createApp();
  const port = Number(process.env.PORT || 3000);
  app.listen(port, () => {
    console.log(`Supermarket product API listening on port ${port} (env: ${config.env})`);
  });
}

if (require.main === module) {
  start();
}

module.exports = { createApp, start };
