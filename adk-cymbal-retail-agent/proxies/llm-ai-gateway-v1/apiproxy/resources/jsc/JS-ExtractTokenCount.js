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
    var responseContent = context.getVariable("response.content");
    var promptTokens = 0;
    var candidatesTokens = 0;
    var totalTokens = 0;
    var timeToFirstToken = 0;
    var model = context.getVariable("model");
    var type = "non-streaming";
    var costCenter = "unknown";

    if (responseContent) {
        // Get time to first token
        var request_start_time = context.getVariable('client.received.start.timestamp');
        var timeNow = Date.now();
        timeToFirstToken = timeNow - request_start_time;

        var responseObj = JSON.parse(responseContent);
        if (responseObj) {
            if (responseObj.usageMetadata) {
                promptTokens = responseObj.usageMetadata.promptTokenCount || 0;
                candidatesTokens = responseObj.usageMetadata.candidatesTokenCount || 0;
                totalTokens = responseObj.usageMetadata.totalTokenCount || 0;
            }
            // Inject routed model name into the response body JSON so it persists in semantic cache
            responseObj.routedModel = context.getVariable("model");
            context.setVariable("response.content", JSON.stringify(responseObj));
        }
        // Get cost center from client application
        costCenter = context.getVariable("verifyapikey.VA-VerifyAPIKey.COST_CENTER");
        if (!costCenter) {
          costCenter = "unknown";
        }
    }

    context.setVariable("prompt_token_count", promptTokens.toString());
    context.setVariable("candidates_token_count", candidatesTokens.toString());
    context.setVariable("total_token_count", totalTokens.toString());
    context.setVariable("time_to_first_token", timeToFirstToken.toString());
    context.setVariable("response_type", type);
    context.setVariable("cost_center", costCenter);

    // Set headers
    context.setVariable("message.header.X-LLM-Model-Selected", model);
    
    var semanticMatchId = context.getVariable("semantic_match_id");
    if (semanticMatchId) {
        context.setVariable("message.header.X-Semantic-Match-ID", semanticMatchId);
    }
    
    var semanticMatchDistance = context.getVariable("semantic_match_distance");
    if (semanticMatchDistance) {
        context.setVariable("message.header.X-Semantic-Match-Distance", semanticMatchDistance);
    }
    
    var semanticRoutingError = context.getVariable("semantic_routing_error");
    if (semanticRoutingError) {
        context.setVariable("message.header.X-Semantic-Routing-Error", semanticRoutingError);
    }

} catch (e) {
    // Default to 0 on error to prevent policy failure
    context.setVariable("prompt_token_count", "0");
    context.setVariable("candidates_token_count", "0");
    context.setVariable("total_token_count", "0");
    context.setVariable("time_to_first_token", "0");
    context.setVariable("response_type", "non-streaming");
    context.setVariable("cost_center", "unknown");
    context.setVariable("extract_token_count_error", e.message);
}
