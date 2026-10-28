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

    // Preserve original Vertex AI payload for lossless failover (tools, systemInstruction, functionCall/functionResponse)
    if (reqBody.contents && Array.isArray(reqBody.contents)) {
        context.setVariable("original_vertex_request", rawContent);
    }

    var prompt = reqBody.prompt || "";

    // Support OpenAI /chat/completions payload structure (scan backwards across all user messages & parts)
    if (!prompt && reqBody.messages && Array.isArray(reqBody.messages)) {
        for (var i = reqBody.messages.length - 1; i >= 0 && !prompt; i--) {
            var msg = reqBody.messages[i];
            if (msg && msg.role === 'user' && msg.content) {
                if (typeof msg.content === 'string' && msg.content.replace(/^\s+|\s+$/g, '') !== '') {
                    prompt = msg.content;
                    break;
                } else if (Array.isArray(msg.content)) {
                    for (var mIdx = msg.content.length - 1; mIdx >= 0; mIdx--) {
                        var mPart = msg.content[mIdx];
                        if (mPart && typeof mPart.text === 'string' && mPart.text.replace(/^\s+|\s+$/g, '') !== '') {
                            prompt = mPart.text;
                            break;
                        }
                    }
                }
            }
        }
    }

    // Support native Vertex AI payload structure (scan backwards across all user messages & parts, skipping functionResponse)
    if (!prompt && reqBody.contents && Array.isArray(reqBody.contents)) {
        for (var j = reqBody.contents.length - 1; j >= 0 && !prompt; j--) {
            var cTurn = reqBody.contents[j];
            if (cTurn && cTurn.role === 'user' && cTurn.parts && Array.isArray(cTurn.parts)) {
                for (var pIdx = cTurn.parts.length - 1; pIdx >= 0; pIdx--) {
                    var part = cTurn.parts[pIdx];
                    if (part && !part.functionResponse && typeof part.text === 'string' && part.text.replace(/^\s+|\s+$/g, '') !== '') {
                        prompt = part.text;
                        break;
                    }
                }
            }
        }
    }

    // Ensure prompt is at least a single whitespace string to avoid Model Armor evaluation errors
    if (!prompt) {
        prompt = " ";
    }

    // Detect tools / functionDeclarations / functionCall / functionResponse usage
    var hasTools = false;
    var hasToolHistory = false;
    var hasToolCallTurn = false;

    if ((reqBody.tools && Array.isArray(reqBody.tools) && reqBody.tools.length > 0) ||
        (reqBody.functionDeclarations && Array.isArray(reqBody.functionDeclarations) && reqBody.functionDeclarations.length > 0)) {
        hasTools = true;
    }

    if (reqBody.contents && Array.isArray(reqBody.contents)) {
        if (reqBody.contents.length > 1) {
            hasToolCallTurn = true;
        }
        for (var cIdx = 0; cIdx < reqBody.contents.length; cIdx++) {
            var contentItem = reqBody.contents[cIdx];
            if (contentItem && (contentItem.role === 'function' || contentItem.role === 'tool')) {
                hasTools = true;
                hasToolHistory = true;
                hasToolCallTurn = true;
            }
            if (contentItem && contentItem.parts && Array.isArray(contentItem.parts)) {
                for (var ptIdx = 0; ptIdx < contentItem.parts.length; ptIdx++) {
                    var pt = contentItem.parts[ptIdx];
                    if (pt && (pt.functionCall || pt.functionResponse)) {
                        hasTools = true;
                        hasToolHistory = true;
                        hasToolCallTurn = true;
                    }
                }
            }
        }
    }

    if (reqBody.messages && Array.isArray(reqBody.messages)) {
        for (var msgIdx = 0; msgIdx < reqBody.messages.length; msgIdx++) {
            var mItem = reqBody.messages[msgIdx];
            if (mItem && (mItem.tool_calls || mItem.role === 'tool' || mItem.role === 'function')) {
                hasTools = true;
                hasToolHistory = true;
                hasToolCallTurn = true;
            }
        }
    }

    // --------------------------------------------------------------------------
    // 2. Header Management & Redundancy Consolidation
    // --------------------------------------------------------------------------
    // Consolidate redundant headers: x-llm-model, x-model-name, x-llm-tier, and x-model-tier
    var llmModelHeader = context.getVariable("request.header.x-llm-model");
    var modelNameHeader = context.getVariable("request.header.x-model-name");
    var llmTierHeader = context.getVariable("request.header.x-llm-tier");
    var modelTierHeader = context.getVariable("request.header.x-model-tier");
    var effectiveTierHeader = exists(llmTierHeader) ? llmTierHeader : modelTierHeader;
    var defaultLocalModel = context.getVariable("llm_local_model") || context.getVariable("propertyset.vertex_config.default_local_model");

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

    var defaultModel = context.getVariable("llm_default_model") || context.getVariable("propertyset.vertex_config.default_model");

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
    var modelTierLower = effectiveTierHeader ? effectiveTierHeader.toLowerCase().replace(/^\s+|\s+$/g, '') : "";
    var explicitLocalRequested = (modelTierLower === "local" || modelTierLower === "gemma");

    // Criterion A: Explicit header request for local Gemma tier or Gemma model name
    if (explicitLocalRequested || headerModelLower.indexOf("gemma") !== -1) {
        routeToGemma = true;
    }
    // Criterion B: Explicit body or URI request for Gemma model name
    else if (bodyOrUriModel && bodyOrUriModel.toLowerCase().indexOf("gemma") !== -1) {
        routeToGemma = true;
    }

    // Keep tool-bearing agent requests on the tool-capable Vertex Gemini target
    // unless x-llm-tier: local (or x-model-tier: local) is explicitly requested
    var explicitRoutingHeader = context.getVariable("request.header.x-llm-routing");
    var explicitRoutingRequested = exists(explicitRoutingHeader) && explicitRoutingHeader.toLowerCase().replace(/^\s+|\s+$/g, '') === "true";
    if (hasTools && !explicitLocalRequested) {
        routeToGemma = false;
        if (hasToolHistory || !explicitRoutingRequested) {
            context.setVariable("llm_routing_enabled", "false");
        }
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

    // Disable semantic cache for multi-turn conversations or tool-call turns
    if (hasToolCallTurn || (reqBody.messages && reqBody.messages.length > 4) || (reqBody.contents && reqBody.contents.length > 1)) {
        cache_enabled = "false";
    }

    // --------------------------------------------------------------------------
    // 6. Set Flow Variables
    // --------------------------------------------------------------------------
    context.setVariable("request_prompt", prompt);
    context.setVariable("model", model);
    context.setVariable("route_to_gemma", routeToGemma ? "true" : "false");
    context.setVariable("has_tools", hasTools ? "true" : "false");
    context.setVariable("cache_enabled", cache_enabled);

    print("Model Routing Decision: model=" + model + ", route_to_gemma=" + routeToGemma);

} catch (e) {
    context.setVariable("request_parse_error", e.message);
}