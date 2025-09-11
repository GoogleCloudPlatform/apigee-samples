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
  Given I store the raw value {"jsonrpc": "2.0","id": 987654321,"method": "initialize","params": {"protocolVersion": "2025-06-18","capabilities": {"tools": {},"resources": {},"prompts": {}},"clientInfo": {"name": "test-client","version": "1.0.0"}}} as myPayload in scenario scope
  And I set body to `myPayload`
  And I set headers to
      | name          | value            |
      | content-type  | application/json |
      | User-Agent    | apickli          |
  When I POST to /mcp/v1/samples/adk-cymbal-retail/customers
  Then response code should be 200
  And response body should be valid json
  And response body should contain 987654321
  And response body should contain serverInfo

Scenario: tools/list
  Given I store the raw value {"jsonrpc":"2.0","id":987654321,"method":"tools/list","params":{"cursor":"optional-cursor-value"}} as myPayload in scenario scope
  And I set body to `myPayload`
  And I set headers to
      | name          | value            |
      | content-type  | application/json |
      | User-Agent    | apickli          |
  When I POST to /mcp/v1/samples/adk-cymbal-retail/customers
  Then response code should be 200
  And response body should contain 987654321
  And response body should contain jsonrpc
  And response body should contain getAllCustomers