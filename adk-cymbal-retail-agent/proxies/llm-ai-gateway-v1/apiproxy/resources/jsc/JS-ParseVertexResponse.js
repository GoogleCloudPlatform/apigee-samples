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
    var rawBody = context.getVariable("response.content");
    var resBody = JSON.parse(rawBody);
    var defaultModel = context.getVariable("llm_default_model");
    var fallbackModel = context.getVariable("llm_fallback_model");

    // If it's not a Vertex AI payload (no candidates array), or already OpenAI, skip translation
    if (resBody.candidates && Array.isArray(resBody.candidates)) {
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
                        message.content = "⚠️ *[SYSTEM NOTICE: Downgraded to " + fallbackModel +" because your Pro token quota was exceeded]*\n\n" + textContent;
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

        var openaiPayload = {
            "id": "chatcmpl-" + context.getVariable("messageid"),
            "object": "chat.completion",
            "created": Math.floor(Date.now() / 1000),
            "model": modelName,
            "choices": choices,
            "usage": {}
        };
        
        if (resBody.usageMetadata) {
            openaiPayload.usage = {
                "prompt_tokens": resBody.usageMetadata.promptTokenCount || 0,
                "completion_tokens": resBody.usageMetadata.candidatesTokenCount || 0,
                "total_tokens": resBody.usageMetadata.totalTokenCount || 0
            };
        }

        var payloadString = JSON.stringify(openaiPayload);
        context.setVariable("response.content", payloadString);
        
        var byteLength = new java.lang.String(payloadString).getBytes("UTF-8").length;
        context.setVariable("response.header.Content-Length", byteLength.toString());
        context.removeVariable("response.header.Transfer-Encoding");
    }
} catch (e) {
    context.setVariable("x-parse-response-error", e.message);
}
