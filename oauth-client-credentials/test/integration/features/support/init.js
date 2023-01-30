/**
 * Copyright 2023 Google LLC
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

if (!process.env.PROXY_URL || !process.env.APP_CLIENT_ID || !process.env.APP_CLIENT_SECRET) {
  
  console.log();
  console.log('Environment variables PROXY_URL, APP_CLIENT_ID and APP_CLIENT_SECRET must be set before the tests can be run.');
  console.log();
  console.log('Please set the Environment variables and try running the command again.');
  console.log();

  process.exit(1);

} else {
  before(function () {
    this.apickli = new apickli.Apickli(
      "https",
      process.env.PROXY_URL
    );

    this.apickli.setGlobalVariable("clientId", process.env.APP_CLIENT_ID);
    this.apickli.setGlobalVariable("clientSecret", process.env.APP_CLIENT_SECRET);

  });
}