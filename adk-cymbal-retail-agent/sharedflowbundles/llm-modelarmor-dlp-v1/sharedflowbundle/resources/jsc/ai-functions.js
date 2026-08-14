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

function getResponse(contentData) {
  var responseText = "";

  if (contentData && contentData["candidates"] && contentData["candidates"].length > 0) {
    // gemini format
    for (i = contentData["candidates"].length - 1; i >= 0; i--) {
      var candidate = contentData["candidates"][i];
      if (
        candidate &&
        candidate["content"] &&
        candidate["content"]["parts"] &&
        candidate["content"]["parts"].length > 0
      ) {
        for (p = candidate["content"]["parts"].length - 1; p >= 0; p--) {
          var part = candidate["content"]["parts"][p];
          if (part && part["text"]) {
            responseText = part["text"];
            break;
          }
        }
      }
    }
  } else if (contentData && contentData["choices"] && contentData["choices"].length > 0) {
    // openmodel format
    for (i = contentData["choices"].length - 1; i >= 0; i--) {
      var choice = contentData["choices"][i];
      if (choice && choice["message"] && choice["message"]["content"]) {
        responseText = choice["message"]["content"];
        break;
      }
    }
  } else if (contentData && contentData["content"] && contentData["content"].length > 0) {
    // claude format
    for (i = contentData["content"].length - 1; i >= 0; i--) {
      var content = contentData["content"][i];
      if (content && content["type"] == "text") {
        responseText = content["text"];
        break;
      }
    }
  }
  return responseText;
}

function setResponse(contentData, content) {
  if (contentData && contentData["candidates"] && contentData["candidates"].length > 0) {
    // gemini format
    for (i = contentData["candidates"].length - 1; i >= 0; i--) {
      var candidate = contentData["candidates"][i];
      if (
        candidate &&
        candidate["content"] &&
        candidate["content"]["parts"] &&
        candidate["content"]["parts"].length > 0
      ) {
        for (p = candidate["content"]["parts"].length - 1; p >= 0; p--) {
          var part = candidate["content"]["parts"][p];
          if (part && part["text"]) {
            part["text"] = content;
            break;
          }
        }
      }
    }
  } else if (contentData && contentData["choices"] && contentData["choices"].length > 0) {
    // openmodel format
    for (i = contentData["choices"].length - 1; i >= 0; i--) {
      var choice = contentData["choices"][i];
      if (choice && choice["message"] && choice["message"]["content"]) {
        choice["message"]["content"] = content;
        break;
      }
    }
  } else if (contentData && contentData["content"] && contentData["content"].length > 0) {
    // claude format
    for (i = contentData["content"].length - 1; i >= 0; i--) {
      var claudeContent = contentData["content"][i];
      if (claudeContent && claudeContent["type"] == "text") {
        claudeContent["text"] = content;
        break;
      }
    }
  }
  return contentData;
}

// this is to only export the function if in node
if (typeof exports !== "undefined") {
  exports.getResponse = getResponse;
  exports.setResponse = setResponse;
}
