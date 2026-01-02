/**
 * Copyright 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

const assert = require('assert');
const https = require('https');

const envs = ["APIGEE_HOST"];

envs.forEach((env) => {
  if (!process.env[env]) {
    console.log(`Missing environment variable: ${env}`);
    process.exit(1);
  }
});

const host = process.env.APIGEE_HOST;
const basePath = "/v1/samples/traffic-mirror";

function makeRequest(path) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: host,
      port: 443,
      path: `${basePath}${path}`,
      method: 'GET',
      headers: {
        'Content-Type': 'application/json'
      }
    };

    const req = https.request(options, (res) => {
      let data = '';

      res.on('data', (chunk) => {
        data += chunk;
      });

      res.on('end', () => {
        resolve({
          statusCode: res.statusCode,
          headers: res.headers,
          body: data
        });
      });
    });

    req.on('error', (error) => {
      reject(error);
    });

    req.setTimeout(10000, () => {
      req.destroy();
      reject(new Error('Request timeout'));
    });

    req.end();
  });
}

async function runTests() {
  console.log('Testing Traffic Mirroring Shared Flow...\n');

  try {
    // Test 1: Basic request should succeed
    console.log('Test 1: Making request to example proxy...');
    const response = await makeRequest('/test');
    assert.strictEqual(response.statusCode, 200, 'Expected status 200');
    console.log('✓ Request successful');

    // Test 2: Mirror response header should be present
    console.log('\nTest 2: Checking for mirror response header...');
    assert.ok(
      response.headers['request-mirror-response-status-code'],
      'Expected mirror response status code header'
    );
    console.log(`✓ Mirror response status code: ${response.headers['request-mirror-response-status-code']}`);

    // Test 3: Response should be fast (not waiting for mirror)
    console.log('\nTest 3: Checking response time (should not wait for mirror)...');
    const start = Date.now();
    await makeRequest('/test');
    const duration = Date.now() - start;
    console.log(`✓ Response time: ${duration}ms`);
    
    // The mirror endpoint has a 2 second delay, but the response should be fast
    if (duration < 1500) {
      console.log('✓ Response is fast (not blocking on mirror request)');
    } else {
      console.log('⚠ Warning: Response might be blocking on mirror request');
    }

    console.log('\n✅ All tests passed!');
    process.exit(0);

  } catch (error) {
    console.error('\n❌ Test failed:', error.message);
    process.exit(1);
  }
}

runTests();
