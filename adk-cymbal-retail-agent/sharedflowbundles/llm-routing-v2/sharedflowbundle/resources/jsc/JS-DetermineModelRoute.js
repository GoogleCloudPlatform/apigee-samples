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

try {
    var keywordDecision = context.getVariable("keyword_routing_decision");
    var defaultModel = context.getVariable("llm_model"); // Default model (e.g. gemini-2.5-pro)
    var model = context.getVariable("model") || defaultModel;
    var fallbackModel = context.getVariable("llm_fallback_model"); // Fallback model (e.g. gemini-2.5-flash)
    var matchedDatapointId = "";
    var distance = 0.0;
    var routeToGemma = false;

    // 1. Process KVM Keyword Decision ("gemma", "simple", "complex")
    if (keywordDecision) {
        var decisionLower = keywordDecision.toLowerCase();
        if (decisionLower === "gemma") {
            model = fallbackModel;
            routeToGemma = true;
        } else if (decisionLower === "simple") {
            model = fallbackModel;
        } else if (decisionLower === "complex") {
            model = defaultModel;
        }
        matchedDatapointId = "kvm_override_" + decisionLower;
        distance = 1.0;
    } else {
        // 2. Process Vector Search Nearest Neighbor Results
        var responseStr = context.getVariable("vectorSearchResponse.content");
        var responseObj = null;
        if (responseStr) {
            try {
                responseObj = JSON.parse(responseStr);
            } catch(e) {
                // Fail silently if JSON parse fails
            }
        }
        
        if (responseObj && responseObj.nearestNeighbors && responseObj.nearestNeighbors.length > 0) {
            var neighbors = responseObj.nearestNeighbors[0].neighbors;
            if (neighbors && neighbors.length > 0) {
                var nearestNeighbor = neighbors[0];

                context.setVariable("nearestNeighbor", JSON.stringify(nearestNeighbor));
                matchedDatapointId = nearestNeighbor.datapoint.datapointId;
                distance = nearestNeighbor.distance;
                
                var matchedIdLower = matchedDatapointId.toLowerCase();

                // Check datapoint ID classification: "gemma_", "simple_", or "complex_"
                if (matchedIdLower.indexOf("gemma") >= 0) {
                    model = fallbackModel;
                    routeToGemma = true;
                } else if (matchedIdLower.indexOf("simple") >= 0) {
                    model = fallbackModel;
                } else if (matchedIdLower.indexOf("complex") >= 0) {
                    model = defaultModel;
                }
            }
        }
        
        // 3. Fallback Testing / Mock Rule from Request Prompt
        var userPrompt = context.getVariable("request_prompt") || "";
        if (model === defaultModel) {
            var lowerPrompt = userPrompt.toLowerCase();
            if (lowerPrompt.indexOf("gemma") >= 0) {
                model = fallbackModel;
                routeToGemma = true;
                matchedDatapointId = "mock_gemma_query_from_prompt_rules";
                distance = 0.99;
            } else if (lowerPrompt.indexOf("simple") >= 0 || 
                       lowerPrompt.indexOf("french") >= 0 || 
                       lowerPrompt.indexOf("hello") >= 0) {
                model = fallbackModel;
                matchedDatapointId = "mock_simple_query_from_prompt_rules";
                distance = 0.99;
            }
        }
    }
    
    context.setVariable("model", model);
    context.setVariable("route_to_gemma", routeToGemma ? "true" : "false");
    context.setVariable("semantic_match_id", matchedDatapointId);
    context.setVariable("semantic_match_distance", distance.toString());
    
    print("Semantic Router Decision: model=" + model + ", route_to_gemma=" + routeToGemma + ", match_id=" + matchedDatapointId);

} catch (e) {
    context.setVariable("model", defaultModel); // Safe fallback
    context.setVariable("semantic_routing_error", e.message);
}
