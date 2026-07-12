const { getPool, closePool } = require('./database/connection');
const models = require('./models');
const syncService = require('./services/syncService');

module.exports = {
  getPool,
  closePool,
  ...models,
  syncService,
};
