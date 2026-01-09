/**
 * Copyright 2026 Google LLC
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

const apickli = require('apickli/apickli-gherkin');
const { When, Then } = require('@cucumber/cucumber');

module.exports = apickli;

// Custom step definitions for spike arrest testing
let responses = [];

When('I send {int} requests in {int} second(s)', function (requestCount, seconds, callback) {
  responses = [];
  const delay = (seconds * 1000) / requestCount;
  let completed = 0;
  
  const sendRequest = (index) => {
    if (index >= requestCount) {
      callback();
      return;
    }
    
    this.apickli.get('/', (error, response) => {
      if (!error && response) {
        responses.push({
          statusCode: response.statusCode,
          body: response.body
        });
      }
      completed++;
      
      if (completed < requestCount) {
        setTimeout(() => sendRequest(completed), delay);
      } else {
        callback();
      }
    });
  };
  
  sendRequest(0);
});

Then('at least one response code should be {int}', function (expectedStatusCode) {
  const found = responses.some(r => r.statusCode === expectedStatusCode);
  if (!found) {
    throw new Error(`Expected at least one response with status code ${expectedStatusCode}, but found none. Status codes: ${responses.map(r => r.statusCode).join(', ')}`);
  }
});

Then('at least one response body path {string} should be {string}', function (path, expectedValue) {
  const found = responses.some(r => {
    try {
      const body = typeof r.body === 'string' ? JSON.parse(r.body) : r.body;
      const pathParts = path.replace('$.', '').split('.');
      let value = body;
      for (const part of pathParts) {
        value = value[part];
      }
      return value === expectedValue;
    } catch (e) {
      return false;
    }
  });
  if (!found) {
    throw new Error(`Expected at least one response with ${path} = ${expectedValue}, but found none`);
  }
});
