const { describe, it } = require('node:test');
const assert = require('node:assert/strict');

// =============================================================
// _lib/slug-utils.js
// =============================================================
const { isValidSlug, toSlug } = require('../_lib/slug-utils');

describe('slug-utils', () => {
  describe('isValidSlug', () => {
    it('accepts valid slugs', () => {
      assert.ok(isValidSlug('wesley-ramos'));
      assert.ok(isValidSlug('cliente-123'));
      assert.ok(isValidSlug('a'));
    });

    it('rejects invalid slugs', () => {
      assert.ok(!isValidSlug(''));
      assert.ok(!isValidSlug('Wesley Ramos'));
      assert.ok(!isValidSlug('café'));
      assert.ok(!isValidSlug('../etc/passwd'));
      assert.ok(!isValidSlug(null));
      assert.ok(!isValidSlug(123));
    });
  });

  describe('toSlug', () => {
    it('normalizes accented characters', () => {
      assert.equal(toSlug('João Silva'), 'joao-silva');
      assert.equal(toSlug('Café & Pão'), 'cafe-pao');
    });

    it('handles special characters', () => {
      assert.equal(toSlug('Wesley Ramos!!!'), 'wesley-ramos');
      assert.equal(toSlug('  espaços  '), 'espacos');
    });

    it('handles empty input', () => {
      assert.equal(toSlug(''), '');
      assert.equal(toSlug(null), '');
      assert.equal(toSlug(undefined), '');
    });
  });
});

// =============================================================
// _lib/rate-limit.js
// =============================================================
const { checkRateLimit } = require('../_lib/rate-limit');

describe('rate-limit', () => {
  it('allows requests within limit', () => {
    const key = `test-${Date.now()}`;
    const r1 = checkRateLimit(key, 3, 60000);
    assert.ok(r1.allowed);
    assert.equal(r1.remaining, 2);
  });

  it('blocks requests exceeding limit', () => {
    const key = `test-block-${Date.now()}`;
    checkRateLimit(key, 2, 60000);
    checkRateLimit(key, 2, 60000);
    const r3 = checkRateLimit(key, 2, 60000);
    assert.ok(!r3.allowed);
    assert.equal(r3.remaining, 0);
  });

  it('uses separate windows per key', () => {
    const key1 = `test-key1-${Date.now()}`;
    const key2 = `test-key2-${Date.now()}`;
    checkRateLimit(key1, 1, 60000);
    checkRateLimit(key1, 1, 60000); // blocked
    const r = checkRateLimit(key2, 1, 60000); // separate key, should be allowed
    assert.ok(r.allowed);
  });
});

// =============================================================
// _lib/cors.js
// =============================================================
const { setCors } = require('../_lib/cors');

describe('cors', () => {
  function mockReq(method, origin) {
    return { method, headers: { origin } };
  }

  function mockRes() {
    const headers = {};
    let statusCode = null;
    let ended = false;
    return {
      setHeader(k, v) { headers[k] = v; },
      status(code) { statusCode = code; return { end() { ended = true; } }; },
      getHeaders() { return headers; },
      getStatus() { return statusCode; },
      isEnded() { return ended; },
    };
  }

  it('handles OPTIONS preflight', () => {
    const req = mockReq('OPTIONS', 'https://wolf-comercial.vercel.app');
    const res = mockRes();
    const handled = setCors(req, res);
    assert.ok(handled);
    assert.equal(res.getStatus(), 204);
  });

  it('allows whitelisted origins', () => {
    const req = mockReq('GET', 'https://wolf-comercial.vercel.app');
    const res = mockRes();
    setCors(req, res);
    assert.equal(res.getHeaders()['Access-Control-Allow-Origin'], 'https://wolf-comercial.vercel.app');
  });

  it('blocks unknown origins', () => {
    const req = mockReq('GET', 'https://evil.com');
    const res = mockRes();
    setCors(req, res);
    assert.equal(res.getHeaders()['Access-Control-Allow-Origin'], undefined);
  });

  it('allows server-to-server (no origin)', () => {
    const req = mockReq('GET', undefined);
    const res = mockRes();
    setCors(req, res);
    assert.equal(res.getHeaders()['Access-Control-Allow-Origin'], '*');
  });
});
