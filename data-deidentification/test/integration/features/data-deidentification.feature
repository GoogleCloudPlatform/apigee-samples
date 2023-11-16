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
  I want to experiment with DLP masking
  So that I can understand how to mask sensitive data

Scenario: GET unknown resource
  When I GET /unknown-resource
  Then response code should be 404
  And response body path $.error.message should be that request was unknown

Scenario: POST to an unknown resource
  When I POST to /unknown-resource
  Then response code should be 404
  And response body path $.error.message should be that request was unknown

Scenario: try to mask xml with wrong content-type
  Given I set Content-Type header to text/plain
  And I set body to does-not-matter
  When I POST to /mask-xml
  Then response code should be 415
  And response body path $.error.code should be 415.01

Scenario: try to mask json with wrong content-type
  Given I set Content-Type header to text/plain
  And I set body to does-not-matter
  When I POST to /mask-json
  Then response code should be 415
  And response body path $.error.code should be 415.02

Scenario: mask email within xml
  Given I set Content-Type header to application/xml
  And I set body to <root><address>someone@example.com</address></root>
  When I POST to /mask-xml
  Then response code should be 200
  And response header Content-Type should be application/xml
  And response body should contain <address>\*\*\*\*\*\*\*@\*\*\*\*\*\*\*.com</address>

Scenario: mask phone within xml
  Given I set Content-Type header to application/xml
  And I set body to <root><contact>434-989-1023</contact></root>
  When I POST to /mask-xml
  Then response code should be 200
  And response header Content-Type should be application/xml
  And response body should contain <contact>\*\*\*-\*\*\*-\*\*23</contact>

Scenario: do not mask phone in XML when using justemail template
  Given I set Content-Type header to application/xml
  And I set body to <root><contact>434-989-1023</contact></root>
  When I POST to /mask-xml?justemail=true
  Then response code should be 200
  And response header Content-Type should be application/xml
  And response body should not contain <contact>\*\*\*-\*\*\*-\*\*23</contact>

Scenario: mask email within json
  Given I set Content-Type header to application/json
  And I set body to { "address" : "someone@example.com" }
  When I POST to /mask-json
  Then response code should be 200
  And response header Content-Type should be application/json
  And response body should contain { "address" : "\*\*\*\*\*\*\*@\*\*\*\*\*\*\*\.com" }

Scenario: mask phone within json
  Given I set Content-Type header to application/json
  And I set body to { "contact" : "434-989-1023" }
  When I POST to /mask-json
  Then response code should be 200
  And response header Content-Type should be application/json
  And response body should contain { "contact" : "\*\*\*\-\*\*\*\-\*\*23" }

Scenario: do not mask phone when template is justemail
  Given I set Content-Type header to application/json
  And I set body to { "contact" : "434-989-1023" }
  When I POST to /mask-json?justemail=true
  Then response code should be 200
  And response header Content-Type should be application/json
  And response body should not contain { "contact" : "\*\*\*\-\*\*\*\-\*\*23" }