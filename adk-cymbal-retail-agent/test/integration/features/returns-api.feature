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

Feature: Returns API

Scenario: Using an invalid API Key
  Given I set x-apikey header to foobar
  When I GET /v1/samples/adk-cymbal-retail/returns
  Then response code should be 401
  And response body should be valid json

Scenario: Retieve a specfic return record
  Given I set x-apikey header to `apikey`
  When I GET /v1/samples/adk-cymbal-retail/returns/123
  Then response code should be 200
  And response body should be valid json
  And response body should contain returnId

Scenario: Retieve a list of returns
  Given I set x-apikey header to `apikey`
  When I GET /v1/samples/adk-cymbal-retail/returns
  Then response code should be 200
  And response body should be valid json
  And response body should contain returnId

Scenario: Create a new return
  Given I set x-apikey header to `apikey`
  And I store the raw value {"returnId":"RMA789012","orderId":"ORD123456","returnStatus":"requested","items":["SKU987","SKU654"],"reason":"Item not as described","requestedAt":"2023-10-26T10:00:00Z","notes":"The color was completely different from the website image."} as myPayload in scenario scope
  And I set body to `myPayload`
  When I POST to /v1/samples/adk-cymbal-retail/returns
  Then response code should be 201
  And response body should be valid json
  And response body should contain returnId