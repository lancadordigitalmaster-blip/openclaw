const SLUG_REGEX = /^[a-z0-9-]+$/;

function isValidSlug(slug) {
  return typeof slug === 'string' && SLUG_REGEX.test(slug);
}

function toSlug(text) {
  if (!text) return '';
  return text
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');
}

module.exports = { isValidSlug, toSlug, SLUG_REGEX };
