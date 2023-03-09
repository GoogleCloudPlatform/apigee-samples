# Copyright 2022 Google LLC
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
  So that I can understand how it can be implemented and how the scopes help with finer access

  Scenario: [Helper] Obtain OAuth Access Token with read scope
    Given I set form parameters to
      |parameter|value|
      |grant_type|client_credentials|
      |scope|read|
    And I have basic authentication credentials `read_clientId` and `read_clientSecret`
    When I POST to /token
    Then response code should be 200
    And response body should be valid json
    And I store the value of body path $.access_token as accessToken in global scope
  
  Scenario: Using a valid OAuth Access Token and performing a GET operation
    Given I set authorization header to "Bearer `accessToken`"
    When I GET /resource
    Then response code should be 200
    And response body path $.status should be success
  
  Scenario: Using a valid OAuth Access Token and performing a POST operation
    Given I set authorization header to "Bearer `accessToken`"
    When I POST to /resource
    Then response code should be 403
    And response body should be valid json
    And response body path $.fault.detail.errorcode should be steps.oauth.v2.InsufficientScope

  Scenario: [Helper] Obtain OAuth Access Token with write scope
    Given I set form parameters to
      |parameter|value|
      |grant_type|client_credentials|
      |scope|write|
    And I have basic authentication credentials `write_clientId` and `write_clientSecret`
    When I POST to /token
    Then response code should be 200
    And response body should be valid json
    And I store the value of body path $.access_token as accessToken in global scope
  
  Scenario: Using a valid OAuth Access Token and performing a GET operation
    Given I set authorization header to "Bearer `accessToken`"
    When I GET /resource
    Then response code should be 200
    And response body path $.status should be success
  
  Scenario: Using a valid OAuth Access Token and performing a POST operation
    Given I set authorization header to "Bearer `accessToken`"
    When I POST to /resource
    Then response code should be 200
    And response body path $.status should be success
  
  Scenario: Using an invalid OAuth Access Token
    Given I set authorization header to "Bearer foobar"
    When I GET /resource
    Then response code should be 401
    And response body should be valid json
    And response body path $.fault.detail.errorcode should be keymanagement.service.invalid_access_token
    