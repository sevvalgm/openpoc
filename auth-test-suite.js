#!/usr/bin/env node

/**
 * OpenPoC Platform - Comprehensive Auth Test Suite
 * Tests all authentication flows with detailed reporting
 */

const http = require('http');
const assert = require('assert');

const API_BASE = 'http://localhost:4041/api';
const TEST_EMAIL_STARTUP = `startup-${Date.now()}@test.com`;
const TEST_EMAIL_ENTERPRISE = `enterprise-${Date.now()}@test.com`;
const TEST_PASSWORD = 'TestPassword123';

let testResults = {
  passed: 0,
  failed: 0,
  errors: []
};

// Helper to make HTTP requests
async function request(method, endpoint, body = null, token = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(endpoint, API_BASE);
    const options = {
      hostname: url.hostname,
      port: url.port || 4041,
      path: url.pathname,
      method,
      headers: {
        'Content-Type': 'application/json',
      },
    };

    if (token) {
      options.headers.Authorization = `Bearer ${token}`;
    }

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          resolve({ status: res.statusCode, data: parsed });
        } catch (e) {
          resolve({ status: res.statusCode, data });
        }
      });
    });

    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

// Test helper
async function test(name, fn) {
  try {
    console.log(`\n  ⏳ ${name}`);
    await fn();
    console.log(`  ✅ ${name}`);
    testResults.passed++;
  } catch (error) {
    console.log(`  ❌ ${name}`);
    console.log(`     Error: ${error.message}`);
    testResults.failed++;
    testResults.errors.push({ test: name, error: error.message });
  }
}

// Main test suite
async function runTests() {
  console.log('\n' + '='.repeat(70));
  console.log('  OpenPoC Authentication Test Suite');
  console.log('='.repeat(70));

  let startupToken = null;
  let startupRefreshToken = null;
  let enterpriseToken = null;

  // ==================== SIGN UP TESTS ====================
  console.log('\n📝 SIGN UP TESTS');
  console.log('-'.repeat(70));

  await test('Startup registration with valid data', async () => {
    const res = await request('POST', '/auth/register', {
      email: TEST_EMAIL_STARTUP,
      password: TEST_PASSWORD,
      firstName: 'John',
      lastName: 'Doe',
      role: 'STARTUP',
      privacyAccepted: true
    });

    assert.strictEqual(res.status, 201, `Expected 201 but got ${res.status}: ${JSON.stringify(res.data)}`);
    assert(res.data.accessToken, 'Missing accessToken');
    assert(res.data.refreshToken, 'Missing refreshToken');
    assert(res.data.user, 'Missing user data');
    assert.strictEqual(res.data.user.email, TEST_EMAIL_STARTUP);
    assert.strictEqual(res.data.user.role, 'STARTUP');

    startupToken = res.data.accessToken;
    startupRefreshToken = res.data.refreshToken;
  });

  await test('Enterprise registration with company name', async () => {
    const res = await request('POST', '/auth/register', {
      email: TEST_EMAIL_ENTERPRISE,
      password: TEST_PASSWORD,
      firstName: 'Jane',
      lastName: 'Smith',
      role: 'ENTERPRISE',
      privacyAccepted: true,
      companyName: 'TechCorp Inc'
    });

    assert.strictEqual(res.status, 201, `Expected 201 but got ${res.status}`);
    assert(res.data.accessToken);
    assert(res.data.user);
    assert.strictEqual(res.data.user.role, 'ENTERPRISE');

    enterpriseToken = res.data.accessToken;
  });

  await test('Reject duplicate email registration', async () => {
    const res = await request('POST', '/auth/register', {
      email: TEST_EMAIL_STARTUP,
      password: TEST_PASSWORD,
      firstName: 'Duplicate',
      lastName: 'User',
      role: 'STARTUP',
      privacyAccepted: true
    });

    assert.strictEqual(res.status, 409, `Expected 409 Conflict but got ${res.status}`);
    assert(res.data.message || res.data.error);
  });

  await test('Reject registration without privacy acceptance', async () => {
    const res = await request('POST', '/auth/register', {
      email: `unique-${Date.now()}@test.com`,
      password: TEST_PASSWORD,
      firstName: 'No',
      lastName: 'Privacy',
      role: 'STARTUP',
      privacyAccepted: false
    });

    assert.strictEqual(res.status, 400, `Expected 400 but got ${res.status}`);
  });

  await test('Reject registration without company name for ENTERPRISE', async () => {
    const res = await request('POST', '/auth/register', {
      email: `enterprise-${Date.now()}@test.com`,
      password: TEST_PASSWORD,
      firstName: 'No',
      lastName: 'Company',
      role: 'ENTERPRISE',
      privacyAccepted: true
    });

    assert.strictEqual(res.status, 400, `Expected 400 but got ${res.status}`);
  });

  await test('Reject weak passwords', async () => {
    const res = await request('POST', '/auth/register', {
      email: `weak-${Date.now()}@test.com`,
      password: 'short',
      firstName: 'Weak',
      lastName: 'Pass',
      role: 'STARTUP',
      privacyAccepted: true
    });

    assert.strictEqual(res.status, 400, `Expected 400 but got ${res.status}`);
  });

  // ==================== SIGN IN TESTS ====================
  console.log('\n🔑 SIGN IN TESTS');
  console.log('-'.repeat(70));

  await test('Successful login with valid credentials', async () => {
    const res = await request('POST', '/auth/login', {
      email: TEST_EMAIL_STARTUP,
      password: TEST_PASSWORD
    });

    assert.strictEqual(res.status, 200, `Expected 200 but got ${res.status}`);
    assert(res.data.accessToken, 'Missing accessToken');
    assert(res.data.refreshToken, 'Missing refreshToken');
    assert.strictEqual(res.data.user.email, TEST_EMAIL_STARTUP);
  });

  await test('Reject login with wrong password', async () => {
    const res = await request('POST', '/auth/login', {
      email: TEST_EMAIL_STARTUP,
      password: 'WrongPassword123'
    });

    assert.strictEqual(res.status, 401, `Expected 401 but got ${res.status}`);
  });

  await test('Reject login with non-existent user', async () => {
    const res = await request('POST', '/auth/login', {
      email: 'nonexistent@test.com',
      password: TEST_PASSWORD
    });

    assert.strictEqual(res.status, 401, `Expected 401 but got ${res.status}`);
  });

  await test('Reject login with invalid email format', async () => {
    const res = await request('POST', '/auth/login', {
      email: 'not-an-email',
      password: TEST_PASSWORD
    });

    assert.strictEqual(res.status, 400, `Expected 400 but got ${res.status}`);
  });

  // ==================== TOKEN TESTS ====================
  console.log('\n🔐 TOKEN TESTS');
  console.log('-'.repeat(70));

  await test('Verify session with valid token', async () => {
    const res = await request('GET', '/auth/session', null, startupToken);

    assert.strictEqual(res.status, 200, `Expected 200 but got ${res.status}`);
    assert(res.data.user, 'Missing user in session');
    assert(res.data.isAuthenticated === true, 'Not authenticated');
  });

  await test('Reject request without token', async () => {
    const res = await request('GET', '/auth/session', null, null);

    assert.strictEqual(res.status, 401, `Expected 401 but got ${res.status}`);
  });

  await test('Reject request with invalid token', async () => {
    const res = await request('GET', '/auth/session', null, 'invalid-token-xyz');

    assert.strictEqual(res.status, 401, `Expected 401 but got ${res.status}`);
  });

  await test('Refresh token generates new access token', async () => {
    const res = await request('POST', '/auth/refresh', {
      refreshToken: startupRefreshToken
    });

    assert.strictEqual(res.status, 200, `Expected 200 but got ${res.status}`);
    assert(res.data.accessToken, 'Missing new accessToken');
    assert(res.data.refreshToken, 'Missing new refreshToken');
  });

  // ==================== ROLE & PERMISSION TESTS ====================
  console.log('\n👤 ROLE & AUTHORIZATION TESTS');
  console.log('-'.repeat(70));

  await test('Startup user has STARTUP role', async () => {
    const res = await request('POST', '/auth/login', {
      email: TEST_EMAIL_STARTUP,
      password: TEST_PASSWORD
    });

    assert.strictEqual(res.data.user.role, 'STARTUP');
  });

  await test('Enterprise user has ENTERPRISE role', async () => {
    const res = await request('POST', '/auth/login', {
      email: TEST_EMAIL_ENTERPRISE,
      password: TEST_PASSWORD
    });

    assert.strictEqual(res.data.user.role, 'ENTERPRISE');
  });

  // ==================== RESULTS ====================
  console.log('\n' + '='.repeat(70));
  console.log('\n📊 TEST RESULTS');
  console.log('-'.repeat(70));
  console.log(`✅ Passed: ${testResults.passed}`);
  console.log(`❌ Failed: ${testResults.failed}`);
  console.log(`📈 Success Rate: ${Math.round(testResults.passed / (testResults.passed + testResults.failed) * 100)}%`);

  if (testResults.errors.length > 0) {
    console.log('\n⚠️  FAILED TESTS:');
    testResults.errors.forEach((err, i) => {
      console.log(`  ${i + 1}. ${err.test}`);
      console.log(`     ${err.error}`);
    });
  }

  console.log('\n' + '='.repeat(70) + '\n');

  process.exit(testResults.failed > 0 ? 1 : 0);
}

// Run tests
runTests().catch(err => {
  console.error('\n❌ Test suite error:', err);
  process.exit(1);
});
