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

var modelTierHeader = context.getVariable("request.header.x-model-tier");
var modelNameHeader = context.getVariable("request.header.x-model-name");
var prompt = context.getVariable("prompt_contents_0") || "";
var gemmaUrl = context.getVariable("propertyset.gemma_config.gemma_url") || "";
var isGemmaConfigured = gemmaUrl.length > 0 && gemmaUrl.indexOf("gemma-cpu-router-run.app") === -1 && gemmaUrl.indexOf("gemma-2-9b-private-router.run.app") === -1;
var routeToGemma = false;

// 1. Explicit Header Override Check
if (modelTierHeader && (modelTierHeader.toLowerCase() === "local" || modelTierHeader.toLowerCase() === "gemma")) {
  routeToGemma = true;
} else if (modelNameHeader && modelNameHeader.toLowerCase().indexOf("gemma") !== -1) {
  routeToGemma = true;
} else if (isGemmaConfigured) {
  // 2. Intelligent Prompt Complexity Classifier (active when Gemma endpoint is provisioned)
  var trimmedPrompt = prompt.trim().toLowerCase();
  var wordCount = trimmedPrompt.split(/\s+/).length;
  
  // Simple greetings, single-intent inquiries, or FAQ phrases routed to local Gemma
  var simpleGreetingPatterns = [
    /^hello[\s!.]*$/,
    /^hi[\s!.]*$/,
    /^hey[\s!.]*$/,
    /^how are you[\s?!.]*$/,
    /^what can you do[\s?!.]*$/,
    /^help[\s!.]*$/,
    /^good (morning|afternoon|evening)[\s!.]*$/
  ];
  
  var isGreeting = simpleGreetingPatterns.some(function(pattern) {
    return pattern.test(trimmedPrompt);
  });
  
  if (isGreeting || (wordCount <= 3 && trimmedPrompt.indexOf("order") === -1 && trimmedPrompt.indexOf("return") === -1)) {
    routeToGemma = true;
  }
}

context.setVariable("route_to_gemma", routeToGemma ? "true" : "false");
print("Gemma Model Routing Decision: route_to_gemma=" + routeToGemma + " (isGemmaConfigured=" + isGemmaConfigured + ") for prompt: " + prompt);
