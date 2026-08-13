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

Feature: MCP Shipping API

Scenario: initialize
  Given I store the raw value {"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"mcp","version":"0.1.0"}},"jsonrpc":"2.0","id":0} as myPayload in scenario scope
  And I set body to `myPayload`
  And I set headers to
      | name          | value            |
      | content-type  | application/json |
      | User-Agent    | apickli          |
      | Authorization | Bearer `customer_token` |

  When I POST to /mcp
  Then response code should be 200
  And response body should be valid json
  And response body should contain serverInfo
  And response body should contain jsonrpc

Scenario: tools/list
  Given I store the raw value {"method":"tools/list","jsonrpc":"2.0","id":1} as myPayload in scenario scope
  And I set body to `myPayload`
  And I set headers to
      | name          | value            |
      | content-type  | application/json |
      | User-Agent    | apickli          |
      | Authorization | Bearer `customer_token` |

  When I POST to /mcp
  Then response code should be 200
  And response body should be valid json
  And response body should contain jsonrpc
  And response body should contain createShippingLabel

Scenario: tools/call - createShippingLabel
  Given I store the raw value {"method":"tools/call","params":{"name":"createShippingLabel","arguments":{"createShippingLabelBody":{"shippingLabelRequest":{"recipientName":"Alice Smith","address":"456 Oak Ave, Seattle, WA","weight":2.5}}}},"jsonrpc":"2.0","id":1} as myPayload in scenario scope
  And I set body to `myPayload`
  And I set headers to
      | name          | value            |
      | content-type  | application/json |
      | User-Agent    | apickli          |
      | Authorization | Bearer `customer_token` |

  When I POST to /mcp
  Then response code should be 200
  And response body should be valid json
  And response body should contain jsonrpc
  And response body should contain confirmationId
  And response body should contain shippingLabelStatus
  And response body should contain shippingProvider

Scenario: notifications/initialized
  Given I store the raw value {"method":"notifications/initialized","jsonrpc":"2.0"} as myPayload in scenario scope
  And I set body to `myPayload`
  And I set headers to
      | name          | value            |
      | content-type  | application/json |
      | User-Agent    | apickli          |
      | Authorization | Bearer `customer_token` |
      
  When I POST to /mcp
  Then response code should be 202

Scenario: Unauthenticated MCP tool call
  Given I store the raw value {"method":"tools/call","params":{"name":"createShippingLabel","arguments":{"createShippingLabelBody":{"shippingLabelRequest":{"recipientName":"Alice Smith","address":"456 Oak Ave, Seattle, WA","weight":2.5}}}},"jsonrpc":"2.0","id":1} as myPayload in scenario scope
  And I set body to `myPayload`
  And I set headers to
      | name          | value            |
      | content-type  | application/json |
      | User-Agent    | apickli          |
  When I POST to /mcp
  Then response code should be 401
