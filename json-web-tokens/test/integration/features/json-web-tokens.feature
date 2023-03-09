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
  I want to experiment with the JWT policy
  So that I can understand how it can be implemented
  
  Scenario Outline: Generate Signed JWT
    When I POST /generate-signed
    Then response code should be 200
    Then response body should contain output_jwt
    
  Scenario: Verify Signed JWT
    Given I store the raw value $.headers.TOKEN as outputToken in scenario scope
    Given I set form parameters to JWT=outputToken
    When I POST /verify-signed
    Then response code should be 200

  Scenario Outline: Generate Encrypted JWT
    When I POST /generate-encrypted
    Then response code should be 200
    Then response body should contain output_jwt
    
  Scenario: Verify Encrypted JWT
    Given I store the raw value $.headers.TOKEN as outputToken in scenario scope
    Given I set form parameters to JWT=outputToken
    When I POST /verify-encrypted
    Then response code should be 200
