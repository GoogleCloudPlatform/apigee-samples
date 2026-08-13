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

var requestObj = request.content.asJSON;
var openAiMessages = [];

// 1. Extract System Instruction if present
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

var openAiPayload = {
  model: context.getVariable("propertyset.gemma_config.model_id") || "gemma3:4b",
  messages: openAiMessages,
  temperature: (requestObj.generationConfig && requestObj.generationConfig.temperature) ? requestObj.generationConfig.temperature : 0.7
};

request.content = JSON.stringify(openAiPayload);
context.setVariable("request.header.Content-Type", "application/json");
