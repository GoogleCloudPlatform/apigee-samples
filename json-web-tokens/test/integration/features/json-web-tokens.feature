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

Scenario: Generate Signed JWT
  When I POST to /generate-signed
  Then response code should be 200
  And response body should be valid json
  And response body should contain output_jwt
  And I store the value of body path $.output_jwt as outputToken in global scope

Scenario: Verify Signed JWT
  Given I set form parameters to
    | parameter | value         |
    | JWT       | `outputToken` |
  When I POST to /verify-signed
  Then response code should be 200
  And response body should contain alg=RS256

Scenario: Generate Encrypted JWT
  When I POST to /generate-encrypted
  Then response code should be 200
  And response body should be valid json
  And response body should contain output_jwt
  And I store the value of body path $.output_jwt as outputToken in global scope

Scenario: Verify Encrypted JWT
  Given I set form parameters to
    | parameter | value         |
    | JWT       | `outputToken` |
  When I POST to /verify-encrypted
  Then response code should be 200
  And response body should contain enc=A128GCM