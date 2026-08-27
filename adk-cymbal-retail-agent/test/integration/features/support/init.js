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

const apickli = require("apickli");
const { Before: before } = require("@cucumber/cucumber");
const https = require("https");
const querystring = require("querystring");

// Resilient wrapper for Vertex AI 429 Quota Rate-Limiting
const origSendRequest = apickli.Apickli.prototype.sendRequest;
apickli.Apickli.prototype.sendRequest = function (method, resource, callback) {
  const self = this;
  const executeRequest = (retryCount = 0) => {
    origSendRequest.call(self, method, resource, function (error, response) {
      if (!error && response && (response.statusCode === 429 || (typeof response.body === 'string' && response.body.includes("RESOURCE_EXHAUSTED")))) {
        if (retryCount < 3) {
          const waitTime = (retryCount + 1) * 2000;
          setTimeout(() => executeRequest(retryCount + 1), waitTime);
          return;
        }
      }
      callback(error, response);
    });
  };
  executeRequest(0);
};

var {setDefaultTimeout} = require('@cucumber/cucumber');
setDefaultTimeout(35 * 1000);

const redirectUri = process.env.REDIRECT_URI || "http://127.0.0.1:9000/callback";

function fetchOAuthToken(host, clientId, clientSecret, scope) {
  return new Promise((resolve, reject) => {
    const authPath = `/authorize?client_id=${clientId}&response_type=code&scope=${scope}&redirect_uri=${encodeURIComponent(redirectUri)}`;
    https.get({
      hostname: host,
      path: authPath,
      rejectUnauthorized: false
    }, (res) => {
      if ((res.statusCode === 302 || res.statusCode === 303) && res.headers.location) {
        try {
          const url = new URL(res.headers.location);
          const code = url.searchParams.get("code");
          if (code) {
            return exchangeCodeForToken(host, clientId, clientSecret, code, resolve, reject);
          }
        } catch (err) {
          const codeMatch = res.headers.location.match(/code=([^&]+)/);
          if (codeMatch) {
            return exchangeCodeForToken(host, clientId, clientSecret, codeMatch[1], resolve, reject);
          }
        }
      }
      
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const payload = JSON.parse(data);
          const code = payload.code;
          if (code) {
            exchangeCodeForToken(host, clientId, clientSecret, code, resolve, reject);
          } else {
            reject(new Error(`Failed to get auth code for scope ${scope}: HTTP ${res.statusCode} ${data}`));
          }
        } catch (e) {
          reject(new Error(`Failed to parse auth code for scope ${scope}: HTTP ${res.statusCode} ${data}`));
        }
      });
    }).on('error', reject);
  });
}

function exchangeCodeForToken(host, clientId, clientSecret, code, resolve, reject) {
  const postData = querystring.stringify({
    grant_type: 'authorization_code',
    code: code,
    client_id: clientId,
    client_secret: clientSecret,
    redirect_uri: redirectUri
  });
  
  const authHeader = "Basic " + Buffer.from(`${clientId}:${clientSecret}`).toString("base64");
  
  const req = https.request({
    hostname: host,
    path: '/token',
    method: 'POST',
    rejectUnauthorized: false,
    headers: {
      'Authorization': authHeader,
      'Content-Type': 'application/x-www-form-urlencoded',
      'Content-Length': postData.length
    }
  }, (tokenRes) => {
    let tokenData = '';
    tokenRes.on('data', chunk => tokenData += chunk);
    tokenRes.on('end', () => {
      try {
        const tokenPayload = JSON.parse(tokenData);
        if (tokenPayload.access_token) {
          resolve(tokenPayload.access_token);
        } else {
          reject(new Error(`No access token in response: ${tokenData}`));
        }
      } catch (e) {
        reject(e);
      }
    });
  });
  
  req.on('error', reject);
  req.write(postData);
  req.end();
}

let cachedManagerToken = null;
let cachedCustomerToken = null;

if (!process.env.APIGEE_HOST || !process.env.APIKEY || !process.env.APISECRET) {
  console.log();
  console.log('Environment variables APIGEE_HOST, APIKEY and APISECRET must be set before the tests can be run.');
  console.log('Please set the Environment variables and try running the command again.');
  console.log();
  process.exit(1);
} else {
  before(async function () {
    this.apickli = new apickli.Apickli(
      "https",
      process.env.APIGEE_HOST
    );

    this.apickli.setGlobalVariable("apikey", process.env.APIKEY);
    this.apickli.setGlobalVariable("llm_apikey", process.env.LLM_APIKEY || process.env.APIKEY);
    this.apickli.setGlobalVariable("app-default-token", process.env.APP_DEFAULT_TOKEN);
    this.apickli.setGlobalVariable("PROJECT_ID", process.env.PROJECT_ID || process.env.GOOGLE_CLOUD_PROJECT || "PROJECT_ID_TO_SET");


    try {
      if (!cachedManagerToken || !cachedCustomerToken) {
        console.log("   🔑 Fetching fresh manager and customer access tokens...");
        cachedManagerToken = await fetchOAuthToken(process.env.APIGEE_HOST, process.env.APIKEY, process.env.APISECRET, 'manager');
        cachedCustomerToken = await fetchOAuthToken(process.env.APIGEE_HOST, process.env.APIKEY, process.env.APISECRET, 'customer');
      }
      
      this.apickli.setGlobalVariable("manager_token", cachedManagerToken);
      this.apickli.setGlobalVariable("customer_token", cachedCustomerToken);
      await new Promise((resolve) => setTimeout(resolve, 500));
    } catch (e) {
      console.error("   🔴 Error fetching OAuth tokens:", e.message);
      console.log("   ⚠️  Falling back to APIKEY for BDD headers...");
      this.apickli.setGlobalVariable("manager_token", process.env.APIKEY);
      this.apickli.setGlobalVariable("customer_token", process.env.APIKEY);
    }
  });
}