/*
 * Copyright 2025 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

var isApigee = (typeof context !== "undefined");
var log = isApigee?print:console.log;


var JSON_RPC_PARSE_ERROR = -32700;
var JSON_RPC_INVALID_REQUEST = -32600;
var JSON_RPC_METHOD_NOT_FOUND = -32601;
var JSON_RPC_INVALID_PARAMS = -32602;
var JSON_RPC_INTERNAL_ERROR = -32603;
var JSON_RPC_REQUEST_CANCELLED = -32800;
var JSON_RPC_CONTENT_TOO_LARGE = -32801;
var JSON_RPC_CONNECTION_CLOSED = -32000;
var JSON_RPC_UNAUTHENTICATED_REQUEST = -32001;
var JSON_RPC_UNAUTHORIZED_REQUEST = -32002;

/**
 * Checks if an object is a string.
 *
 * @param {*} obj The object to check.
 * @returns {boolean} True if the object is a string, false otherwise.
 */
function isString(obj) {
  return (Object.prototype.toString.call(obj) === '[object String]');
}

/**
 * Checks if an object is a plain JavaScript object (created by `{}` or `new Object()`).
 *
 * @param {*} item The item to check.
 * @returns {boolean} True if the item is a plain object, false otherwise.
 */
function isPlainObject(item) {
  if (item === null || typeof item !== 'object') {
    return false;
  }

  var classString = Object.prototype.toString.call(item);
  return classString === '[object Object]';
}

/**
 * Converts a JavaScript value into a pretty-printed JSON string (2-space indentation).
 *
 * @param {*} value The value to convert.
 * @returns {string} The formatted JSON string.
 */
function getPrettyJSON(value) {
  return JSON.stringify(value, null, 2);
}


/**
 * Safely retrieves a nested property value from an object using a dot-separated key string.
 *
 * @param {object} obj The object to query.
 * @param {string} keyString The dot-separated path to the nested property (e.g., "a.b.c").
 * @param {*} defaultValue The value to return if the path is not found or the object is null/undefined.
 * @returns {*} The value at the specified path, or the defaultValue.
 */
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

/**
 * Calculates a simple hash code for a string.
 *
 * @param {string} str The string to hash.
 * @returns {number} The calculated hash code.
 */
function hashCode(str) {
  var hash = 0, i, chr;
  if (str.length === 0) return hash;
  for (i = 0; i < str.length; i++) {
    chr   = str.charCodeAt(i);
    hash  = ((hash << 5) - hash) + chr;
    hash |= 0; // Convert to 32bit integer
  }
  return hash;
}

/**
 * Custom Error class for signaling JSON-RPC errors.
 *
 * @class
 * @augments {Error}
 * @param {string} message The error message.
 * @param {number} statusCode The JSON-RPC error code (e.g., -32602).
 * @param {number} [httpStatus] (optional) The HTTP Status code (e.g. 401)
 * @returns {JsonRPCError} An instance of JsonRPCError.
 */
function JsonRPCError(message, statusCode, httpStatus) {

  Error.call(this, message);

  if (Error.captureStackTrace) {
    Error.captureStackTrace(this, JsonRPCError);
  } else {
    this.stack = (new Error()).stack;
  }

  this.name = 'JsonRPCError';
  this.code = statusCode;
  this.message = message
  this.status = httpStatus;

  return this
}

/**
 * @private
 */
JsonRPCError.prototype = Object.create(Error.prototype);
JsonRPCError.prototype.constructor = JsonRPCError;

/**
 * Sets the Apigee flow variables for a standardized JSON-RPC error response.
 * This function is designed to be called when an error occurs during processing.
 *
 * @param {object} ctx The Apigee context object.
 * @param {number} status The HTTP status code to set (e.g., 500).
 * @param {(string|object)} error The error information. Can be a string message or an object containing code, message, and status.
 * @throws {Error} Throws a standard JavaScript error to halt the policy execution (as required in Apigee).
 */
function setErrorResponse(ctx, status, error) {
  var mcpId = ctx.getVariable("mcp.id");

  var responseBody = {
    jsonrpc: "2.0",
    error: {
      code: JSON_RPC_INTERNAL_ERROR,
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
    status = error.status
  }

  if (error.message) {
    responseBody.error.message = error.message;
  }

  if (error.code) {
    responseBody.error.code = error.code
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

/**
 * Sets the necessary Apigee flow variables (`response.status.code`, headers, `response.content`)
 * to construct a complete HTTP response.
 *
 * @param {object} ctx The Apigee context object.
 * @param {number} status The HTTP status code to set.
 * @param {Array<Array<string>>} headers An array of header pairs, e.g., `[['Content-Type', 'application/json']]`.
 * @param {string} content The body content of the response.
 */
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

      ctx.setVariable("response.header." + header.toLowerCase() + "-count", headerMap[header].length);
      for (var j = 0; j < headerValues.length; j++) {
        ctx.setVariable("response.header." + header.toLowerCase() + "-" + j, headerMap[header][j]);
      }
    }
  }
  ctx.setVariable("response.content", content)
}


/**
 * Recursively flattens a JavaScript object and sets its properties as Apigee flow variables.
 * Keys are concatenated with dots and prefixed by the specified prefix.
 *
 * @param {object} ctx The Apigee context object.
 * @param {string} prefix The prefix to prepend to all variable names (e.g., "mcp.").
 * @param {object} obj The object to flatten and set as flow variables.
 * @param {string} [path] The current path used for recursion (internal use).
 */
function flattenAndSetFlowVariables(ctx, prefix, obj, path) {
  for (var key in obj) {
    if (Object.prototype.hasOwnProperty.call(obj, key)) {
      var newPath = path ? path + '.' + key : key;
      var value = obj[key];

      if (typeof value === 'object' && value !== null) {
        flattenAndSetFlowVariables(ctx, prefix, value, newPath);
      } else {
        if (ctx && typeof ctx.setVariable === 'function') {
          ctx.setVariable(prefix + newPath, value);
        }
      }
    }
  }
}

/**
 * Combines two URL path segments, ensuring proper slash handling.
 * It inserts exactly one slash between the two segments, removing any
 * extraneous leading/trailing slashes from the internal connection point.
 *
 * @param {string} path1 The first path segment (e.g., "/base/url/").
 * @param {string} path2 The second path segment (e.g., "/resource" or "resource").
 * @returns {string} The combined path (e.g., "/base/url/resource").
 */
function combinePaths(path1, path2) {
  // Trim whitespace
  path1 = (path1 || "").trim();
  path2 = (path2 || "").trim();

  if (path1.endsWith('/')) {
    path1 = path1.slice(0, -1);
  }

  if (path2.startsWith('/')) {
    path2 = path2.substring(1);
  }

  return path1 + '/' + path2;
}

/**
 * Parses a JSON string into a JSON-RPC 2.0 object and performs basic validation.
 * Optionally flattens the resulting object into Apigee flow variables with the "mcp." prefix.
 *
 * @param {object} ctx The Apigee context object.
 * @param {string} jsonString The JSON-RPC request or response as a string.
 * @param {boolean} createFlowVars If true, creates flattened Apigee flow variables (e.g., mcp.method).
 * @returns {object} The parsed JSON-RPC object.
 * @throws {JsonRPCError} If parsing fails or the object is not a valid JSON-RPC 2.0 structure.
 */
function parseJsonRpc(ctx, jsonString, createFlowVars) {
  var rpc;

  try {
    rpc = JSON.parse(jsonString);
  } catch (e) {
    throw new JsonRPCError("Error parsing JSON: " + e.message, JSON_RPC_PARSE_ERROR);
  }

  if (typeof rpc !== 'object' || rpc === null) {
    throw new JsonRPCError("Parsed object is not a valid object.", JSON_RPC_PARSE_ERROR);
  }

  if (rpc.jsonrpc !== "2.0") {
    throw new JsonRPCError("Invalid JSON-RPC version. Expected '2.0', but got: " + rpc.jsonrpc, JSON_RPC_INVALID_REQUEST);
  }

  if (!(typeof rpc.method === 'string' || typeof rpc.error === 'object' || typeof rpc.result !== 'undefined')) {
    throw new JsonRPCError("Parsed object does not conform to JSON-RPC 2.0 request or response structure.", JSON_RPC_INVALID_REQUEST);
  }

  if (!createFlowVars) {
    return rpc;
  }

  flattenAndSetFlowVariables(ctx,"mcp.", rpc, '');

  return rpc
}

/**
 * Parses the incoming JSON-RPC request from the Apigee context.
 * This is a wrapper around parseJsonRpc specifically for the main request body.
 *
 * @param {object} ctx The Apigee context object.
 * @returns {object} The parsed JSON-RPC object.
 */
function parseMCPReq(ctx) {
  return parseJsonRpc(ctx, ctx.getVariable("request.content"), true);
}


/**
 * Replaces path parameters (placeholders like `{paramName}`) in a request path with
 * corresponding values from the JSON-RPC arguments object.
 *
 * @param {string} requestPath The path string containing placeholders (e.g., "/users/{userId}").
 * @param {object} argumentsObj The JSON-RPC `params` object containing the `arguments` key.
 * @param {Array<string>} pathParamNames An array of valid path parameter names expected in the path.
 * @returns {string} The path with all parameters replaced by their values.
 * @throws {JsonRPCError} If required path parameters are missing or unrecognized.
 */
function replacePathParams(requestPath, argumentsObj, pathParamNames) {
  var hasPlaceholders = /\{([a-zA-Z0-9_]+)\}/.test(requestPath);

  if (!hasPlaceholders) {
    return requestPath;
  }

  // Ensure arguments object has the expected structure
  if (!argumentsObj || !argumentsObj.arguments) {
    throw new JsonRPCError("Invalid arguments structure. 'arguments' is required when path contains placeholders.", JSON_RPC_INVALID_PARAMS);
  }

  // Ensure pathParamNames is a valid array
  if (!Array.isArray(pathParamNames)) {
    throw new JsonRPCError("Invalid pathParamNames. It must be an array of strings.", JSON_RPC_INVALID_PARAMS);
  }

  var replacedPath = requestPath.replace(/\{([a-zA-Z0-9_]+)\}/g, function(match, paramName) {
    if (pathParamNames.indexOf(paramName) === -1) {
      throw new JsonRPCError("Path parameter '" + paramName + "' is not a recognized parameter.", JSON_RPC_INVALID_PARAMS);
    }

    // Retrieve the value directly from the arguments object
    var paramValue = argumentsObj.arguments[paramName];

    if (typeof paramValue === 'undefined' || paramValue === null) {
      throw new JsonRPCError("Missing required path parameter: '" + paramName + "'", JSON_RPC_INVALID_PARAMS);
    }

    return paramValue;
  });

  return replacedPath;
}

/**
 * Creates a URL query string (`?key1=value1&key2=value2`) from the JSON-RPC arguments object,
 * including only parameters specified in `queryParamNames`.
 *
 * @param {object} argumentsObj The JSON-RPC `params` object containing the `arguments` key.
 * @param {Array<string>} queryParamNames An array of valid query parameter names to include.
 * @returns {string} The formatted query string, including the leading '?' if parameters exist, otherwise an empty string.
 */
function createQueryParams(argumentsObj, queryParamNames) {
  // Ensure arguments object has the expected structure
  if (!argumentsObj || !argumentsObj.arguments) {
    return "";
  }

  // Ensure queryParamNames is a valid array
  if (!Array.isArray(queryParamNames)) {
    console.error("Invalid queryParamNames. It must be an array of strings.");
    return "";
  }

  var params = [];

  // Iterate over the provided list of valid query parameter names
  for (var i = 0; i < queryParamNames.length; i++) {
    var key = queryParamNames[i];
    var value = argumentsObj.arguments[key];

    // Only include the key-value pair if the value is defined and not null
    if (typeof value !== 'undefined' && value !== null) {
      var encodedKey = encodeURIComponent(key);
      var encodedValue = encodeURIComponent(value);
      params.push(encodedKey + "=" + encodedValue);
    }
  }

  return params.length > 0 ? "?" + params.join("&") : "";
}


/**
 * Constructs the full target URL by combining the base URL, replacing path parameters,
 * and appending the query string.
 *
 * @param {string} baseURL The base URL of the target service.
 * @param {string} requestPath The path suffix which may contain placeholders.
 * @param {object} argumentsObj The JSON-RPC `params` object containing the `arguments`.
 * @param {Array<string>} pathParams Array of recognized path parameter names.
 * @param {Array<string>} queryParams Array of recognized query parameter names.
 * @returns {string} The fully constructed URL.
 */
function createFullUrl(baseURL, requestPath, argumentsObj, pathParams, queryParams) {
  var fullPath = replacePathParams(requestPath, argumentsObj, pathParams);
  var queryString = createQueryParams(argumentsObj, queryParams);
  return baseURL + fullPath + queryString;
}



/**
 * Safely parses a JSON string, returning the result or a default value on failure.
 *
 * @param {string} str The string to parse.
 * @param {*} defaultValue The value to return if parsing fails.
 * @returns {*} The parsed JSON object or the default value.
 */
function parseJsonString(str, defaultValue) {
  if (!str || typeof str !== 'string') {
    return defaultValue;
  }

  try {
    return JSON.parse(str);
  } catch (error) {
    return defaultValue;
  }
}

/**
 * Converts a JSON object into a `application/x-www-form-urlencoded` string.
 * Supports simple key-value pairs and arrays. Nested objects are flattened using dot notation.
 *
 * @param {object} jsonData The JSON object to convert.
 * @returns {string} The URL-encoded form data string.
 */
function jsonToFormURLEncoded(jsonData) {
  var params = [];

  function processObject(obj, prefix) {
    for (var key in obj) {
      if (Object.prototype.hasOwnProperty.call(obj, key)) {
        var newKey = prefix ? prefix + '.' + key : key;
        var value = obj[key];

        if (value && typeof value === 'object') {
          if (Array.isArray(value)) {
            for (var i = 0; i < value.length; i++) {
              params.push(encodeURIComponent(newKey) + '=' + encodeURIComponent(value[i]));
            }
          } else {
            processObject(value, newKey);
          }
        } else {
          params.push(encodeURIComponent(newKey) + '=' + encodeURIComponent(value));
        }
      }
    }
  }

  processObject(jsonData, '');

  return params.join('&');
}

/**
 * Recursively converts a JSON object chunk into an XML string fragment based on a provided schema.
 * This is the core engine for JSON to XML transcoding, supporting attributes, elements, and
 * wrapped/unwrapped arrays based on Open API's XML object extensions.
 *
 * @param {(object|string|number|boolean)} data The JSON data fragment.
 * @param {object} schema The OpenAPI schema definition for this data fragment.
 * @param {string} [propName] The name of the property in the parent object (used as default element name).
 * @param {number} [indentLevel=0] The current indentation level for pretty-printing.
 * @returns {string} The XML string fragment.
 */
function jsonToXml(data, schema, propName, indentLevel) {
  // Helper function to escape special characters for safe XML content
  function escapeXml(unsafe) {
    var str = String(unsafe);
    return str.replace(/[<>&'"]/g, function(c) {
      switch (c) {
        case '<': return '&lt;';
        case '>': return '&gt;';
        case '&': return '&amp;';
        case "'": return '&apos;';
        case '"': return '&quot;';
      }
    });
  }

  var xmlString = '';
  var indent = '  '.repeat(indentLevel || 0);

  // Determine the element name based on a clear hierarchy of rules.
  var elementName = '';
  if (schema.xml && schema.xml.name) {
    elementName = schema.xml.name;
  } else if (propName) {
    elementName = propName;
  } else {
    elementName = 'root';
  }

  // Add prefix if specified
  if (schema.xml && schema.xml.prefix) {
    elementName = schema.xml.prefix + ':' + elementName;
  }

  var rootAttributes = '';
  var rootContent = '';

  // Add namespace based on new annotations
  if (schema.xml && schema.xml.namespace) {
    var prefixAttr = schema.xml.prefix ? 'xmlns:' + schema.xml.prefix : 'xmlns';
    rootAttributes += ' ' + prefixAttr + '="' + escapeXml(schema.xml.namespace) + '"';
  }

  // Separate properties into attributes and elements based on schema annotations
  var attributes = {};
  var elements = {};

  if (schema.properties) {
    for (var key in schema.properties) {
      if (schema.properties.hasOwnProperty(key)) {
        var propSchema = schema.properties[key];
        // Check if it's an attribute
        if (propSchema.xml && propSchema.xml.attribute) {
          attributes[propSchema.xml.name] = key;
        } else {
          // If not an attribute, assume it's an element.
          // The element name is either from xml.name or the property key.
          var childElementName = (propSchema.xml && propSchema.xml.name) ? propSchema.xml.name : key;
          elements[childElementName] = key;
        }
      }
    }
  }

  // Construct the root element's attributes from the JSON data
  for (var attrName in attributes) {
    if (attributes.hasOwnProperty(attrName)) {
      var dataKey = attributes[attrName];
      if (data.hasOwnProperty(dataKey)) {
        rootAttributes += ' ' + attrName + '="' + escapeXml(data[dataKey]) + '"';
      }
    }
  }

  // If there are child elements, we treat this as a container.
  if (Object.keys(elements).length > 0) {
    for (var elemName in elements) {
      if (elements.hasOwnProperty(elemName)) {
        var dataKey = elements[elemName];
        if (data.hasOwnProperty(dataKey)) {
          var childData = data[dataKey];
          var childSchema = schema.properties[dataKey];

          // Handle arrays with the "wrapped" annotation
          if (Array.isArray(childData)) {
            if (childSchema.xml && childSchema.xml.wrapped) {
              var wrapperName = childSchema.xml.name;
              var wrapperPrefix = childSchema.xml.prefix ? childSchema.xml.prefix + ':' : '';
              var wrapperNamespace = childSchema.xml.namespace ? ' xmlns:' + (childSchema.xml.prefix || '') + '="' + escapeXml(childSchema.xml.namespace) + '"' : '';

              rootContent += '\n' + indent + '  <' + wrapperPrefix + wrapperName + wrapperNamespace + '>';
              childData.forEach(function(item) {
                rootContent += '\n' + jsonToXml(item, childSchema.items, null, (indentLevel || 0) + 2);
              });
              rootContent += '\n' + indent + '  </' + wrapperPrefix + wrapperName + '>';
            } else {
              // Handle unwrapped arrays
              childData.forEach(function(item) {
                rootContent += '\n' + jsonToXml(item, childSchema.items, elemName, (indentLevel || 0) + 1);
              });
            }
          } else if (typeof childData === 'object' && childData !== null) {
            // Handle nested objects and pass the correct element name
            rootContent += '\n' + jsonToXml(childData, childSchema, elemName, (indentLevel || 0) + 1);
          } else {
            // Handle simple key-value pairs as elements
            rootContent += '\n' + indent + '  <' + elemName + '>' + escapeXml(childData) + '</' + elemName + '>';
          }
        }
      }
    }
  } else if (typeof data === 'string' || typeof data === 'number' || typeof data === 'boolean') {
    // If there are no child elements, the value of the JSON property is the text content
    rootContent = escapeXml(data);
  }

  // Build the final XML string for this node
  if (rootContent.indexOf('\n') !== -1) {
    // Prettify with newlines for child elements
    xmlString = indent + '<' + elementName + rootAttributes + '>' + rootContent + '\n' + indent + '</' + elementName + '>';
  } else {
    // Keep text content on the same line
    xmlString = indent + '<' + elementName + rootAttributes + '>' + rootContent + '</' + elementName + '>';
  }

  return xmlString;
}

/**
 * Converts a complete JSON request body into a fully formed XML document,
 * including the XML declaration.
 *
 * @param {object} jsonBody The JSON object representing the entire request payload.
 * @param {object} jsonSchema The OpenAPI schema definition for the root object.
 * @returns {string} The complete XML document string.
 */
function convertJsonToXml(jsonBody, jsonSchema) {
  var xmlHeader = '<?xml version="1.0" encoding="UTF-8"?>\n';

  // The entire jsonBody is now treated as the root element's data.
  // The name of the root element is now determined within jsonToXml.
  var xmlString = jsonToXml(jsonBody, jsonSchema, null, 0);

  return xmlHeader + xmlString;
}

/**
 * Retrieves the definition for a specific MCP tool from the global `mcpToolsInfo` object.
 *
 * @param {object} ctx The Apigee context object.
 * @param {string} toolName The name of the tool being called (e.g., "google_search").
 * @returns {object} The tool definition object.
 * @throws {JsonRPCError} If `mcpToolsInfo` is missing or the specific tool is not defined.
 */
function getToolInfo(ctx, toolName) {
  if (!mcpToolsInfo) {
    throw new JsonRPCError("Could not find MCP tools information", JSON_RPC_INTERNAL_ERROR)
  }

  var toolInfo = mcpToolsInfo[toolName];

  if (!toolInfo) {
    throw new JsonRPCError("Could not find tool definition for \""+ toolName + "\"", JSON_RPC_METHOD_NOT_FOUND)
  }

  return toolInfo
}

/**
 * Processes an incoming JSON-RPC `tools/call` request and translates it into
 * the corresponding Apigee flow variables (`message.verb`, `target.url`, `request.header.Accept`,
 * `message.content`, etc.) to invoke the target REST service.
 *
 * @param {object} ctx The Apigee context object.
 * @throws {JsonRPCError} If the request is not a valid `tools/call` or the tool/target is not found.
 */
function processMCPRequest(ctx) {
  var rpc = parseJsonRpc(ctx, ctx.getVariable("request.content"), false)

  if (rpc.method !== "tools/call") {
    throw new JsonRPCError("Cannot set target on non MCP tools/call method.", JSON_RPC_METHOD_NOT_FOUND)
  }

  var toolInfo = getToolInfo(ctx, rpc["params"]["name"])
  if (!toolInfo) {
    throw new JsonRPCError("Could not find tool definition for \""+ rpc["params"]["name"] + "\"", JSON_RPC_METHOD_NOT_FOUND)
  }

  //set as flow variables
  flattenAndSetFlowVariables(ctx, "mcp_tool.", toolInfo, '');

  var targetUrl = toolInfo.target["url"];
  var targetPathSuffix = toolInfo.target["pathSuffix"];
  var targetVerb = toolInfo.target["verb"];
  var targetContentType = toolInfo.target.headers["content-type"];
  var targetAccept = toolInfo.target.headers["accept"];
  var requestSchema = toolInfo.schemas["request"];
  var bodyParam = toolInfo.inputParams["body"];
  var headerParams = toolInfo.inputParams["headers"] || [];
  var queryParams = toolInfo.inputParams["query"] || [];
  var pathParams = toolInfo.inputParams["path"] || [];


  //Build the Request Object
  //Set Verb
  ctx.setVariable("message.verb", targetVerb);

  //Set URL
  ctx.setVariable("target.url", createFullUrl(targetUrl, targetPathSuffix, rpc["params"], pathParams, queryParams));

  //Set the Accept request Header
  if (targetAccept) {
    ctx.setVariable("request.header.Accept", targetAccept)
  }

  //Set the Body
  if (targetVerb === "GET") {
    ctx.removeVariable("message.content");
    ctx.removeVariable("message.header.Content-Type");
  } else {
    //post, put, delete, options
    if (targetContentType) {
      ctx.setVariable("request.header.Content-Type", targetContentType);
    }

    var requestBody = _get(rpc, "params.arguments." + bodyParam, null);
    if (requestBody) {
      if (isString(requestBody)) {
        ctx.setVariable("message.content", requestBody)
      } else if (targetContentType === "application/x-www-form-urlencoded") {
        ctx.setVariable("message.content", jsonToFormURLEncoded(requestBody))
      } else if (targetContentType === "application/xml" && requestSchema) {
        ctx.setVariable("message.content", convertJsonToXml(requestBody, requestSchema))
      } else {
        ctx.setVariable("message.content", getPrettyJSON(requestBody))
      }
    } else {
      //clear the message content so that JSON-RPC body is not passed through
      ctx.setVariable("message.content", "");
    }
  }

  //Set Headers
  for (var i = 0; i < headerParams.length; i++) {
    var headerName = headerParams[i]; // e.g., "xRequestId" or "authSecret"
    var headerValue = _get(rpc, "params.arguments." + headerName, null);
    if (headerValue) {
      ctx.setVariable("request.header." + headerName, headerValue)
    }
  }
}

/**
 * Checks if a given MIME type should be treated as a binary resource.
 *
 * @param {string} mimeType The MIME type string to check.
 * @returns {boolean} True if the MIME type is identified as binary, false otherwise.
 */
function isBinaryMimeType(mimeType) {
  if (!isString(mimeType)) {
    return false;
  }

  // Check for generic binary categories first
  var genericBinaryPrefixes = [
    'image/',
    'audio/',
    'video/',
    'font/'
  ];

  for (var i = 0; i < genericBinaryPrefixes.length; i++) {
    if (mimeType.indexOf(genericBinaryPrefixes[i]) === 0) {
      return true;
    }
  }

  // Fast check for common application-specific binary types
  var commonBinaryMimeTypes = [
    'application/octet-stream',
    'application/pdf',
    'application/zip',
    'application/gzip',
    'application/msword',
    'application/vnd.ms-excel',
    'application/vnd.ms-powerpoint',
    'application/x-bzip',
    'application/x-bzip2',
    'application/x-7z-compressed',
    'application/x-tar',
    'application/java-archive'
  ];

  return commonBinaryMimeTypes.indexOf(mimeType) !== -1;
}


/**
 * Processes the response from the target REST service (stored in flow variables) and
 * constructs the standardized JSON-RPC 2.0 response wrapper (the `tools/call` result).
 * Sets the final response flow variables for the proxy.
 *
 * @param {object} ctx The Apigee context object.
 */
function processRESTRes(ctx) {
  var statusCode = parseInt(ctx.getVariable("response.status.code"));
  var content = ctx.getVariable("response.content");
  var contentType = ctx.getVariable("response.header.content-type");
  var base64Content = ctx.getVariable("response.content.as.base64");

  var statusCodePrefix = parseInt(statusCode/100);

  var isError = false;
  if (statusCodePrefix === 4 || statusCodePrefix === 5) {
    isError = true;
  }

  var headers = [["Content-Type", "application/json"]];
  var mcpId = ctx.getVariable("mcp.id");

  var rpcResponse = {
    jsonrpc: "2.0",
    id: mcpId,
    result: {
      isError: isError
      // 'content' will be added below based on type
    }
  };


  //handle binary formats
  if (isString(contentType)) {
    if (contentType.indexOf("image/") === 0) {
      rpcResponse.result.content = [{
        type: "image",
        data: base64Content,
        mimeType: contentType
      }];
    } else if (contentType.indexOf("audio/") === 0) {
      rpcResponse.result.content = [{
        type: "audio",
        data: base64Content,
        mimeType: contentType
      }];
    } else if (isBinaryMimeType(contentType)) {
      // Handle as generic binary resource
      var hash = hashCode(base64Content);
      var fileName = "downloaded-file"; // Generic name

      rpcResponse.result.content = [{
        type: "resource",
        resource: {
          uri: "urn:apigee:mcp:blob:" + hash,
          name: fileName,
          title: "Downloaded File",
          mimeType: contentType,
          blob: base64Content
        }
      }];
    }
  }

  // Fallback to text/json handling
  if (!rpcResponse.result.content) {
    rpcResponse.result.content = [{
      type: "text",
      text: content
    }];
    var jsonResponse = parseJsonString(content, null);
    if (jsonResponse) {
      if (!isPlainObject(jsonResponse)) {
        jsonResponse = {
          result: jsonResponse
        };
      }
      rpcResponse.result.structuredContent = jsonResponse;
    }
  }

  setResponse(ctx, 200, headers,  getPrettyJSON(rpcResponse));
}

/**
 * Validates the structure of the entire mcpToolsInfo object.
 * This is needed in case one manually edits the mcp-tools.cjs file.
 *
 * @param {object} mcpToolsInfo The complete tool definition list.
 * @throws {JsonRPCError} If the structure is invalid.
 */
function validateMcpToolsInfo(mcpToolsInfo) {
  if (!isPlainObject(mcpToolsInfo)) {
    throw new JsonRPCError("Tool configuration failed: mcpToolsInfo must be a non-null object.", JSON_RPC_INTERNAL_ERROR);
  }

  for (var toolName in mcpToolsInfo) {
    if (!mcpToolsInfo.hasOwnProperty(toolName)) continue;

    var tool = mcpToolsInfo[toolName];
    var path = "Tool '" + toolName + "': ";

    if (!isPlainObject(tool)) {
      throw new JsonRPCError(path + "Configuration must be an object.", JSON_RPC_INTERNAL_ERROR);
    }

    // 1. Check required top-level properties (only 'target' is strictly required)
    if (!tool.target) {
      throw new JsonRPCError(path + "Missing required top-level key: target.", JSON_RPC_INTERNAL_ERROR);
    }

    // 2. Validate 'target'
    var target = tool.target;
    if (!isPlainObject(target)) {
      throw new JsonRPCError(path + "target must be an object.", JSON_RPC_INTERNAL_ERROR);
    }

    // Separate checks for required string properties in target for precise errors
    if (typeof target.url !== 'string') {
      throw new JsonRPCError(path + "target is missing required string property: url.", JSON_RPC_INTERNAL_ERROR);
    }
    if (typeof target.pathSuffix !== 'string') {
      throw new JsonRPCError(path + "target is missing required string property: pathSuffix.", JSON_RPC_INTERNAL_ERROR);
    }
    if (typeof target.verb !== 'string') {
      throw new JsonRPCError(path + "target is missing required string property: verb.", JSON_RPC_INTERNAL_ERROR);
    }

    // target.headers is optional. If provided, it must be a plain object with string values.
    if (tool.target.hasOwnProperty('headers')) {
      if (!isPlainObject(target.headers)) {
        throw new JsonRPCError(path + "target.headers must be an object if provided.", JSON_RPC_INTERNAL_ERROR);
      }

      // Validate all values in the headers map are strings
      for (var headerKey in target.headers) {
        if (target.headers.hasOwnProperty(headerKey)) {
          var headerValue = target.headers[headerKey];
          if (typeof headerValue !== 'string') {
            throw new JsonRPCError(path + "All values in target.headers must be strings (Header key: " + headerKey + ").", JSON_RPC_INTERNAL_ERROR);
          }
        }
      }
    }

    // 3. Validate 'schemas' (Optional)
    if (tool.schemas) {
      if (!isPlainObject(tool.schemas)) {
        throw new JsonRPCError(path + "schemas must be an object if provided.", JSON_RPC_INTERNAL_ERROR);
      }

      // Check for the optional 'request' schema field
      if (tool.schemas.request && !isPlainObject(tool.schemas.request)) {
        throw new JsonRPCError(path + "schemas.request must be an object if provided.", JSON_RPC_INTERNAL_ERROR);
      }
    }

    // 4. Validate 'inputParams' (NOW OPTIONAL)
    if (tool.inputParams) {
      var inputParams = tool.inputParams;
      if (!isPlainObject(inputParams)) {
        throw new JsonRPCError(path + "inputParams must be an object if provided.", JSON_RPC_INTERNAL_ERROR);
      }

      // 4a. Validate 'body' (Optional String)
      if (inputParams.hasOwnProperty('body') && typeof inputParams.body !== 'string') {
        throw new JsonRPCError(path + "inputParams.body must be a string if provided.", JSON_RPC_INTERNAL_ERROR);
      }

      // 4b. Validate path, query, headers (Optional Array of Strings)
      var arrayProps = ['path', 'query', 'headers'];

      for (var i = 0; i < arrayProps.length; i++) {
        var propName = arrayProps[i]; // e.g., 'path'

        if (inputParams.hasOwnProperty(propName)) {
          var arr = inputParams[propName];

          if (!Array.isArray(arr)) {
            throw new JsonRPCError(path + "inputParams." + propName + " must be an array if provided.", JSON_RPC_INTERNAL_ERROR);
          }

          // Check array contents: all elements must be strings
          for (var j = 0; j < arr.length; j++) {
            if (typeof arr[j] !== 'string') {
              throw new JsonRPCError(path + "All elements in inputParams." + propName + " array must be strings.", JSON_RPC_INTERNAL_ERROR);
            }
          }
        }
      }
    }
  }

}

/**
 * Filters an MCP `tools/list` response based on the tools allowed in the API Product.
 * It modifies the `response.content` flow variable in place.
 * This is for authorization-based filtering only.
 *
 * @param {object} ctx The Apigee context object.
 */
function filterAuthorizedTools(ctx) {
  var contentStr = ctx.getVariable("response.content");
  var responseRpc = parseJsonString(contentStr, null);

  // Silently exit if the response isn't a valid tools/list response.
  if (!responseRpc || !responseRpc.result || !Array.isArray(responseRpc.result.tools)) {
    return;
  }

  var mcpToolsStr = ctx.getVariable("mcp.authorized_product.tools");

  if (mcpToolsStr && mcpToolsStr.trim() === '*') {
    // Wildcard means no filtering is needed.
    return;
  }

  var allowedTools = [];
  if (mcpToolsStr) {
    allowedTools = mcpToolsStr.split(',').map(function(tool) {
      return tool.trim();
    });
  }

  // If mcpToolsStr is undefined or empty, allowedTools will be empty, correctly filtering out all tools.
  responseRpc.result.tools = responseRpc.result.tools.filter(function(tool) {
    return allowedTools.indexOf(tool.name) >= 0;
  });

  var newContentStr = getPrettyJSON(responseRpc);
  ctx.setVariable("response.content", newContentStr);
}


/**
 * Filters an MCP `tools/list` response based on the `x-mcp-tools-filter` header.
 * It modifies the `response.content` flow variable in place.
 *
 * @param {object} ctx The Apigee context object.
 */
function filterHeaderTools(ctx) {
  var contentStr = ctx.getVariable("response.content");
  var responseRpc = parseJsonString(contentStr, null);

  // Silently exit if the response isn't a valid tools/list response.
  if (!responseRpc || !responseRpc.result || !Array.isArray(responseRpc.result.tools)) {
    return;
  }

  var headerFilterStr = ctx.getVariable("request.header.x-mcp-tools-filter.values.string") || ctx.getVariable("request.header.x-mcp-tools-filter");

  // Only filter if the header is present, a string, and not empty or a wildcard.
  if (!headerFilterStr || !isString(headerFilterStr) || headerFilterStr.trim().length === 0 || headerFilterStr.trim() === '*') {
    return;
  }

  var headerTools = headerFilterStr.split(',').map(function(tool) {
    return tool.trim();
  });

  responseRpc.result.tools = responseRpc.result.tools.filter(function(tool) {
    return headerTools.indexOf(tool.name) >= 0;
  });

  var newContentStr = getPrettyJSON(responseRpc);
  ctx.setVariable("response.content", newContentStr);
}

/**
 * Authorizes an MCP (Media Communications Protocol) request based on the API product configuration.
 * It checks if the called tool is in the list of allowed tools for the API key's associated product.
 * Core methods like 'initialize' and 'ping' are always permitted.
 *
 * @param {object} ctx The Apigee context object.
 * @throws {JsonRPCError} If the request is invalid, unauthorized, or if there's an internal configuration error.
 */
function authorizeMCPReq(ctx) {
  var mcpMethod = ctx.getVariable("mcp.method");
  if (!mcpMethod) {
    throw new JsonRPCError("no MCP method specified", JSON_RPC_INVALID_REQUEST);
  }

  var publicMethods = [
    "initialize", "notifications/initialized", "ping", "resources/list",
    "resources/templates/list", "prompts/list"
  ];

  if (publicMethods.indexOf(mcpMethod) >= 0) {
    return;
  }

  var prefix = "verifyapikey.VAK-Check.";
  var apiProductName = ctx.getVariable(prefix + "apiproduct.name");
  if (!apiProductName) {
    throw new JsonRPCError("no API Product for MCP request", JSON_RPC_UNAUTHORIZED_REQUEST, 403);
  }
  ctx.setVariable("mcp.authorized_product.name", apiProductName);

  var mcpToolsStr = ctx.getVariable(prefix + "apiproduct.mcp_tools");

  // Set the variable for downstream policies if it exists.
  if (isString(mcpToolsStr)) {
    ctx.setVariable("mcp.authorized_product.tools", mcpToolsStr);
  }

  // `tools/list` is a special case: it's always an authorized method call.
  // The filtering logic in a later step will use the variable set above.
  if (mcpMethod === "tools/list") {
    return;
  }

  // For all other protected methods (e.g., tools/call), mcp_tools MUST be defined.
  if (!isString(mcpToolsStr)) {
    throw new JsonRPCError("unauthorized MCP method: " + mcpMethod + ". API product is not configured for MCP tools", JSON_RPC_UNAUTHORIZED_REQUEST, 403);
  }

  if (mcpMethod === "tools/call") {
    var mcpTool = ctx.getVariable("mcp.params.name");
    if (!mcpTool) {
      throw new JsonRPCError("no MCP tool name specified for tools/call", JSON_RPC_INVALID_REQUEST);
    }

    // Check for the explicit wildcard "*"
    if (mcpToolsStr.trim() === '*') {
      return; // Wildcard allows any tool.
    }

    // If not a wildcard, check if the specific tool is in the comma-separated list.
    var allowedTools = mcpToolsStr.split(',').map(function(tool) {
      return tool.trim();
    });

    if (allowedTools.indexOf(mcpTool) < 0) {
      throw new JsonRPCError("unauthorized MCP tools/call: " + mcpTool, JSON_RPC_UNAUTHORIZED_REQUEST, 403);
    }
  }
}


if (!isApigee) {
  module.exports = {
    "flattenAndSetFlowVariables": flattenAndSetFlowVariables,
    "parseJsonRpc": parseJsonRpc,
    "parseMCPReq": parseMCPReq,
    "setResponse": setResponse,
    "setErrorResponse": setErrorResponse,
    "createFullUrl": createFullUrl,
    "createQueryParams": createQueryParams,
    "replacePathParams": replacePathParams,
    "processRESTRes": processRESTRes,
    "processMCPRequest": processMCPRequest,
    "convertJsonToXml": convertJsonToXml,
    "isString": isString,
    "isPlainObject": isPlainObject,
    "getPrettyJSON": getPrettyJSON,
    "parseJsonString": parseJsonString,
    "_get": _get,
    "combinePaths": combinePaths,
    "JsonRPCError": JsonRPCError,
    "getToolInfo": getToolInfo,
    "jsonToFormURLEncoded": jsonToFormURLEncoded,
    "validateMcpToolsInfo": validateMcpToolsInfo,
    "filterAuthorizedTools": filterAuthorizedTools,
    "filterHeaderTools": filterHeaderTools,
    "authorizeMCPReq": authorizeMCPReq,
    "isBinaryMimeType": isBinaryMimeType,
    "JSON_RPC_PARSE_ERROR": JSON_RPC_PARSE_ERROR,
    "JSON_RPC_INVALID_REQUEST": JSON_RPC_INVALID_REQUEST,
    "JSON_RPC_METHOD_NOT_FOUND": JSON_RPC_METHOD_NOT_FOUND,
    "JSON_RPC_INVALID_PARAMS": JSON_RPC_INVALID_PARAMS,
    "JSON_RPC_INTERNAL_ERROR": JSON_RPC_INTERNAL_ERROR,
    "JSON_RPC_UNAUTHORIZED_REQUEST": JSON_RPC_UNAUTHORIZED_REQUEST,
    "JSON_RPC_UNAUTHENTICATED_REQUEST": JSON_RPC_UNAUTHENTICATED_REQUEST
  };
}