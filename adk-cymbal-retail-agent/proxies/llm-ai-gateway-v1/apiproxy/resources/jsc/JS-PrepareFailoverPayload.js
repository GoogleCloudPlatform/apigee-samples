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
// Apigee X - Failover Request Payload Preparation
// Converts request payload to Vertex AI generateContent schema
// ====================================================
(function () {
    try {
        var rawPayload = context.getVariable("request.content") || request.content;
        var failoverModel = context.getVariable("llm_default_fallback_model") || "gemini-2.5-flash";
        var currentModel = context.getVariable("model") || "";

        var payloadObj = null;
        try {
            payloadObj = (typeof rawPayload === "object") ? rawPayload : JSON.parse(rawPayload);
        } catch (e) {
            payloadObj = null;
        }

        var payloadString = "";
        if (payloadObj && payloadObj.messages && Array.isArray(payloadObj.messages)) {
            var vertexContents = [];
            var systemInstruction = null;

            payloadObj.messages.forEach(function(m) {
                if (m.role === "system") {
                    systemInstruction = { "parts": [{"text": m.content || ""}] };
                } else {
                    var role = (m.role === "assistant") ? "model" : "user";
                    vertexContents.push({
                        "role": role,
                        "parts": [{"text": m.content || ""}]
                    });
                }
            });

            if (vertexContents.length === 0) {
                var sysText = systemInstruction && systemInstruction.parts && systemInstruction.parts[0] ? systemInstruction.parts[0].text : " ";
                vertexContents.push({
                    "role": "user",
                    "parts": [{"text": sysText}]
                });
            }

            var vertexPayload = {
                "contents": vertexContents,
                "generationConfig": {
                    "maxOutputTokens": payloadObj.max_tokens || payloadObj.max_completion_tokens || 8192,
                    "temperature": payloadObj.temperature || 0.7
                }
            };

            if (systemInstruction) {
                vertexPayload.systemInstruction = systemInstruction;
            }

            payloadString = JSON.stringify(vertexPayload);
        } else {
            payloadString = (typeof rawPayload === "object") ? JSON.stringify(rawPayload) : String(rawPayload);
            if (currentModel && currentModel.length > 0) {
                payloadString = payloadString.split(currentModel).join(failoverModel);
            }
        }

        context.setVariable("failover_payload", payloadString);
        context.setVariable("failover.prepared", "true");

    } catch (err) {
        print("Exception in JS-PrepareFailoverPayload: " + err.message);
        context.setVariable("failover.prepared", "false");
        context.setVariable("failover.error", err.message);
    }
})();
