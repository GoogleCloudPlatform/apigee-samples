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

(function () {
    /**
     * Retrieves a boolean header as a String ("true" or "false") with a fallback default value.
     * @param {string} headerName - The name of the header to fetch.
     * @param {string} defaultValue - The default string value if header is absent ("true" or "false").
     * @returns {string}
     */
    function getBooleanStringHeader(headerName, defaultValue) {
        var headerValue = context.getVariable("request.header." + headerName);
        
        // If header is missing or empty, return default
        if (headerValue === null || headerValue === undefined || headerValue === "") {
            return defaultValue;
        }
        
        // Sanitize string (lowercase and trim whitespace for ES5 compatibility)
        headerValue = headerValue.toLowerCase().replace(/^\s+|\s+$/g, '');
        
        // Any value other than "true" is treated as "false"
        return headerValue === "true" ? "true" : "false";
    }

    /**
     * Retrieves a string header with a Property Set fallback.
     * @param {string} headerName - The name of the header to fetch.
     * @param {string} propertyKey - The key in vertex_config.properties.
     * @returns {string}
     */
    function getModelHeader(headerName, propertyKey) {
        var headerValue = context.getVariable("request.header." + headerName);
        
        // If header is present and not empty, use it
        if (headerValue !== null && headerValue !== undefined && headerValue !== "") {
            return headerValue;
        }
        
        // Fallback to Property Set: propertyset.vertex_config.KEY
        var fallbackValue = context.getVariable("propertyset.vertex_config." + propertyKey);
        return fallbackValue ? fallbackValue : "";
    }

    // 1. Process Boolean Headers (Defaulting to the String "true")
    var isCacheEnabled = getBooleanStringHeader("x-llm-cache", "true");
    var isSanitizeUserPrompt = getBooleanStringHeader("x-llm-sanitize-user-prompt", "true");
    var isRoutingEnabled = getBooleanStringHeader("x-llm-routing", "true");
    var isTokenQuotaEnforce = getBooleanStringHeader("x-llm-token-quota-enforce", "true");
    var isSanitizeModelResponse = getBooleanStringHeader("x-llm-sanitize-model-response", "true");
    var isPromptRateLimiting = getBooleanStringHeader("x-llm-prompt-rate-limiting", "true");

    // 2. Process Model Headers (With PropertySet fallback)
    var llmModel = getModelHeader("x-llm-model", "default_model");
    var fallbackModel = getModelHeader("x-llm-fallback-model", "default_fallback_model");

    // 3. Set Apigee Flow Variables (All stored as Strings)
    context.setVariable("llm_cache_enabled", isCacheEnabled);
    context.setVariable("llm_sanitize_user_prompt", isSanitizeUserPrompt);
    context.setVariable("llm_routing_enabled", isRoutingEnabled);
    context.setVariable("llm_token_quota_enforce", isTokenQuotaEnforce);
    context.setVariable("llm_sanitize_model_response", isSanitizeModelResponse);
    context.setVariable("llm_prompt_rate_limiting", isPromptRateLimiting);
    
    // 4. model + default and fallback + default model
    context.setVariable("llm_model", llmModel);
    context.setVariable("llm_local_model", context.getVariable("propertyset.vertex_config.default_local_model"));
    context.setVariable("llm_default_model", context.getVariable("propertyset.vertex_config.default_model"));
    context.setVariable("llm_fallback_model", fallbackModel);
    context.setVariable("llm_default_fallback_model", context.getVariable("propertyset.vertex_config.default_fallback_model"));

})();
