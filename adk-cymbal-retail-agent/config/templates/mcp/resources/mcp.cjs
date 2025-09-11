/*
 *  Copyright 2025 Google LLC
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *       http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */

var isApigee = (typeof context !== "undefined");
var log = isApigee?print:console.log;

function isString(obj) {
  return (Object.prototype.toString.call(obj) === '[object String]');
}

function getPrettyJSON(value) {
  return JSON.stringify(value, null, 2);
}


function _get(obj, keyString, defaultValue) {
  if (typeof obj !== 'object' || obj === null) {
    return defaultValue;
  }

  var keys = keyString.split('.');

  var current = obj;
  for (var i = 0; i < keys.length; i++) {
    var key = keys[i];
    if (typeof current !== 'object' || current === null || typeof current[key] === 'undefined') {
      return defaultValue;
    }
    current = current[key];
  }

  return current;
}

function setErrorResponse(ctx, status, error) {
  var mcpId = ctx.getVariable("mcp.id");

  var responseBody = {
    jsonrpc: "2.0",
    error: {
      code: 500,
      message: "Internal Server Error"
    }
  }

  if (mcpId) {
    responseBody.id = mcpId;
  }


  if (isString(error)) {
    responseBody.error.message = error
  }

  if (error.status) {
    responseBody.error.code = status;
    status = error.status
  }

  if (error.message) {
    responseBody.error.message = error.message;
  }

  // if (error.stack) {
  //   responseBody.stack = error.stack;
  // }

  var headers = [];
  if (error.headers) {
    headers = headers.concat(error.headers);
  }

  headers.push(['Content-Type', 'application/json']);
  ctx.setVariable("error_body", getPrettyJSON(responseBody))
  ctx.setVariable("error_status", status)
  ctx.setVariable("error_headers", getPrettyJSON(headers))

  throw new Error(responseBody.error.message)

  //setResponse(ctx, status, [], getPrettyJSON(responseBody));
}

function setResponse(ctx, status, headers, content) {
  ctx.setVariable("response.status.code", status.toString());

  if (Array.isArray(headers)) {
    //group headers by name (for multi-value headers)
    var headerMap = {}
    for (var i = 0; i < headers.length; i++) {
      var hName = headers[i][0];
      var hValue = headers[i][1];
      if (!headerMap[hName]) {
        headerMap[hName] = [];
      }
      headerMap[hName].push(hValue);
    }

    for (var header in headerMap) {
      var headerValues = headerMap[header];
      if (headerValues.length === 1) {
        ctx.setVariable("response.header." + header.toLowerCase(), headerMap[header][0]);
        continue;
      }

      ctx.setVariable("response.header." + header.toLowerCase() + "-Count", headerMap[header].length);
      for (var j = 0; j < headerValues.length; j++) {
        ctx.setVariable("response.header." + header.toLowerCase() + "-" + j, headerMap[header][j]);
      }
    }
  }
  ctx.setVariable("response.content", content)
}


function flattenAndSetFlowVariables(ctx, prefix, obj, path) {
  for (var key in obj) {
    if (Object.prototype.hasOwnProperty.call(obj, key)) {
      var newPath = path ? path + '.' + key : key;
      var value = obj[key];

      if (typeof value === 'object' && value !== null) {
        flattenAndSetFlowVariables(ctx, prefix, value, newPath);
      } else {
        if (context && typeof ctx.setVariable === 'function') {
          ctx.setVariable(prefix + newPath, value);
        }
      }
    }
  }
}

function combinePaths(path1, path2) {
  path1 = path1.trim();
  path2 = path2.trim();

  if (path1.charAt(path1.length - 1) === '/') {
    return path1.slice(0, -1) + path2;
  } else {
    return path1 + path2;
  }
}

function parseJsonRpc(ctx, jsonString, createFlowVars) {
  var rpc;

  try {
    rpc = JSON.parse(jsonString);
  } catch (e) {
    throw new Error("Error parsing JSON: " + e.message);
  }

  if (typeof rpc !== 'object' || rpc === null) {
    throw new Error("Parsed object is not a valid object.");
  }

  if (rpc.jsonrpc !== "2.0") {
    throw new Error("Invalid JSON-RPC version. Expected '2.0', but got: " + rpc.jsonrpc);
  }

  if (!(typeof rpc.method === 'string' || typeof rpc.error === 'object' || typeof rpc.result !== 'undefined')) {
    throw new Error("Parsed object does not conform to JSON-RPC 2.0 request or response structure.");
  }

  if (!createFlowVars) {
    return rpc;
  }

  flattenAndSetFlowVariables(ctx,"mcp.", rpc, '');

  return rpc
}

function modifyRequestPath(ctx) {

  var messagePath = ctx.getVariable("message.path");
  var mcpMethod = ctx.getVariable("mcp.method");
  var mcpToolName = ctx.getVariable("mcp.params.name");

  if (mcpMethod === "tools/call" && mcpToolName) {
    ctx.setVariable("message.path", combinePaths(messagePath, "/tools/" + mcpToolName))
  }
}



function replacePathParams(requestPath, argumentsObj) {
  var hasPlaceholders = /\{([a-zA-Z0-9_]+)\}/.test(requestPath);

  if (!hasPlaceholders) {
    return requestPath;
  }

  if (!argumentsObj || !argumentsObj.arguments || !argumentsObj.arguments.path_params) {
    throw new Error("Invalid arguments structure. 'arguments.path_params' is required when path contains placeholders.");
  }

  var replacedPath = requestPath.replace(/\{([a-zA-Z0-9_]+)\}/g, function(match, paramName) {
    var paramValue = argumentsObj.arguments.path_params[paramName];

    if (typeof paramValue === 'undefined' || paramValue === null) {
      throw new Error("Missing required path parameter: '" + paramName + "'");
    }

    return paramValue;
  });

  return replacedPath;
}


function createQueryParams(argumentsObj) {
  if (!argumentsObj || !argumentsObj.arguments || !argumentsObj.arguments.query_params) {
    return ""
  }

  var queryParams = argumentsObj.arguments.query_params;
  var params = [];

  for (var key in queryParams) {
    if (Object.prototype.hasOwnProperty.call(queryParams, key)) {
      var encodedKey = encodeURIComponent(key);
      var encodedValue = encodeURIComponent(queryParams[key]);
      params.push(encodedKey + "=" + encodedValue);
    }
  }

  return params.length > 0 ? "?" + params.join("&") : "";
}


function createFullUrl(baseURL, requestPath, argumentsObj) {
  var fullPath = replacePathParams(requestPath, argumentsObj);
  var queryString = createQueryParams(argumentsObj);
  return baseURL + fullPath + queryString;
}


if (!isApigee) {
  module.exports = {
    "flattenAndSetFlowVariables": flattenAndSetFlowVariables,
    "parseJsonRpc": parseJsonRpc,
    "setResponse": setResponse,
    "setErrorResponse": setErrorResponse,
    "createFullUrl": createFullUrl,
    "createQueryParams": createQueryParams,
    "replacePathParams": replacePathParams
  };
}