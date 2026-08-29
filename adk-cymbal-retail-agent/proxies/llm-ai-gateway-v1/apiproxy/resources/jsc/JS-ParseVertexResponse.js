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
 * JS-ParseVertexResponse.js
 * 
 * Normalizes downstream LLM provider responses into standard OpenAI Chat Completion format.
 * - Converts Vertex AI Gemini candidate responses into OpenAI format.
 * - Strips internal properties (e.g. 'routedModel') from non-Vertex AI responses (such as Ollama/OpenAI native payloads).
 * - Recalculates response Content-Length header.
 */

try {
    // Retrieve raw response content and context variables
    var rawBody = context.getVariable("response.content");
    var resBody = JSON.parse(rawBody);
    var defaultModel = context.getVariable("llm_default_model");
    var fallbackModel = context.getVariable("llm_fallback_model");

    // Case 1: Vertex AI payload (contains 'candidates' array) -> Translate to OpenAI chat completion format
    if (resBody.candidates && Array.isArray(resBody.candidates)) {
        var choices = [];

        // Iterate over candidates returned by Vertex AI
        for (var i = 0; i < resBody.candidates.length; i++) {
            var candidate = resBody.candidates[i];
            
            var message = {
                "role": "assistant",
                "content": null
            };
            
            var tool_calls = [];
            var textContent = "";
            var finishReason = "stop";

            // Extract text parts and function/tool calls from candidate parts
            if (candidate.content && candidate.content.parts) {
                for (var j = 0; j < candidate.content.parts.length; j++) {
                    var part = candidate.content.parts[j];
                    if (part.text) {
                        textContent += part.text;
                    } 
                    if (part.functionCall) {
                        tool_calls.push({
                            "id": "call_" + part.functionCall.name + "_" + j,
                            "type": "function",
                            "function": {
                                "name": part.functionCall.name,
                                "arguments": JSON.stringify(part.functionCall.args || {})
                            }
                        });
                    }
                }
                
                if (textContent) {
                    // Prepend notice if automatic fallback/downgrade was triggered
                    if (context.getVariable("fallback_triggered") === "true") {
                        message.content = "⚠️ *[SYSTEM NOTICE: Downgraded to " + fallbackModel +" because your Pro token quota was exceeded]*\n\n" + textContent;
                    } else {
                        message.content = textContent;
                    }
                }
                if (tool_calls.length > 0) {
                    message.tool_calls = tool_calls;
                }
            }

            // Map Vertex AI finish reasons to OpenAI format
            if (candidate.finishReason) {
                if (tool_calls.length > 0) {
                    finishReason = "tool_calls";
                } else if (candidate.finishReason === "STOP") {
                    finishReason = "stop";
                } else if (candidate.finishReason === "MAX_TOKENS") {
                    finishReason = "length";
                }
            } else if (tool_calls.length > 0) {
                finishReason = "tool_calls";
            }

            choices.push({
                "index": i,
                "message": message,
                "finish_reason": finishReason
            });
        }

        // Determine target model name
        var modelName = resBody.routedModel || context.getVariable("model") || defaultModel;

        // Construct standard OpenAI Chat Completion response structure
        var openaiPayload = {
            "id": "chatcmpl-" + context.getVariable("messageid"),
            "object": "chat.completion",
            "created": Math.floor(Date.now() / 1000),
            "model": modelName,
            "choices": choices,
            "usage": {}
        };
        
        // Map token usage metadata if present
        if (resBody.usageMetadata) {
            openaiPayload.usage = {
                "prompt_tokens": resBody.usageMetadata.promptTokenCount || 0,
                "completion_tokens": resBody.usageMetadata.candidatesTokenCount || 0,
                "total_tokens": resBody.usageMetadata.totalTokenCount || 0
            };
        }

        // Update response content and set proper Content-Length header
        var payloadString = JSON.stringify(openaiPayload);
        context.setVariable("response.content", payloadString);
        
        var byteLength = new java.lang.String(payloadString).getBytes("UTF-8").length;
        context.setVariable("response.header.Content-Length", byteLength.toString());
        context.removeVariable("response.header.Transfer-Encoding");

        // Case 2: Non-Vertex AI payload (e.g., Ollama or native OpenAI format) -> Cleanup internal fields
    } else if (resBody && typeof resBody === "object") {
        // Strip internal 'routedModel' key if it was injected during token counting / caching
        if ("routedModel" in resBody) {
            delete resBody.routedModel;
            var payloadString = JSON.stringify(resBody);
            context.setVariable("response.content", payloadString);

            // Recalculate Content-Length header to reflect removed property
            var byteLength = new java.lang.String(payloadString).getBytes("UTF-8").length;
            context.setVariable("response.header.Content-Length", byteLength.toString());
            context.removeVariable("response.header.Transfer-Encoding");
        }
    }
} catch (e) {
    // Capture parsing errors gracefully without disrupting flow
    context.setVariable("x-parse-response-error", e.message);
}
