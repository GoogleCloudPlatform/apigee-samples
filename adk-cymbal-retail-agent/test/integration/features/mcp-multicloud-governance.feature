# Copyright 2026 Google LLC
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

Feature: MCP Multicloud Governance & Payload Authorization

  Background:
    Given I set headers to
      | name          | value            |
      | content-type  | application/json |
      | User-Agent    | apickli          |

  Scenario: 1. Successful Tool Discovery via KVM
    Given I set Authorization header to Bearer `customer_token`
    And I store the raw value {"method":"tools/list","jsonrpc":"2.0","id":1} as myPayload in scenario scope
    And I set body to `myPayload`
    When I POST to /mcp
    Then response code should be 200
    And response body should be valid json
    And response body should contain getAllOrders
    And response body should contain createOrder

  Scenario: 2. Authorized Tool Execution (Positive Payload Auth via Existing Proxy)
    Given I set Authorization header to Bearer `customer_token`
    And I store the raw value {"method":"tools/call","params":{"name":"getAllOrders","arguments":{}},"jsonrpc":"2.0","id":2} as myPayload in scenario scope
    And I set body to `myPayload`
    When I POST to /mcp
    Then response code should be 200
    And response body should be valid json
    And response body should contain jsonrpc

  Scenario: 3. Unauthorized Agent Request (Negative Credential Auth)
    Given I set Authorization header to Bearer foobar
    And I store the raw value {"method":"tools/call","params":{"name":"getAllOrders","arguments":{}},"jsonrpc":"2.0","id":3} as myPayload in scenario scope
    And I set body to `myPayload`
    When I POST to /mcp
    Then response code should be 401

  Scenario: 4. Method Not Found Governance (Invalid JSON-RPC Method)
    Given I set Authorization header to Bearer `customer_token`
    And I store the raw value {"method":"tools/unsupportedMethod","params":{},"jsonrpc":"2.0","id":4} as myPayload in scenario scope
    And I set body to `myPayload`
    When I POST to /mcp
    Then response code should be 400
    And response body should be valid json

  Scenario: 5. Multicloud Tool Execution (Target Proxy JSON-RPC Transformation)
    Given I set Authorization header to Bearer `customer_token`
    And I store the raw value {"method":"tools/call","params":{"name":"getOrderById","arguments":{"orderId":"101"}},"jsonrpc":"2.0","id":5} as myPayload in scenario scope
    And I set body to `myPayload`
    When I POST to /mcp
    Then response code should be 200
    And response body should be valid json
    And response body should contain customerId
