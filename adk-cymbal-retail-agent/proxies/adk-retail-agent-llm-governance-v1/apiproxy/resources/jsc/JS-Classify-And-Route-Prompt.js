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
// Hybrid AI Gateway Dynamic Routing Classifier
// Evaluates incoming prompts to determine whether to route to:
//  - Private Local Gemma 3 (4B) on Cloud Run CPU (Simple queries / FAQs / Mocks)
//  - Managed Frontier Gemini 2.5 Flash on Vertex AI (Complex multi-agent reasoning)
// ==============================================================================

var modelTierHeader = context.getVariable("request.header.x-model-tier");
var modelNameHeader = context.getVariable("request.header.x-model-name");
var prompt = context.getVariable("prompt_contents_0") || "";

// Read configured Gemma endpoint URL from Apigee propertyset
var gemmaUrl = context.getVariable("propertyset.gemma_config.gemma_url") || "";
var isGemmaConfigured = gemmaUrl.length > 0 && 
                        gemmaUrl.indexOf("gemma-cpu-router-run.app") === -1 && 
                        gemmaUrl.indexOf("gemma-2-9b-private-router.run.app") === -1;
var routeToGemma = false;

// 1. Explicit Header Override Check (Client-directed routing)
if (modelTierHeader && (modelTierHeader.toLowerCase() === "local" || modelTierHeader.toLowerCase() === "gemma")) {
  routeToGemma = true;
} else if (modelNameHeader && modelNameHeader.toLowerCase().indexOf("gemma") !== -1) {
  routeToGemma = true;
} else if (isGemmaConfigured) {
  // 2. Intelligent Prompt Complexity Classifier (Active when Gemma endpoint is provisioned)
  var trimmedPrompt = prompt.trim().toLowerCase();
  var wordCount = trimmedPrompt.split(/\s+/).length;
  
  // Simple greetings, single-intent inquiries, or FAQ phrases routed to local Gemma
  var gemmaRetailPatterns = [
    /^hello[\s!.]*$/i,
    /^hi[\s!.]*$/i,
    /^hey[\s!.]*$/i,
    /^how are you[\s?!.]*$/i,
    /^what can you do[\s?!.]*$/i,
    /^help[\s!.]*$/i,
    /^good (morning|afternoon|evening)[\s!.]*$/i,
    /store hours|operating hours|opening hours|when are you open/i,
    /return policy|refund policy|exchange policy|how do i return/i,
    /shipping (rates|options|policy|cost|fee|methods|time)/i,
    /loyalty (points|rewards|program|tier)/i,
    /store locations|store address|where are you located/i,
    /contact customer service|support email|support phone/i,
    /cancel order policy|cancellation policy/i
  ];
  
  var isPatternMatch = gemmaRetailPatterns.some(function(pattern) {
    return pattern.test(trimmedPrompt);
  });
  
  if (isPatternMatch || (wordCount <= 4 && trimmedPrompt.indexOf("transfer_to_agent") === -1 && trimmedPrompt.indexOf("createorder") === -1)) {
    routeToGemma = true;
  }
}

context.setVariable("route_to_gemma", routeToGemma ? "true" : "false");
print("Gemma Model Routing Decision: route_to_gemma=" + routeToGemma + " (isGemmaConfigured=" + isGemmaConfigured + ") for prompt: " + prompt);

