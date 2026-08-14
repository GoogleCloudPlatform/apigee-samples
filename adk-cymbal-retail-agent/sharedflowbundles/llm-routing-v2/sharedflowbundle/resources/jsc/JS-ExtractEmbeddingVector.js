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
    var responseStr = context.getVariable("embeddingsResponse.content");
    var responseObj = JSON.parse(responseStr);
    var realVector = responseObj.predictions[0].embeddings.values;
    context.setVariable("prompt_vector", JSON.stringify(realVector));
    context.setVariable("x-mock-vector-error", "none");
} catch (e) {
    // Fallback to dummy vector if something goes horribly wrong
    var dummyVector = [];
    for(var i=0; i<768; i++) { dummyVector.push(0.0); }
    context.setVariable("prompt_vector", JSON.stringify(dummyVector));
    context.setVariable("x-mock-vector-error", e.message);
}
