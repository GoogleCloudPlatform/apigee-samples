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
// Apigee X - Failover Response Processing & Formatting
// Formats the response from ServiceCallout (SC-VertexFailover) for the client
// ====================================================
(function () {
    try {
        var failoverResponseContent = context.getVariable("failoverResponse.content");
        var failoverResponseStatus = context.getVariable("failoverResponse.status.code") || "503";
        var failoverModel = context.getVariable("llm_default_fallback_model") || "gemini-2.5-flash";

        function toCleanIntString(val, fallback) {
            if (val === null || val === undefined) return String(fallback);
            var intPart = String(val).split(".")[0];
            var parsed = parseInt(intPart, 10);
            if (isNaN(parsed)) return String(fallback);
            return String(parsed);
        }

        var cleanStatusCode = toCleanIntString(failoverResponseStatus, 503);
        var statusCodeNum = parseInt(cleanStatusCode, 10);

        context.setVariable("failover.executed", "true");
        context.setVariable("failover.statusCode", cleanStatusCode);
        context.setVariable("failover.model", failoverModel);

        if (statusCodeNum >= 200 && statusCodeNum < 300) {
            context.setVariable("failover.success", "true");
            context.setVariable("fallback_triggered", "true");
        } else {
            context.setVariable("failover.success", "false");
            print("Failover upstream returned error status: " + cleanStatusCode);
        }

        if (failoverResponseContent) {
            context.setVariable("response.status.code", cleanStatusCode);
            context.setVariable("response.header.Content-Type", "application/json");
            context.setVariable("response.content", failoverResponseContent);
        } else {
            context.setVariable("response.status.code", "503");
            context.setVariable("response.header.Content-Type", "application/json");
            context.setVariable("response.content", JSON.stringify({
                "error": {
                    "code": 503,
                    "message": "Failover target unreachable or returned empty response",
                    "status": "UNAVAILABLE"
                }
            }));
        }

    } catch (err) {
        print("Exception in JS-ProcessFailoverResponse: " + err.message);
        context.setVariable("failover.executed", "false");
        context.setVariable("failover.error", err.message);
    }
})();
