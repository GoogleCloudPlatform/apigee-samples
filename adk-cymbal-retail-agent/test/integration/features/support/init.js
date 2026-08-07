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

var {setDefaultTimeout} = require('@cucumber/cucumber');
setDefaultTimeout(25 * 1000);

function fetchOAuthToken(host, clientId, clientSecret, scope) {
  return new Promise((resolve, reject) => {
    const authPath = `/authorize?client_id=${clientId}&response_type=code&scope=${scope}`;
    https.get({
      hostname: host,
      path: authPath,
      rejectUnauthorized: false
    }, (res) => {
      if (res.statusCode === 302 && res.headers.location) {
        const url = require("url").parse(res.headers.location, true);
        const code = url.query.code;
        if (code) {
          return exchangeCodeForToken(host, clientId, clientSecret, code, resolve, reject);
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
            reject(new Error(`Failed to get auth code for scope ${scope}: ${data}`));
          }
        } catch (e) {
          reject(e);
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
    client_secret: clientSecret
  });
  
  const req = https.request({
    hostname: host,
    path: '/token',
    method: 'POST',
    rejectUnauthorized: false,
    headers: {
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

if (!process.env.APIGEE_HOST || !process.env.APIKEY || !process.env.APISECRET) {
  
  console.log();
  console.log('Environment variables APIGEE_HOST, APIKEY and APISECRET must be set before the tests can be run.');
  console.log();
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
    this.apickli.setGlobalVariable("app-default-token", process.env.APP_DEFAULT_TOKEN);

    try {
      console.log("   🔑 Fetching fresh manager and customer access tokens...");
      const managerToken = await fetchOAuthToken(process.env.APIGEE_HOST, process.env.APIKEY, process.env.APISECRET, 'manager');
      const customerToken = await fetchOAuthToken(process.env.APIGEE_HOST, process.env.APIKEY, process.env.APISECRET, 'customer');
      
      this.apickli.setGlobalVariable("manager_token", managerToken);
      this.apickli.setGlobalVariable("customer_token", customerToken);
    } catch (e) {
      console.error("   🔴 Error fetching OAuth tokens:", e.message);
      console.log("   ⚠️  Falling back to APIKEY for BDD headers...");
      this.apickli.setGlobalVariable("manager_token", process.env.APIKEY);
      this.apickli.setGlobalVariable("customer_token", process.env.APIKEY);
    }
  });
}