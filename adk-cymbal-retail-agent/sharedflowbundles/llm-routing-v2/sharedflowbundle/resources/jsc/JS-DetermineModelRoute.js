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
    var defaultModel = context.getVariable("llm_model"); // Default model
    var model = context.getVariable("model");
    var fallbackModel = context.getVariable("llm_fallback_model"); // Fallback model
    var matchedDatapointId = "";
    var distance = 0.0;

    if (keywordDecision) {
        if (keywordDecision === "simple") {
            model = fallbackModel;
        }
        matchedDatapointId = "kvm_override_" + keywordDecision;
        distance = 1.0;
    } else {
        var responseStr = context.getVariable("vectorSearchResponse.content");
        var responseObj = null;
        if (responseStr) {
            try {
                responseObj = JSON.parse(responseStr);
            } catch(e) {
                // Ignore parse error
            }
        }
        
        // Process Vector Search results
        if (responseObj && responseObj.nearestNeighbors && responseObj.nearestNeighbors.length > 0) {
            var neighbors = responseObj.nearestNeighbors[0].neighbors;
            if (neighbors && neighbors.length > 0) {
                var nearestNeighbor = neighbors[0];

                context.setVariable("nearestNeighbor", JSON.stringify(nearestNeighbor));
                matchedDatapointId = nearestNeighbor.datapoint.datapointId;
                distance = nearestNeighbor.distance;
                
                if (matchedDatapointId.indexOf("simple") >= 0) {
                    model = fallbackModel;
                }
            }
        }
        
        // Mock / Testing Rule as fallback
        var userPrompt = context.getVariable("request_prompt") || "";
        if (model === defaultModel) {
            var lowerPrompt = userPrompt.toLowerCase();
            if (lowerPrompt.indexOf("simple") >= 0 || 
                lowerPrompt.indexOf("french") >= 0 || 
                lowerPrompt.indexOf("hello") >= 0) {
                model = fallbackModel;
                matchedDatapointId = "mock_simple_query_from_prompt_rules";
                distance = 0.99;
            }
        }
    }
    
    context.setVariable("model", model);
    context.setVariable("semantic_match_id", matchedDatapointId);
    context.setVariable("semantic_match_distance", distance.toString());
    
} catch (e) {
    context.setVariable("model", defaultModel); // Safe fallback
    context.setVariable("semantic_routing_error", e.message);
}
