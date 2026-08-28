/**
 * Copyright 2026 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// ==============================================================================
// Protocol Response Transformer: OpenAI -> Vertex AI JSON-RPC Schema
// Normalizes responses from private Gemma (OpenAI choices[].message.content)
// to standard Vertex AI `generateContent` response (candidates[].content.parts[].text)
// and extracts token counts for Apigee Data Collectors & Analytics.
// ==============================================================================

var responseObj = response.content.asJSON;
var replyText = "";
var finishReason = "STOP";
var promptTokens = 0;
var candidateTokens = 0;
var totalTokens = 0;

if (responseObj.choices && responseObj.choices.length > 0) {
  var choice = responseObj.choices[0];
  if (choice.message && choice.message.content) {
    replyText = choice.message.content;
  }
  if (choice.finish_reason) {
    finishReason = choice.finish_reason.toUpperCase();
  }
}

if (responseObj.usage) {
  promptTokens = responseObj.usage.prompt_tokens || 0;
  candidateTokens = responseObj.usage.completion_tokens || 0;
  totalTokens = responseObj.usage.total_tokens || (promptTokens + candidateTokens);
}

var vertexResponse = {
  candidates: [
    {
      content: {
        role: "model",
        parts: [
          { text: replyText }
        ]
      },
      finishReason: finishReason
    }
  ],
  usageMetadata: {
    promptTokenCount: promptTokens,
    candidatesTokenCount: candidateTokens,
    totalTokenCount: totalTokens
  },
  modelVersion: context.getVariable("propertyset.gemma_config.model_id") || "gemma3:4b",
  responseId: responseObj.id || "gemma-" + Date.now()
};

response.content = JSON.stringify(vertexResponse);
context.setVariable("response.header.Content-Type", "application/json");

// Populate token variables for downstream logging policies
context.setVariable("prompt_token_count", promptTokens);
context.setVariable("candidates_token_count", candidateTokens);
context.setVariable("total_token_count", totalTokens);
context.setVariable("candidate_contents_0", JSON.stringify([{ text: replyText }]));
