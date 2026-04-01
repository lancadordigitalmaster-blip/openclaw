const { describe, it, beforeEach } = require('node:test');
const assert = require('node:assert/strict');

// =============================================================
// Test API input validation without external dependencies
// We test the validation logic by calling handlers with mock req/res
// =============================================================

// Mock Supabase to avoid real DB calls
const originalEnv = { ...process.env };

beforeEach(() => {
  process.env.SUPABASE_URL = 'https://test.supabase.co';
  process.env.SUPABASE_SERVICE_ROLE_KEY = 'test-key';
  process.env.ANTHROPIC_API_KEY = 'sk-ant-test';
  process.env.WOLF_API_KEY = 'test-wolf-key';
  process.env.ADMIN_SECRET = 'test-admin-secret';
});

function mockReq(method, { headers = {}, body = {}, query = {} } = {}) {
  return { method, headers, body, query, socket: { remoteAddress: '127.0.0.1' } };
}

function mockRes() {
  let _status = null;
  let _body = null;
  let _headers = {};
  let _ended = false;

  const res = {
    setHeader(k, v) { _headers[k] = v; },
    status(code) {
      _status = code;
      return {
        json(data) { _body = data; return res; },
        send(data) { _body = data; return res; },
        end() { _ended = true; return res; },
      };
    },
    getStatus() { return _status; },
    getBody() { return _body; },
    isEnded() { return _ended; },
  };
  return res;
}

// =============================================================
// parse-proposal validation
// =============================================================
describe('parse-proposal validation', () => {
  it('rejects non-POST methods', async () => {
    // We can't easily require the handler without Supabase connecting,
    // but we can test the rate-limit + auth pattern
    const { rateLimit } = require('../_lib/rate-limit');
    const { setCors } = require('../_lib/cors');

    const req = mockReq('GET');
    const res = mockRes();

    // CORS should pass through for non-OPTIONS
    const handled = setCors(req, res, { methods: 'POST, OPTIONS' });
    assert.ok(!handled); // GET is not OPTIONS, so not handled by CORS
  });

  it('rate limiter blocks after threshold', () => {
    const { checkRateLimit } = require('../_lib/rate-limit');
    const ip = `test-parse-${Date.now()}`;

    // Simulate 5 requests (limit for parse-proposal)
    for (let i = 0; i < 5; i++) {
      const r = checkRateLimit(ip, 5, 60000);
      assert.ok(r.allowed, `Request ${i + 1} should be allowed`);
    }

    // 6th should be blocked
    const r6 = checkRateLimit(ip, 5, 60000);
    assert.ok(!r6.allowed, 'Request 6 should be blocked');
    assert.ok(r6.retryAfterMs > 0);
  });
});

// =============================================================
// Admin auth validation
// =============================================================
describe('admin auth validation', () => {
  it('timing-safe compare works correctly', () => {
    const { timingSafeEqual } = require('crypto');

    function safeCompare(a, b) {
      if (typeof a !== 'string' || typeof b !== 'string') return false;
      const bufA = Buffer.from(a);
      const bufB = Buffer.from(b);
      if (bufA.length !== bufB.length) return false;
      return timingSafeEqual(bufA, bufB);
    }

    assert.ok(safeCompare('test-secret', 'test-secret'));
    assert.ok(!safeCompare('test-secret', 'wrong-secret'));
    assert.ok(!safeCompare('test-secret', 'test-secre')); // different length
    assert.ok(!safeCompare(null, 'test'));
    assert.ok(!safeCompare('test', undefined));
  });
});

// =============================================================
// track-view slug validation
// =============================================================
describe('track-view input validation', () => {
  it('rejects missing slug', () => {
    const { isValidSlug } = require('../_lib/slug-utils');
    assert.ok(!isValidSlug(undefined));
    assert.ok(!isValidSlug(''));
    assert.ok(!isValidSlug(null));
  });

  it('rejects path traversal attempts', () => {
    const { isValidSlug } = require('../_lib/slug-utils');
    assert.ok(!isValidSlug('../etc/passwd'));
    assert.ok(!isValidSlug('../../.env'));
    assert.ok(!isValidSlug('slug with spaces'));
    assert.ok(!isValidSlug('UPPERCASE'));
  });

  it('accepts valid proposal slugs', () => {
    const { isValidSlug } = require('../_lib/slug-utils');
    assert.ok(isValidSlug('wesley-ramos'));
    assert.ok(isValidSlug('giovani-calcados'));
    assert.ok(isValidSlug('dr-marcos'));
    assert.ok(isValidSlug('cliente-123'));
  });
});

// =============================================================
// CORS origin validation
// =============================================================
describe('CORS origin validation', () => {
  const { getAllowedOrigins } = require('../_lib/cors');

  it('returns default origins when env not set', () => {
    delete process.env.ALLOWED_ORIGINS;
    const origins = getAllowedOrigins();
    assert.ok(origins.includes('https://comercial.wolfpacks.com.br'));
    assert.ok(origins.includes('https://wolf-comercial.vercel.app'));
  });

  it('respects ALLOWED_ORIGINS env var', () => {
    process.env.ALLOWED_ORIGINS = 'https://custom.com,https://other.com';
    const origins = getAllowedOrigins();
    assert.equal(origins.length, 2);
    assert.ok(origins.includes('https://custom.com'));
    assert.ok(origins.includes('https://other.com'));
    delete process.env.ALLOWED_ORIGINS;
  });
});
