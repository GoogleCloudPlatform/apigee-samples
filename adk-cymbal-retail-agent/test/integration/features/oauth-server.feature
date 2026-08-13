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

Feature: OAuth 2.0 Server & Token Exchange

Scenario: Authorize endpoint missing client_id parameter
  When I GET /authorize?response_type=code&scope=customer&redirect_uri=http://localhost
  Then response code should be 400
  And response body should be valid json
  And response body should contain invalid_request

Scenario: Token exchange with invalid client secret
  Given I set Authorization header to Basic c29tZV9jbGllbnRfaWQ6aW52YWxpZF9zZWNyZXQ=
  And I set headers to
      | name         | value                              |
      | content-type | application/x-www-form-urlencoded  |
  And I store the raw value grant_type=authorization_code&code=fake_code&redirect_uri=http://localhost as myPayload in scenario scope
  And I set body to `myPayload`
  When I POST to /token
  Then response code should be 401
  And response body should be valid json
  And response body should contain invalid_client

Scenario: Token exchange with unsupported grant type
  Given I set Authorization header to Basic c29tZV9jbGllbnRfaWQ6aW52YWxpZF9zZWNyZXQ=
  And I set headers to
      | name         | value                              |
      | content-type | application/x-www-form-urlencoded  |
  And I store the raw value grant_type=client_credentials as myPayload in scenario scope
  And I set body to `myPayload`
  When I POST to /token
  Then response code should be 400
  And response body should be valid json
  And response body should contain Unsupported grant type
