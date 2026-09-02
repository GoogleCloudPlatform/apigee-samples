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
// Hybrid AI Gateway Unified Request Parser & Dynamic Router
// Evaluates incoming request body, path suffix, and headers to:
//  1. Extract user prompt across OpenAI and Vertex AI payload formats
//  2. Resolve and consolidate header-based model overrides (x-llm-model vs x-model-name)
//  3. Perform priority routing to private local Gemma model if explicitly requested
//  4. Manage semantic cache enablement for multi-turn conversations
// ==============================================================================

/**
 * Helper function to check if a variable exists.
 * Returns true if the value is not undefined, null, or empty string.
 * @param {*} value
 * @returns {boolean}
 */
function exists(value) {
    return typeof value !== 'undefined' && value !== null && value !== '';
}

/**
 * Extracts and normalizes the AI model name from either a GCP Vertex AI URL 
 * or a request payload JSON string.
 * 
 * @param {string} urlString - The Vertex AI API request URL / proxy path suffix.
 * @param {string} contentString - The stringified JSON payload of the request.
 * @returns {string} The extracted model name, or "unknown" if not found.
 */
function getModelName(urlString, contentString) {
    var modelName = "unknown";

    // 1. Check if the URL matches GCP Vertex AI publisher endpoints
    if (urlString) {
        var match = urlString.match(/\/publishers\/(google|anthropic)\/models\/([^:]+)/);
        if (match && match.length > 2) {
            return match[2];
        }
    }

    // 2. Fallback: Parse the request body model field if present
    if (contentString) {
        try {
            var contentData = JSON.parse(contentString);
            if (contentData && contentData.model) {
                modelName = contentData.model;
                if (modelName.indexOf("/") !== -1) {
                    var modelNamePieces = modelName.split("/");
                    modelName = modelNamePieces[modelNamePieces.length - 1];
                }
            }
        } catch (e) {
            // Fail silently and keep "unknown" if JSON parsing fails
        }
    }

    return modelName;
}

try {
    // --------------------------------------------------------------------------
    // 1. Parse Request Body & Extract Prompt
    // --------------------------------------------------------------------------
    var rawContent = context.getVariable("request.content") || "{}";
    var reqBody = {};
    try {
        reqBody = JSON.parse(rawContent);
    } catch (parseErr) {
        reqBody = {};
    }

    // Detect inbound client request protocol (OpenAI vs native Vertex AI)
    var pathSuffix = context.getVariable("proxy.pathsuffix") || "";
    if (reqBody.messages || pathSuffix.indexOf("/chat") !== -1) {
        context.setVariable("request_protocol", "openai");
    } else {
        context.setVariable("request_protocol", "vertex");
    }

    var prompt = reqBody.prompt || "";

    // Support OpenAI /chat/completions payload structure
    if (!prompt && reqBody.messages && Array.isArray(reqBody.messages)) {
        for (var i = reqBody.messages.length - 1; i >= 0; i--) {
            if (reqBody.messages[i] && reqBody.messages[i].role === 'user') {
                prompt = reqBody.messages[i].content || "";
                break;
            }
        }
    }

    // Support native Vertex AI payload structure
    if (!prompt && reqBody.contents && Array.isArray(reqBody.contents)) {
        for (var j = reqBody.contents.length - 1; j >= 0; j--) {
            if (reqBody.contents[j] && reqBody.contents[j].role === 'user' && reqBody.contents[j].parts && reqBody.contents[j].parts.length > 0) {
                prompt = reqBody.contents[j].parts[0].text || "";
                break;
            }
        }
    }

    // Ensure prompt is at least a single whitespace string to avoid Model Armor evaluation errors
    if (!prompt) {
        prompt = " ";
    }

    // --------------------------------------------------------------------------
    // 2. Header Management & Redundancy Consolidation
    // --------------------------------------------------------------------------
    // Consolidate redundant headers: x-llm-model, x-model-name, and x-model-tier
    var llmModelHeader = context.getVariable("request.header.x-llm-model");
    var modelNameHeader = context.getVariable("request.header.x-model-name");
    var modelTierHeader = context.getVariable("request.header.x-model-tier");
    var defaultLocalModel = context.getVariable("llm_local_model");

    // Order of precedence for explicit header model selection:
    // 1. x-llm-model header
    // 2. x-model-name header
    // 3. llm_model context variable (populated by JS-ProcessCustomLLMHeaders)
    var headerModel = "";
    if (exists(llmModelHeader)) {
        headerModel = llmModelHeader;
    } else if (exists(modelNameHeader)) {
        headerModel = modelNameHeader;
    } else if (exists(context.getVariable("llm_model"))) {
        headerModel = context.getVariable("llm_model");
    }

    var defaultModel = context.getVariable("llm_default_model") || "gemini-2.5-flash";

    // Extract model from URL path suffix or payload JSON
    var bodyOrUriModel = getModelName(context.getVariable("proxy.pathsuffix"), rawContent);
    if (bodyOrUriModel === "unknown") {
        bodyOrUriModel = "";
    }

    // --------------------------------------------------------------------------
    // 3. Gemma Priority Routing Evaluation (Explicit Requests Only)
    // Note: Semantic / Intelligent prompt classification is offloaded to FC-LLMRouting
    // --------------------------------------------------------------------------
    var routeToGemma = false;
    var headerModelLower = headerModel.toLowerCase();
    var modelTierLower = modelTierHeader ? modelTierHeader.toLowerCase() : "";

    // Criterion A: Explicit header request for local Gemma tier or Gemma model name
    if (modelTierLower === "local" || modelTierLower === "gemma" || headerModelLower.indexOf("gemma") !== -1) {
        routeToGemma = true;
    }
    // Criterion B: Explicit body or URI request for Gemma model name
    else if (bodyOrUriModel && bodyOrUriModel.toLowerCase().indexOf("gemma") !== -1) {
        routeToGemma = true;
    }

    // --------------------------------------------------------------------------
    // 4. Resolve Final Model Assignment
    // --------------------------------------------------------------------------
    var model = "";
    if (routeToGemma) {
        // Preserve specific Gemma model name if passed in header/body; fallback to default Gemma model
        if (headerModelLower.indexOf("gemma") !== -1) {
            model = headerModel;
        } else if (bodyOrUriModel && bodyOrUriModel.toLowerCase().indexOf("gemma") !== -1) {
            model = bodyOrUriModel;
        } else {
            model = defaultLocalModel;
        }
    } else {
        // Standard model determination priority for Vertex AI:
        // 1. Explicit Header Model (if present and not default)
        // 2. Extracted Body / URI Model
        // 3. Default Model from propertyset
        if (exists(headerModel) && headerModel !== defaultModel) {
            model = headerModel;
        } else if (exists(bodyOrUriModel)) {
            model = bodyOrUriModel;
        } else {
            model = defaultModel;
        }
    }

    // --------------------------------------------------------------------------
    // 5. Semantic Cache Management
    // --------------------------------------------------------------------------
    var cache_enabled = context.getVariable("llm_cache_enabled");
    if (!exists(cache_enabled)) {
        cache_enabled = "true";
    }

    // Disable semantic cache for multi-turn conversations or tool calls
    if ((reqBody.messages && reqBody.messages.length > 4) || (reqBody.contents && reqBody.contents.length > 3)) {
        cache_enabled = "false";
    }

    // --------------------------------------------------------------------------
    // 6. Set Flow Variables
    // --------------------------------------------------------------------------
    context.setVariable("request_prompt", prompt);
    context.setVariable("model", model);
    context.setVariable("route_to_gemma", routeToGemma ? "true" : "false");
    context.setVariable("cache_enabled", cache_enabled);

    print("Model Routing Decision: model=" + model + ", route_to_gemma=" + routeToGemma);

} catch (e) {
    context.setVariable("request_parse_error", e.message);
}