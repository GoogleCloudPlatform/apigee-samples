# Copyright 2023 Google LLC
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
  As an Apigee platform explorer
  I want to experiment with the client credentials OAuth flow
  So that I can understand how it can be implemented

Scenario: [Helper] Obtain OAuth Access Token
  Given I set form parameters to
    |parameter|value|
    |grant_type|client_credentials|
  And I have basic authentication credentials `clientId` and `clientSecret`
  When I POST to /token
  Then response code should be 200
  And response body should be valid json
  And I store the value of body path $.access_token as accessToken in global scope

Scenario: Using a valid OAuth Access Token
  Given I set authorization header to "Bearer `accessToken`"
  When I GET /resource
  Then response code should be 200
  And response body path $.status should be success

Scenario: Using an invalid OAuth Access Token
  Given I set authorization header to "Bearer foobar"
  When I GET /resource
  Then response code should be 401
  And response body should be valid json
  And response body path $.fault.detail.errorcode should be keymanagement.service.invalid_access_token