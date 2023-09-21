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
  I want to experiment with API Product Operations while using OAuth tokens
  So that I can understand how Operations work

Scenario: missing Token
  When I GET /token/users
  Then response code should be 401
  And response body path $.fault.detail.errorcode should be oauth.v2.InvalidAccessToken

Scenario: get a token for viewer
  Given I have basic authentication credentials `viewerClientId` and `viewerClientSecret`
  And I set Content-Type header to application/x-www-form-urlencoded
  And I set body to grant_type=client_credentials
  When I POST to -oauth2-cc/token
  Then response code should be 200
  And response body path $.token_type should be Bearer
  And I store the value of body path $.access_token as VIEWER_ACCESSTOKEN in global scope

Scenario: get a token for creator
  Given I have basic authentication credentials `creatorClientId` and `creatorClientSecret`
  And I set Content-Type header to application/x-www-form-urlencoded
  And I set body to grant_type=client_credentials
  When I POST to -oauth2-cc/token
  Then response code should be 200
  And response body path $.token_type should be Bearer
  And I store the value of body path $.access_token as CREATOR_ACCESSTOKEN in global scope

Scenario: get a token for admin
  Given I have basic authentication credentials `adminClientId` and `adminClientSecret`
  And I set Content-Type header to application/x-www-form-urlencoded
  And I set body to grant_type=client_credentials
  When I POST to -oauth2-cc/token
  Then response code should be 200
  And response body path $.token_type should be Bearer
  And I store the value of body path $.access_token as ADMIN_ACCESSTOKEN in global scope

Scenario: unknown resource
  Given I set TOKEN header to `VIEWER_ACCESSTOKEN`
  When I GET /token/unknown-resource
  Then response code should be 400
  And response body path $.response.message should be that request was unknown

Scenario: list users ok
  Given I set TOKEN header to `VIEWER_ACCESSTOKEN`
  When I GET /token/users
  Then response code should be 200
  And response body path $.status should be OK
  And response body path $.verb should be GET
  And response body path $.apiproduct-operation-resource should be /*/users

Scenario: list users reject
  Given I set TOKEN header to `CREATOR_ACCESSTOKEN`
  When I GET /token/users
  Then response code should be 401
  And response body path $.fault.detail.errorcode should be keymanagement.service.InvalidAPICallAsNoApiProductMatchFound

Scenario: get single user ok
  Given I set TOKEN header to `VIEWER_ACCESSTOKEN`
  When I GET /token/users/1234
  Then response code should be 200
  And response body path $.status should be OK
  And response body path $.verb should be GET
  And response body path $.apiproduct-operation-resource should be /*/users/*

Scenario: get single user reject
  Given I set TOKEN header to `CREATOR_ACCESSTOKEN`
  When I GET /token/users/1234
  Then response code should be 401
  And response body path $.fault.detail.errorcode should be keymanagement.service.InvalidAPICallAsNoApiProductMatchFound

Scenario: create user reject
  Given I set TOKEN header to `VIEWER_ACCESSTOKEN`
  And I set Content-Type header to text/plain
  And I set body to does-not-matter
  When I POST to /token/users
  Then response code should be 401
  And response body path $.fault.detail.errorcode should be keymanagement.service.InvalidAPICallAsNoApiProductMatchFound

Scenario: create user ok
  Given I set TOKEN header to `CREATOR_ACCESSTOKEN`
  And I set Content-Type header to text/plain
  And I set body to does-not-matter
  When I POST to /token/users
  Then response code should be 200
  And response body path $.status should be OK
  And response body path $.verb should be POST
  And response body path $.apiproduct-operation-resource should be /*/users

Scenario: delete user reject 1
  Given I set TOKEN header to `VIEWER_ACCESSTOKEN`
  When I DELETE /token/users/1234
  Then response code should be 401
  And response body path $.fault.detail.errorcode should be keymanagement.service.InvalidAPICallAsNoApiProductMatchFound

Scenario: delete user reject 2
  Given I set TOKEN header to `CREATOR_ACCESSTOKEN`
  When I DELETE /token/users/1234
  Then response code should be 401
  And response body path $.fault.detail.errorcode should be keymanagement.service.InvalidAPICallAsNoApiProductMatchFound

Scenario: delete user ok
  Given I set TOKEN header to `ADMIN_ACCESSTOKEN`
  When I DELETE /token/users/1234
  Then response code should be 200
  And response body path $.status should be OK
  And response body path $.verb should be DELETE
  And response body path $.apiproduct-operation-resource should be /*/users/*