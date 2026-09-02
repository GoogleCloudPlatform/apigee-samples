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

Feature: Apigee LLM AI Gateway API

  Background:
    Given I set headers to
      | name          | value            |
      | content-type  | application/json |
      | User-Agent    | apickli          |

  Scenario: 1. Unauthorized request without API Key returns 401
    Given I store the raw value {"model":"gemini-2.5-flash","messages":[{"role":"user","content":"Hello"}]} as myPayload in scenario scope
    And I set body to `myPayload`
    When I POST to /v1/llm-ai-gateway/chat/completions
    Then response code should be 401
    And response body should be valid json

  Scenario: 2. Unauthorized request with invalid API Key returns 401
    Given I set x-apikey header to invalid_api_key_12345
    And I store the raw value {"model":"gemini-2.5-flash","messages":[{"role":"user","content":"Hello"}]} as myPayload in scenario scope
    And I set body to `myPayload`
    When I POST to /v1/llm-ai-gateway/chat/completions
    Then response code should be 401
    And response body should be valid json

  Scenario: 3. OpenAI-compatible chat completions request with valid API Key
    Given I set headers to
      | name                            | value            |
      | content-type                    | application/json |
      | User-Agent                      | apickli          |
      | x-apikey                        | `llm_apikey`     |
      | x-llm-cache                     | false            |
      | x-llm-routing                   | false            |
      | x-llm-sanitize-user-prompt      | false            |
      | x-llm-sanitize-model-response   | false            |
    And I store the raw value {"model":"gemini-2.5-flash","messages":[{"role":"user","content":"Respond with the single word: OK"}]} as myPayload in scenario scope
    And I set body to `myPayload`
    When I POST to /v1/llm-ai-gateway/chat/completions
    Then response body should be valid json

  Scenario: 4. Native /chat endpoint request with valid API Key
    Given I set headers to
      | name                            | value            |
      | content-type                    | application/json |
      | User-Agent                      | apickli          |
      | x-apikey                        | `llm_apikey`     |
      | x-llm-cache                     | false            |
      | x-llm-routing                   | false            |
    And I store the raw value {"model":"gemini-2.5-flash","messages":[{"role":"user","content":"Hello from Cymbal Retail"}]} as myPayload in scenario scope
    And I set body to `myPayload`
    When I POST to /v1/llm-ai-gateway/chat
    Then response body should be valid json

  Scenario: 5. Model routing with frontier tier header
    Given I set headers to
      | name                            | value            |
      | content-type                    | application/json |
      | User-Agent                      | apickli          |
      | x-apikey                        | `llm_apikey`     |
      | x-model-tier                    | frontier         |
      | x-llm-cache                     | false            |
    And I store the raw value {"model":"gemini-2.5-flash","messages":[{"role":"user","content":"Provide order return policy"}]} as myPayload in scenario scope
    And I set body to `myPayload`
    When I POST to /v1/llm-ai-gateway/chat/completions
    Then response body should be valid json

  Scenario: 6. Model override via x-llm-model header
    Given I set headers to
      | name                            | value            |
      | content-type                    | application/json |
      | User-Agent                      | apickli          |
      | x-apikey                        | `llm_apikey`     |
      | x-llm-model                     | gemini-2.5-pro   |
      | x-llm-cache                     | false            |
      | x-llm-routing                   | false            |
    And I store the raw value {"model":"gemini-2.5-flash","messages":[{"role":"user","content":"What are your operating hours?"}]} as myPayload in scenario scope
    And I set body to `myPayload`
    When I POST to /v1/llm-ai-gateway/chat/completions
    Then response body should be valid json

  Scenario: 7. Token quota enforcement and rate limiting flags
    Given I set headers to
      | name                            | value            |
      | content-type                    | application/json |
      | User-Agent                      | apickli          |
      | x-apikey                        | `llm_apikey`     |
      | x-llm-prompt-rate-limiting      | true             |
      | x-llm-token-quota-enforce       | true             |
      | x-llm-cache                     | false            |
      | x-llm-routing                   | false            |
    And I store the raw value {"model":"gemini-2.5-flash","messages":[{"role":"user","content":"Check order 123"}]} as myPayload in scenario scope
    And I set body to `myPayload`
    When I POST to /v1/llm-ai-gateway/chat/completions
    Then response body should be valid json

  Scenario: 8. Responsible AI Sanitization flags enabled
    Given I set headers to
      | name                            | value            |
      | content-type                    | application/json |
      | User-Agent                      | apickli          |
      | x-apikey                        | `llm_apikey`     |
      | x-llm-sanitize-user-prompt      | true             |
      | x-llm-sanitize-model-response   | true             |
      | x-llm-cache                     | false            |
      | x-llm-routing                   | false            |
    And I store the raw value {"model":"gemini-2.5-flash","messages":[{"role":"user","content":"My email is test@example.com"}]} as myPayload in scenario scope
    And I set body to `myPayload`
    When I POST to /v1/llm-ai-gateway/chat/completions
    Then response body should be valid json

  Scenario: 9. Native Vertex AI generateContent endpoint
    Given I set headers to
      | name                            | value            |
      | content-type                    | application/json |
      | User-Agent                      | apickli          |
      | x-apikey                        | `llm_apikey`     |
      | x-llm-cache                     | false            |
      | x-llm-routing                   | false            |
    And I store the raw value {"contents":[{"role":"USER","parts":[{"text":"Hello from Cymbal"}]}]} as myPayload in scenario scope
    And I set body to `myPayload`
    When I POST to /v1/llm-ai-gateway/projects/`PROJECT_ID`/locations/us-central1/publishers/google/models/gemini-2.5-flash:generateContent
    Then response body should be valid json

  Scenario: 10. Request to unknown LLM Gateway route returns 404
    Given I set x-apikey header to `llm_apikey`
    When I GET /v1/llm-ai-gateway/unknown-route
    Then response code should be 404
