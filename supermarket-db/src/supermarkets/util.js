function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Strips HTML tags from a description field (several store APIs return
 * marked-up copy, e.g. "<p>...</p><ul><li>...</li></ul>").
 */
function stripHtml(html) {
  if (!html) return null;
  return html
    .replace(/<[^>]*>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim() || null;
}

module.exports = { sleep, stripHtml };
