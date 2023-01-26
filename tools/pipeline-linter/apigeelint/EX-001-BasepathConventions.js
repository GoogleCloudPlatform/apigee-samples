/*
  Copyright 2023 Google LLC
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at
      https://www.apache.org/licenses/LICENSE-2.0
  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
*/
const basepathConvention="/v1/samples/"
const plugin = {
  ruleId: "EX-001",
  name: "Basepath convention",
  message: "Check ProxyEndpoint Basepath convention.",
  fatal: false,
  severity: 2, // 1 = warn, 2 = error
  nodeType: "Endpoint",
  enabled: true
};

const onProxyEndpoint = function (ep, cb) {
  let httpProxyConnection = ep.getHTTPProxyConnection(),
    hadError = false;

  if (httpProxyConnection) {
    //console.log("basepath:" + httpProxyConnection.getBasePath());
    let basepath = httpProxyConnection.getBasePath();
    if (basepath && !basepath.startsWith(basepathConvention)) {
      ep.addMessage({
        plugin,
        source: httpProxyConnection.getSource(),
        line: httpProxyConnection.getElement().lineNumber,
        column: httpProxyConnection.getElement().columnNumber,
        message: `Basepath not following "${basepathConvention}" convention`
      });
      hadError = true;
    }
  }
  if (typeof (cb) == 'function') {
    cb(null, hadError);
  }
};

module.exports = {
  plugin,
  onProxyEndpoint
};
