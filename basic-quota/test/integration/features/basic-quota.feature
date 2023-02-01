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
  I want to experiment with the quota policy
  So that I can understand how it can be implemented
  
  Scenario Outline: Quota
    When I GET /?apikey=`clientId1`
    Then response code should be <code>
    And response body path $.status should be <status>
    And response body path $.allowed should be <allowed>
    Examples:
      | iteration | code |  status | allowed |
      |         1 |  200 | success |      10 |
      |         2 |  200 | success |      10 |
      |         3 |  200 | success |      10 |
      |         4 |  200 | success |      10 |
      |         5 |  200 | success |      10 |
      |         6 |  200 | success |      10 |
      |         7 |  200 | success |      10 |
      |         8 |  200 | success |      10 |
      |         9 |  200 | success |      10 |
      |        10 |  200 | success |      10 |
    
  Scenario: Quota failure
    When I GET /?apikey=`clientId1`
    Then response code should be 429
    And response body path $.status should be "quota exceeded"

  Scenario: Different Quota
    When I GET /?apikey=`clientId2`
    Then response code should be 200
    And response body path $.status should be success
    And response body path $.allowed should be 1000
