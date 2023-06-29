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
/* global process require */

const apickli = require("apickli");
const { Before: before } = require("@cucumber/cucumber");

const requiredVars = ["APIGEE_HOST", "SAMPLE_PROXY_BASEPATH",
                      "VIEWER_CLIENT_ID", "CREATOR_CLIENT_ID", "ADMIN_CLIENT_ID",
                      "VIEWER_CLIENT_SECRET", "CREATOR_CLIENT_SECRET", "ADMIN_CLIENT_SECRET"
                     ];
let notPresent = requiredVars.filter( v => !process.env[v] );
if (notPresent.length > 0) {
  console.log('\nEnvironment variables [' + requiredVars.join(", ") + '] must be set before the tests can be run.');
  console.log('Missing: [' + notPresent.join(", ") + '] ');
  console.log('\nPlease set the Environment variables and try running the command again.\n');
  process.exit(1);

} else {
  before(function () {
    this.apickli = new apickli.Apickli(
      "https",
      process.env.APIGEE_HOST + process.env.SAMPLE_PROXY_BASEPATH
    );

    this.apickli.setGlobalVariable("viewerClientId", process.env.VIEWER_CLIENT_ID);
    this.apickli.setGlobalVariable("creatorClientId", process.env.CREATOR_CLIENT_ID);
    this.apickli.setGlobalVariable("adminClientId", process.env.ADMIN_CLIENT_ID);
    this.apickli.setGlobalVariable("viewerClientSecret", process.env.VIEWER_CLIENT_SECRET);
    this.apickli.setGlobalVariable("creatorClientSecret", process.env.CREATOR_CLIENT_SECRET);
    this.apickli.setGlobalVariable("adminClientSecret", process.env.ADMIN_CLIENT_SECRET);

  });
}
