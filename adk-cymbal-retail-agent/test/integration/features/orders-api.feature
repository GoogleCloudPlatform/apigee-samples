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

Feature:
  As a developer
  I want to experiment with Orders API
  So that I can understand how it can be used

Scenario: Using an invalid API Key
  Given I set x-apikey header to foobar
  When I GET /orders
  Then response code should be 401
  And response body should be valid json

Scenario: Retieve a specfic order record
  Given I set x-apikey header to `apikey`
  When I GET /orders/123
  Then response code should be 200
  And response body should be valid json
  And response body should contain shippingAddress

Scenario: Retieve a list of orders
  Given I set x-apikey header to `apikey`
  When I GET /orders
  Then response code should be 200
  And response body should be valid json
  And response body should contain shippingAddress

Scenario: Create a new order
  Given I set x-apikey header to `apikey`
  And I store the raw value {"customerId": 101,"id": 87654,"items": ["Laptop", "Wireless Mouse", "Keyboard"],"shippingAddress": "123 Tech Avenue, Silicon City, CA 90210","status": "shipped","totalAmount": 1500.75} as myPayload in scenario scope
  And I set body to `myPayload`
  When I POST to /customers
  Then response code should be 201
  And response body should be valid json