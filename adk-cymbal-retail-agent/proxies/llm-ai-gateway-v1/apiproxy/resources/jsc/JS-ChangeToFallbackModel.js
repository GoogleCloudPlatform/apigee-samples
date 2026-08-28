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

var defaultFallback = context.getVariable("llm_default_fallback_model") || "gemini-2.5-flash";
var originalModel = context.getVariable("model") || "";
var fallbackModel = context.getVariable("llm_fallback_model") || defaultFallback;

if (originalModel) {
    if (originalModel.indexOf("flash") >= 0) {
        fallbackModel = originalModel;
    } else if (originalModel.indexOf("-pro") >= 0) {
        fallbackModel = originalModel.replace("-pro", "-flash");
    } else {
        fallbackModel = defaultFallback;
    }
}

if (!fallbackModel) {
    fallbackModel = defaultFallback;
}

// 1. Update the 'model' variable so that the LLMTokenQuota policy counts it under the fallback model
context.setVariable("model", fallbackModel);
context.setVariable("fallback_triggered", "true");

