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
// Protocol Request Transformer: Vertex AI -> OpenAI JSON-RPC Schema
// Converts Vertex AI `generateContent` payload (contents[].parts[].text, system_instruction)
// to OpenAI / vLLM / Ollama chat format (messages[].role, messages[].content)
// ==============================================================================

var requestObj = request.content.asJSON;
var openAiMessages = [];

// 1. Extract and map Vertex AI System Instruction to OpenAI 'system' role
if (requestObj.system_instruction && requestObj.system_instruction.parts) {
  var sysText = requestObj.system_instruction.parts.map(function(p) { return p.text || ""; }).join("\n");
  if (sysText) {
    openAiMessages.push({
      role: "system",
      content: sysText
    });
  }
}

// 2. Extract Contents (User / Model turns)
if (requestObj.contents && Array.isArray(requestObj.contents)) {
  requestObj.contents.forEach(function(c) {
    var role = (c.role === "model") ? "assistant" : "user";
    var contentText = (c.parts || []).map(function(p) { return p.text || ""; }).join("\n");
    openAiMessages.push({
      role: role,
      content: contentText
    });
  });
}

var maxTokens = (requestObj.generationConfig && requestObj.generationConfig.maxOutputTokens) ? requestObj.generationConfig.maxOutputTokens : 2000;
var configuredModel = context.getVariable("propertyset.gemma_config.model_id");
if (!configuredModel || configuredModel.indexOf("gemma") === -1) {
  configuredModel = "gemma3:1b";
}

var openAiPayload = {
  model: configuredModel,
  messages: openAiMessages,
  temperature: (requestObj.generationConfig && requestObj.generationConfig.temperature) ? requestObj.generationConfig.temperature : 0.7,
  max_tokens: maxTokens
};

request.content = JSON.stringify(openAiPayload);
context.setVariable("request.header.Content-Type", "application/json");

// Direct Apigee target connection to configured Cloud Run Gemma endpoint
var gemmaUrl = context.getVariable("propertyset.gemma_config.gemma_url");
if (!gemmaUrl || gemmaUrl.indexOf("run.app") === -1) {
  gemmaUrl = "https://gemma-cpu-router-78901377646.us-central1.run.app/v1/chat/completions";
}
context.setVariable("target.url", gemmaUrl);

