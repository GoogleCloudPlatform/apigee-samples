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
  I want to experiment with Customers API
  So that I can understand how it can be used

Scenario: Using an invalid API Key
  Given I set x-apikey header to foobar
  When I GET /customers
  Then response code should be 401
  And response body should be valid json

Scenario: Retieve a specfic customer record
  Given I set x-apikey header to `apikey`
  When I GET /customers/123
  Then response code should be 200
  And response body should be valid json
  And response body should contain firstName

Scenario: Retieve a list of customers
  Given I set x-apikey header to `apikey`
  When I GET /customers
  Then response code should be 200
  And response body should be valid json
  And response body should contain firstName

Scenario: Create a new customer
  Given I set x-apikey header to `apikey`
  And I store the raw value {"firstName": "John","lastName": "Doe","email": "john.doe@example.com","phoneNumber": "555-123-4567","address": "123 Highland Dr","city": "Some Creek","state": "GA","zip": "30303"} as myPayload in scenario scope
  And I set body to `myPayload`
  When I POST to /customers
  Then response code should be 201
  And response body should be valid json