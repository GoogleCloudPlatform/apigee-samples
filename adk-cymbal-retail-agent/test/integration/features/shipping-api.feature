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

Feature: Shipping API

Scenario: Using an invalid Access Token
  Given I set Authorization header to Bearer foobar
  When I POST to /v2/samples/adk-cymbal-retail/shipping
  Then response code should be 401
  And response body should be valid json

Scenario: Create a shipping label and get rates
  Given I set Authorization header to Bearer customer_token
  And I store the raw value {"shippingLabelRequest":{"recipientName":"Alice Smith","address":"1600 Amphitheatre Pkwy, Mountain View, CA 94043","weight":2.5}} as myPayload in scenario scope
  And I set body to `myPayload`
  When I POST to /v2/samples/adk-cymbal-retail/shipping
  Then response code should be 200
  And response body should be valid json
  And response body should contain shippingLabelResponse
  And response body should contain confirmationId
