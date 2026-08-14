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

/**
 * Helper function to check if a variable exists.
 * It returns true if the variable is not undefined, not null, and not an empty string.
 */
function exists(value) {
    return typeof value !== 'undefined' && value !== null && value !== '';
}

/**
 * Extracts and normalizes the AI model name from either a GCP Vertex AI URL 
 * or a request payload JSON string.
 * 
 * @param {string} urlString - The Vertex AI API request URL.
 * @param {string} contentString - The stringified JSON payload of the request.
 * @returns {string} The extracted model name, or "unknown" if not found.
 */
function getModelName(urlString, contentString) {
  var modelName = "unknown";

  // 1. Check if the URL is valid and matches GCP Vertex AI publisher endpoints
  if (urlString) {
    // Matches and captures the model name segment after the publisher folder and before any action colon
    var match = urlString.match(/\/publishers\/(google|anthropic)\/models\/([^:]+)/);
    if (match && match.length > 2) {
      return match[2];
    }
  }

  // 2. Fallback: Parse the request body if present
  if (contentString) {
    try {
      var contentData = JSON.parse(contentString);
      if (contentData && contentData.model) {
        modelName = contentData.model;
        
        // Extract the last segment if the model name is a full resource path
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
    var reqBody = JSON.parse(context.getVariable("request.content"));
    var prompt = reqBody.prompt || "";
    // model
    var headerModel =  context.getVariable("llm_model");
    // default model
    var defaultModel = context.getVariable("llm_default_model");
    
    // Support OpenAI /chat/completions payload structure
    if (!prompt && reqBody.messages && Array.isArray(reqBody.messages)) {
        var lastUserMessage = "";
        for (var i = reqBody.messages.length - 1; i >= 0; i--) {
            if (reqBody.messages[i].role === 'user') {
                lastUserMessage = reqBody.messages[i].content || "";
                break;
            }
        }
        prompt = lastUserMessage;
    }
    
    // Support native Vertex AI payload structure
    if (!prompt && reqBody.contents && Array.isArray(reqBody.contents)) {
        var lastUserText = "";
        for (var j = reqBody.contents.length - 1; j >= 0; j--) {
            if (reqBody.contents[j].role === 'user' && reqBody.contents[j].parts && reqBody.contents[j].parts.length > 0) {
                lastUserText = reqBody.contents[j].parts[0].text || "";
                break;
            }
        }
        prompt = lastUserText;
    }
    
    // Ensure prompt is at least a string to avoid evaluation errors in Model Armor
    if (!prompt) {
        prompt = " "; // Model Armor errors if prompt is strictly empty string depending on evaluation
    }
    
    // Get model from the payload
    var bodyOrUriModel = getModelName(context.getVariable("proxy.pathsuffix"),context.getVariable("request.content")) || defaultModel;

    // Simplified assignment
    // How model is set?:
    // 1. from header (x-llm-model)
    // 2. from body
    // 3. default value (properties: default_model)
    if (exists(headerModel) && headerModel !== defaultModel) {
        model = headerModel;
    } else if (exists(bodyOrUriModel)) {
        model = bodyOrUriModel;
    } else {
        model = defaultModel;
    }

    // is cache enabled
    var cache_enabled = context.getVariable("llm_cache_enabled");
    // Disable semantic cache for multi-turn conversations or tool calls, as the last user message alone is an incomplete cache key
    if ((reqBody.messages && reqBody.messages.length > 4) || (reqBody.contents && reqBody.contents.length > 3)) {
        cache_enabled = "false";
    }
    
    context.setVariable("request_prompt", prompt);
    context.setVariable("model", model);
    context.setVariable("cache_enabled", cache_enabled);
} catch(e) {
    context.setVariable("request_parse_error", e.message);
}
