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
  I want to experiment with API Product Operations while using API Keys
  So that I can understand how Operations work

  Scenario Outline: missing APIKey
    When I GET /apikey/users
    Then response code should be 401
    And response body path $.fault.detail.errorcode should be steps.oauth.v2.FailedToResolveAPIKey

  Scenario Outline: unknown resource
    Given I set APIKEY header to `viewerClientId`
    When I GET /apikey/unknown-resource
    Then response code should be 400
    And response body path $.response.message should be that request was unknown

  Scenario Outline: list users ok
    Given I set APIKEY header to `viewerClientId`
    When I GET /apikey/users
    Then response code should be 200
    And response body path $.status should be OK
    And response body path $.verb should be GET
    And response body path $.apiproduct-operation-resource should be /*/users

  Scenario Outline: list users reject
    Given I set APIKEY header to `creatorClientId`
    When I GET /apikey/users
    Then response code should be 401
    And response body path $.fault.detail.errorcode should be oauth.v2.InvalidApiKeyForGivenResource

  Scenario Outline: get single user ok
    Given I set APIKEY header to `viewerClientId`
    When I GET /apikey/users/1234
    Then response code should be 200
    And response body path $.status should be OK
    And response body path $.verb should be GET
    And response body path $.apiproduct-operation-resource should be /*/users/*

  Scenario Outline: get single user reject
    Given I set APIKEY header to `creatorClientId`
    When I GET /apikey/users/1234
    Then response code should be 401
    And response body path $.fault.detail.errorcode should be oauth.v2.InvalidApiKeyForGivenResource

  Scenario Outline: create user reject
    Given I set APIKEY header to `viewerClientId`
      And I set Content-Type header to text/plain
      And I set body to does-not-matter
    When I POST to /apikey/users
    Then response code should be 401
    And response body path $.fault.detail.errorcode should be oauth.v2.InvalidApiKeyForGivenResource

  Scenario Outline: create user ok
    Given I set APIKEY header to `creatorClientId`
      And I set Content-Type header to text/plain
      And I set body to does-not-matter
    When I POST to /apikey/users
    Then response code should be 200
      And response body path $.status should be OK
      And response body path $.verb should be POST
      And response body path $.apiproduct-operation-resource should be /*/users

  Scenario Outline: delete user reject 1
    Given I set APIKEY header to `viewerClientId`
    When I DELETE /apikey/users/1234
    Then response code should be 401
    And response body path $.fault.detail.errorcode should be oauth.v2.InvalidApiKeyForGivenResource

  Scenario Outline: delete user reject 2
    Given I set APIKEY header to `creatorClientId`
    When I DELETE /apikey/users/1234
    Then response code should be 401
    And response body path $.fault.detail.errorcode should be oauth.v2.InvalidApiKeyForGivenResource

  Scenario Outline: delete user ok
    Given I set APIKEY header to `adminClientId`
    When I DELETE /apikey/users/1234
    Then response code should be 200
      And response body path $.status should be OK
      And response body path $.verb should be DELETE
      And response body path $.apiproduct-operation-resource should be /*/users/*
