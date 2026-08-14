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
    var rawBody = context.getVariable("request.content");
    var reqBody = JSON.parse(rawBody);
    
    // If the request is already in native Vertex AI structure, pass it through unchanged
    if (!(reqBody.contents && Array.isArray(reqBody.contents))) {
        
        var vertexContents = [];
        var systemInstruction = null;
        
        // Support OpenAI /chat/completions standard payload
        if (reqBody.messages && Array.isArray(reqBody.messages)) {
            for (var i = 0; i < reqBody.messages.length; i++) {
                var msg = reqBody.messages[i];
                
                if (msg.role === 'system') {
                    systemInstruction = {
                        "parts": [{"text": msg.content || ""}]
                    };
                } else if (msg.role === 'assistant') {
                    var parts = [];
                    if (msg.content) parts.push({"text": msg.content});
                    if (msg.tool_calls && Array.isArray(msg.tool_calls)) {
                        for (var k = 0; k < msg.tool_calls.length; k++) {
                            // Extract only what's needed for Vertex
                            parts.push({
                                "functionCall": {
                                    "name": msg.tool_calls[k].function.name,
                                    "args": msg.tool_calls[k].function.arguments ? JSON.parse(msg.tool_calls[k].function.arguments) : {}
                                }
                            });
                        }
                    }
                    if (parts.length === 0) parts.push({"text": ""});
                    vertexContents.push({
                        "role": "model",
                        "parts": parts
                    });
                } else if (msg.role === 'tool') {
                    // Extract function name from OpenAI tool_call_id
                    var fnName = msg.tool_call_id || "unknown";
                    if (fnName.startsWith("call_")) {
                        fnName = fnName.substring(5);
                        var lastUnderscore = fnName.lastIndexOf('_');
                        if (lastUnderscore !== -1) {
                            fnName = fnName.substring(0, lastUnderscore);
                        }
                    }
                    var contentObj;
                    try { contentObj = JSON.parse(msg.content); } catch(e) { contentObj = {"result": msg.content}; }
                    
                    var flatResult = contentObj;
                    if (contentObj && contentObj.content && Array.isArray(contentObj.content) && contentObj.content[0] && contentObj.content[0].text) {
                        flatResult = {"result": contentObj.content[0].text};
                    }
                    
                    vertexContents.push({
                        "role": "function", // Vertex uses 'function' role for function responses!
                        "parts": [{
                            "functionResponse": {
                                "name": fnName,
                                "response": flatResult
                            }
                        }]
                    });
                } else {
                    vertexContents.push({
                        "role": "user",
                        "parts": [{"text": msg.content || ""}]
                    });
                }
            }
        } 
        // Support legacy simplistic test payload {"prompt": "..."}
        else if (reqBody.prompt) {
            vertexContents.push({
                "role": "user",
                "parts": [{"text": reqBody.prompt}]
            });
        }

        var maxTokens = reqBody.max_tokens || reqBody.max_completion_tokens || 8192;

        var vertexPayload = {
            "contents": vertexContents,
            "generationConfig": {
                "maxOutputTokens": maxTokens
            }
        };
        
        if (systemInstruction) {
            vertexPayload.systemInstruction = systemInstruction;
        }
        
        // Map OpenAI tools to Vertex functionDeclarations
        if (reqBody.tools && Array.isArray(reqBody.tools)) {
            var functionDeclarations = [];
            for (var j = 0; j < reqBody.tools.length; j++) {
                var oTool = reqBody.tools[j];
                if (oTool.type === "function" && oTool.function) {
                    functionDeclarations.push(oTool.function);
                }
            }
            if (functionDeclarations.length > 0) {
                vertexPayload.tools = [{"functionDeclarations": functionDeclarations}];
            }
        }

        context.setVariable("request.content", JSON.stringify(vertexPayload));
        context.setVariable("vertex_payload_debug", JSON.stringify(vertexPayload));
    }
    context.setVariable("x-build-payload-error", "");
} catch (e) {
    context.setVariable("x-build-payload-error", e.message);
}
