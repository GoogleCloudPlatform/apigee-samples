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

Feature: MCP Returns API

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
  And response body should contain getReturnById
  And response body should contain getAllReturns
  And response body should contain createReturnRequest
  And response body should contain updateReturnStatus
  And response body should contain processRefund

Scenario: tools/call - getReturnById
  Given I store the raw value {"method":"tools/call","params":{"name":"getReturnById","arguments":{"returnId":"ret-123"}},"jsonrpc":"2.0","id":1} as myPayload in scenario scope
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
  And response body should contain orderId
  And response body should contain returnStatus
  And response body should contain reason

Scenario: tools/call - getAllReturns
  Given I store the raw value {"method":"tools/call","params":{"name":"getAllReturns","arguments":{}},"jsonrpc":"2.0","id":2} as myPayload in scenario scope
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
  And response body should contain returnId

Scenario: tools/call - createReturnRequest
  Given I store the raw value {"method":"tools/call","params":{"name":"createReturnRequest","arguments":{"NewReturnRequest":{"orderId":"ord-001","reason":"Defective item"}}},"jsonrpc":"2.0","id":3} as myPayload in scenario scope
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
  And response body should contain returnId

Scenario: tools/call - processRefund
  Given I store the raw value {"method":"tools/call","params":{"name":"processRefund","arguments":{"returnId":"ret-001","ProcessRefundRequest":{"amount":49.99}}},"jsonrpc":"2.0","id":4} as myPayload in scenario scope
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
  And response body should contain returnId

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
