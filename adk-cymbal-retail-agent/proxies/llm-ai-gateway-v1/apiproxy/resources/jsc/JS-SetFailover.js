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

// ====================================================
// Apigee X - Failover / Fallback Callout to Vertex AI 
// ====================================================
(function () {
    try {
        // --- 1. Configuration & Parameters ---
        var projectId = context.getVariable("organization.name");
        var location = context.getVariable("propertyset.vertex_config.region");
        var failoverModel = context.getVariable("llm_default_fallback_model");
        var endpoint = "https://" + location + "-aiplatform.googleapis.com:443/v1/projects/" + 
                       projectId + "/locations/" + location + "/publishers/google/models/" + 
                       failoverModel + ":generateContent";
        // --- 2. Request Data Extraction ---
        var currentModel = context.getVariable("model") || "";
        var rawPayload = context.getVariable("request.content") || request.content;
        var bearerToken = context.getVariable("request.header.authorization");
        // Prepare Headers (Vertex AI requires Content-Type: application/json)
        var headers = {
            "Content-Type": "application/json"
        };
        if (bearerToken) {
            headers["Authorization"] = bearerToken;
        }
        // Prepare and adapt Payload
        var payloadString = (typeof rawPayload === "object") ? JSON.stringify(rawPayload) : String(rawPayload);
        if (currentModel && currentModel.length > 0) {
            payloadString = payloadString.split(currentModel).join(failoverModel);
        }
        // --- 3. Strict Integer String Extraction (Guarantees no ".0" for Java Integer.parseInt) ---
        function toCleanIntString(val, fallback) {
            if (val === null || val === undefined) return String(fallback);
            // Splits "200.0" or 200.0 at the dot and keeps only the integer part "200"
            var intPart = String(val).split(".")[0];
            var parsed = parseInt(intPart, 10);
            if (isNaN(parsed)) return String(fallback);
            return String(parsed);
        }
        // --- 4. Build Apigee Request ---
        var fallbackRequest = new Request(endpoint, "POST", headers, payloadString);
        // --- 5. Completion Callback with Enhanced Response & Error Handling ---
        function onComplete(response, error) {
            // Scenario A: Network / Transport Error (Timeout, DNS, Connection reset)
            if (error) {
                var errStatusStr = toCleanIntString(error.status, 503);
                print("Failover Transport Error: " + (error.message || error));
                context.setVariable("failover.executed", "true");
                context.setVariable("failover.success", "false");
                context.setVariable("failover.error", String(error.message || error));
                context.setVariable("response.status.code", errStatusStr);
                context.setVariable("response.reason.phrase", "Service Unavailable");
                context.setVariable("response.header.Content-Type", "application/json");
                context.setVariable("response.content", JSON.stringify({
                    "error": {
                        "code": 503,
                        "message": "Failover target unreachable: " + (error.message || "Transport error"),
                        "status": "UNAVAILABLE"
                    }
                }));
                return;
            }
            // Scenario B: HTTP Response Received
            if (response) {
                // Extracts strictly "200" (never "200.0")
                var cleanStatusStr = toCleanIntString(response.status, 200);
                var statusCodeNum = parseInt(cleanStatusStr, 10);
                var responseContent = response.content;
                context.setVariable("failover.executed", "true");
                context.setVariable("failover.statusCode", cleanStatusStr);
                context.setVariable("failover.model", failoverModel);
                // Evaluate HTTP status range
                if (statusCodeNum >= 200 && statusCodeNum < 300) {
                    context.setVariable("failover.success", "true");
                } else {
                    context.setVariable("failover.success", "false");
                    print("Failover upstream error with HTTP status: " + cleanStatusStr);
                }
                // Propagate response code (Apigee Integer.parseInt safe) and content
                context.setVariable("response.status.code", cleanStatusStr);
                context.setVariable("response.header.Content-Type", "application/json");
                context.setVariable("response.content", responseContent);
            }
        }
        // --- 6. Execute Asynchronous Call ---
        httpClient.send(fallbackRequest, onComplete);
    } catch (err) {
        print("Exception in Failover JS Policy: " + err.message);
        context.setVariable("failover.executed", "false");
        context.setVariable("failover.error", err.message);
    }
})();