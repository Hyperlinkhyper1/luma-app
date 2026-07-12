const { getPool } = require('../database/connection');

class Supermarket {
  static async findAll() {
    const [rows] = await getPool().query('SELECT * FROM supermarkets ORDER BY name');
    return rows;
  }

  static async findById(id) {
    const [rows] = await getPool().query('SELECT * FROM supermarkets WHERE id = :id', { id });
    return rows[0] || null;
  }

  static async findBySlug(slug) {
    const [rows] = await getPool().query('SELECT * FROM supermarkets WHERE slug = :slug', { slug });
    return rows[0] || null;
  }

  static async create({ name, slug, logo_url = null, website_url = null }) {
    const [result] = await getPool().query(
      `INSERT INTO supermarkets (name, slug, logo_url, website_url)
       VALUES (:name, :slug, :logo_url, :website_url)`,
      { name, slug, logo_url, website_url }
    );
    return this.findById(result.insertId);
  }

  static async findOrCreateBySlug(slug, defaults = {}) {
    const existing = await this.findBySlug(slug);
    if (existing) {
      return existing;
    }
    return this.create({ name: defaults.name || slug, slug, ...defaults });
  }
}

module.exports = Supermarket;
