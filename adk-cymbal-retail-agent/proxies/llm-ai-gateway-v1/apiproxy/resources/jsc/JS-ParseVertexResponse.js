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
 * Protocol Response Transformer & Normalizer:
 * Enforces protocol symmetry between inbound client requests and outbound model responses.
 * 
 * Supported Scenarios:
 * 1. Client Request = OpenAI, Target Response = Vertex AI ("candidates") -> Convert Vertex AI to OpenAI format.
 * 2. Client Request = OpenAI, Target Response = OpenAI ("choices")   -> Clean up internal fields and return OpenAI format.
 * 3. Client Request = Vertex AI, Target Response = Vertex AI ("candidates") -> Clean up internal fields and return Vertex AI format.
 * 4. Client Request = Vertex AI, Target Response = OpenAI ("choices") -> Convert OpenAI to Vertex AI format.
 */

/**
 * Converts an OpenAI Chat Completion response payload into Vertex AI Candidate format.
 * 
 * @param {Object} openAiBody - Parsed JSON object of OpenAI response.
 * @param {string} modelName - Resolved model name.
 * @returns {Object} Formatted Vertex AI response payload.
 */
function convertOpenAiToVertex(openAiBody, modelName) {
    var candidates = [];
    if (openAiBody.choices && Array.isArray(openAiBody.choices)) {
        for (var i = 0; i < openAiBody.choices.length; i++) {
            var choice = openAiBody.choices[i];
            var parts = [];
            
            if (choice.message) {
                if (choice.message.content) {
                    parts.push({ "text": choice.message.content });
                }
                if (choice.message.tool_calls && Array.isArray(choice.message.tool_calls)) {
                    for (var k = 0; k < choice.message.tool_calls.length; k++) {
                        var tc = choice.message.tool_calls[k];
                        if (tc.function) {
                            var fnArgs = {};
                            try {
                                fnArgs = typeof tc.function.arguments === "string" ? JSON.parse(tc.function.arguments) : (tc.function.arguments || {});
                            } catch (e) {
                                fnArgs = {};
                            }
                            parts.push({
                                "functionCall": {
                                    "name": tc.function.name,
                                    "args": fnArgs
                                }
                            });
                        }
                    }
                }
            }
            if (parts.length === 0) {
                parts.push({ "text": "" });
            }
            
            var finishReason = "STOP";
            if (choice.finish_reason === "length") {
                finishReason = "MAX_TOKENS";
            }
            
            candidates.push({
                "content": {
                    "role": "model",
                    "parts": parts
                },
                "finishReason": finishReason
            });
        }
    }
    
    var vertexPayload = {
        "candidates": candidates
    };
    
    if (openAiBody.usage) {
        vertexPayload.usageMetadata = {
            "promptTokenCount": openAiBody.usage.prompt_tokens || 0,
            "candidatesTokenCount": openAiBody.usage.completion_tokens || 0,
            "totalTokenCount": openAiBody.usage.total_tokens || 0
        };
    }
    
    return vertexPayload;
}

try {
    var rawBody = context.getVariable("response.content");
    var resBody = JSON.parse(rawBody);
    var defaultModel = context.getVariable("llm_default_model");
    var fallbackModel = context.getVariable("llm_fallback_model");
    var requestProtocol = context.getVariable("request_protocol") || "openai";

    var isVertexTargetResponse = resBody.candidates && Array.isArray(resBody.candidates);
    var isOpenAiTargetResponse = resBody.choices && Array.isArray(resBody.choices);

    var finalPayload = null;

    if (requestProtocol === "openai") {
        if (isVertexTargetResponse) {
            var choices = [];

            for (var i = 0; i < resBody.candidates.length; i++) {
                var candidate = resBody.candidates[i];
                var message = {
                    "role": "assistant",
                    "content": null
                };
                var tool_calls = [];
                var textContent = "";
                var finishReason = "stop";

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
                        if (context.getVariable("fallback_triggered") === "true") {
                            message.content = "[SYSTEM NOTICE: Downgraded to " + fallbackModel + " because your Pro token quota was exceeded]\n\n" + textContent;
                        } else {
                            message.content = textContent;
                        }
                    }
                    if (tool_calls.length > 0) {
                        message.tool_calls = tool_calls;
                    }
                }

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

            var modelName = resBody.routedModel || context.getVariable("model") || defaultModel;

            finalPayload = {
                "id": "chatcmpl-" + context.getVariable("messageid"),
                "object": "chat.completion",
                "created": Math.floor(Date.now() / 1000),
                "model": modelName,
                "choices": choices,
                "usage": {}
            };

            if (resBody.usageMetadata) {
                finalPayload.usage = {
                    "prompt_tokens": resBody.usageMetadata.promptTokenCount || 0,
                    "completion_tokens": resBody.usageMetadata.candidatesTokenCount || 0,
                    "total_tokens": resBody.usageMetadata.totalTokenCount || 0
                };
            }
        } else {
            if (resBody && typeof resBody === "object" && "routedModel" in resBody) {
                delete resBody.routedModel;
            }
            finalPayload = resBody;
        }
    } else {
        if (isVertexTargetResponse) {
            if (resBody && typeof resBody === "object" && "routedModel" in resBody) {
                delete resBody.routedModel;
            }
            finalPayload = resBody;
        } else if (isOpenAiTargetResponse) {
            var resolvedModel = resBody.routedModel || context.getVariable("model") || defaultModel;
            if ("routedModel" in resBody) {
                delete resBody.routedModel;
            }
            finalPayload = convertOpenAiToVertex(resBody, resolvedModel);
        } else {
            if (resBody && typeof resBody === "object" && "routedModel" in resBody) {
                delete resBody.routedModel;
            }
            finalPayload = resBody;
        }
    }

    if (finalPayload) {
        var payloadString = JSON.stringify(finalPayload);
        context.setVariable("response.content", payloadString);

        var byteLength = new java.lang.String(payloadString).getBytes("UTF-8").length;
        context.setVariable("response.header.Content-Length", byteLength.toString());
        context.removeVariable("response.header.Transfer-Encoding");
    }
} catch (e) {
    context.setVariable("x-parse-response-error", e.message);
}
