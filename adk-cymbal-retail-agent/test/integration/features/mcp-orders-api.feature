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

Feature: MCP Orders API

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
  And response body should contain getOrderById
  And response body should contain getAllOrders
  And response body should contain createOrder
  And response body should contain updateOrder

Scenario: tools/call - getOrderById
  Given I store the raw value {"method":"tools/call","params":{"name":"getOrderById","arguments":{"orderId":"123456"}},"jsonrpc":"2.0","id":1} as myPayload in scenario scope
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
  And response body should contain customerId
  And response body should contain totalAmount
  And response body should contain status

Scenario: tools/call - getAllOrders
  Given I store the raw value {"method":"tools/call","params":{"name":"getAllOrders","arguments":{}},"jsonrpc":"2.0","id":2} as myPayload in scenario scope
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
  And response body should contain shippingAddress

Scenario: tools/call - createOrder
  Given I store the raw value {"method":"tools/call","params":{"name":"createOrder","arguments":{"NewOrder":{"customerId":"cust-001","items":[{"itemId":"item-1","quantity":2}]}}},"jsonrpc":"2.0","id":3} as myPayload in scenario scope
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
  And response body should contain totalAmount

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
