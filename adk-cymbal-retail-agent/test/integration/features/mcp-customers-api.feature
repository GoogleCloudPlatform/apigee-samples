# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

Feature: MCP Customers API

Scenario: initialize
  Given I store the raw value {"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"mcp","version":"0.1.0"}},"jsonrpc":"2.0","id":0} as myPayload in scenario scope
  And I set body to `myPayload`
  And I set headers to
      | name          | value            |
      | content-type  | application/json |
      | User-Agent    | apickli          |
      | x-apikey      | `apikey`         |

  When I POST to /mcp/v1/samples/adk-cymbal-retail/customers
  Then response code should be 200
  And response body should be valid json
  And response body should contain mcp-customer-profile-api
  And response body should contain jsonrpc

Scenario: tools/list
  Given I store the raw value {"method":"tools/list","jsonrpc":"2.0","id":1} as myPayload in scenario scope
  And I set body to `myPayload`
  And I set headers to
      | name          | value            |
      | content-type  | application/json |
      | User-Agent    | apickli          |
      | x-apikey      | `apikey`         |

  When I POST to /mcp/v1/samples/adk-cymbal-retail/customers
  Then response code should be 200
  And response body should be valid json
  And response body should contain 1
  And response body should contain jsonrpc
  And response body should contain getAllCustomers

  Scenario: tools/call
  Given I store the raw value {"method":"tools/call","params":{"name":"getCustomerById","arguments":{"path_params":{"customerId":12345}}},"jsonrpc":"2.0","id":1} as myPayload in scenario scope
  And I set body to `myPayload`
  And I set headers to
      | name          | value            |
      | content-type  | application/json |
      | User-Agent    | apickli          |
      | x-apikey      | `apikey`         |

  When I POST to /mcp/v1/samples/adk-cymbal-retail/customers
  Then response code should be 200
  And response body should be valid json
  And response body should contain 1
  And response body should contain jsonrpc
  And response body should contain email
  And response body should contain createdAt

  Scenario: notifications/initialized
  Given I store the raw value {"method":"notifications/initialized","jsonrpc":"2.0"} as myPayload in scenario scope
  And I set body to `myPayload`
  And I set headers to
      | name          | value            |
      | content-type  | application/json |
      | User-Agent    | apickli          |
      | x-apikey      | `apikey`         |
      
  When I POST to /mcp/v1/samples/adk-cymbal-retail/customers
  Then response code should be 202
  And response body should be valid json
  And response body should contain notifications/initialized
  And response body should contain jsonrpc