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
  I want to experiment with the Regular Expression and JSON Threat Protection policies
  So that I can understand how it can be implemented

Scenario: Threat in Request (SQL Injection Detected)
  When I GET /json?query="delete"
  Then response code should be 500

Scenario: No Threat in Request (No Threat Detected)
  When I GET /json?query="select"
  Then response code should be 200

Scenario: JSON Payload larger than expected (Potential Threat Detected)
  Given I store the raw value {"f1": "t1", "f2": "t2", "f3": "t3", "f4": "t4", "f5": "t5", "f6": "t6"} as myPayload in scenario scope
  And I set body to `myPayload`
  And I set content-type header to application/json
  When I POST to /echo
  Then response code should be 500

Scenario: JSON Payload as expected (No Threat Detected)
  Given I store the raw value {"f1": "t1", "f2": "t2", "f3": "t3", "f4": "t4", "f5": "t5"} as myPayload in scenario scope
  And I set body to `myPayload`
  And I set content-type header to application/json
  When I POST to /echo
  Then response code should be 200