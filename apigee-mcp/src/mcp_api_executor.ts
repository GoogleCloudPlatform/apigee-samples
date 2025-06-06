/**
 * Copyright 2024 Google LLC
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
import axios, { AxiosRequestConfig, Method } from 'axios';
import { OpenAPIV3 } from 'openapi-types';

/**
 * Represents the input for executing an OpenAPI tool.
 */
export interface ExecuteOpenApiToolInput {
  /** The unique method identifier of the tool to execute (e.g., 'api_myProduct_getUserById'). */
  method: string;
  /** The parameters provided for the tool invocation, validated against the tool's Zod schema. */
  parameters: Record<string, any>;
  /** A function to retrieve the authentication token or headers needed for the target API. */
  getAuthenticationHeaders: () => Promise<Record<string, string>>; // Example: returns { 'Authorization': 'Bearer ...' }

  executionDetails: any;
}

/**
 * Executes an API call defined by an OpenApiTool.
 *
 * @param input - The necessary information to execute the tool.
 * @returns The response data from the target API.
 * @throws Error if the tool is not found, required details are missing, or the API call fails.
 */
export const executeOpenApiTool = async (input: ExecuteOpenApiToolInput): Promise<any> => {
  const { method, parameters, getAuthenticationHeaders, executionDetails } = input;

  // 1. Handle direct return value tools first
  if (executionDetails.isDirectReturnValue) {
    console.log(`[API Executor] Tool '${method}' is a direct return value tool. Returning predefined data.`);
    return {
      content: [
        {
          type: "text",
          text: executionDetails.directReturnValue,
        },
      ],
    };
  }

  // 2. Retrieve execution details
  const { targetServer, httpMethod, apiPath, openapiParameters = [], openapiRequestBody } = executionDetails;

  // Validate required fields for an actual API call
  if (!targetServer) {
    throw new Error(`Target server URL is missing for tool '${method}'.`);
  }
  if (!httpMethod) {
    throw new Error(`HTTP method is missing for tool '${method}'. This should be set for non-direct return tools.`);
  }
  if (!apiPath) {
    throw new Error(`API path is missing for tool '${method}'. This should be set for non-direct return tools.`);
  }


  // 3. Construct the HTTP Request
  let url = `${targetServer}${apiPath}`;
  const queryParams: Record<string, any> = {};
  const headers: Record<string, string> = {
    'Content-Type': 'application/json', // Default, might be overridden by spec
    'Accept': 'application/json',       // Default, might be overridden by spec
  };
  let requestBody: any = undefined;

  // --- Process parameters based on OpenAPI definition ---

  // Separate parameters based on their 'in' location (path, query, header)
  openapiParameters.forEach((paramOrRef: OpenAPIV3.ReferenceObject | OpenAPIV3.ParameterObject) => {
    // Basic handling: assumes parameters are not $ref objects here,
    if ('$ref' in paramOrRef) {
        console.warn(`Skipping unresolved parameter reference: ${paramOrRef.$ref} during execution of ${method}`);
        return;
    }

    const param = paramOrRef as OpenAPIV3.ParameterObject;
    const paramName = param.name;
    const paramValue = parameters[paramName];

    if (paramValue === undefined && param.required) {
        console.warn(`Required parameter '${paramName}' is missing for tool '${method}'. API might reject.`);
        // Depending on strictness, you might throw an error here
        // throw new Error(`Required parameter '${paramName}' is missing for tool '${method}'.`);
    }

    if (paramValue !== undefined) {
      switch (param.in) {
        case 'path':
          // Replace path placeholders like {userId}
          url = url.replace(`{${paramName}}`, encodeURIComponent(String(paramValue)));
          break;
        case 'query':
          queryParams[paramName] = paramValue;
          break;
        case 'header':
          headers[paramName] = String(paramValue);
          break;
        // 'cookie' parameters are less common for server-to-server calls and ignored here
      }
    }
  });

  // --- Process request body ---
  if (parameters.body) {
    requestBody = parameters.body;
    // Potentially check openapiRequestBody for content type if needed
    // const contentType = Object.keys(openapiRequestBody?.content ?? {})[0] || 'application/json';
    // headers['Content-Type'] = contentType;
  } else if (openapiRequestBody && (openapiRequestBody as OpenAPIV3.RequestBodyObject).required) {
     console.warn(`Required request body is missing for tool '${method}'. API might reject.`);
     // Depending on strictness, you might throw an error here
     // throw new Error(`Required request body is missing for tool '${method}'.`);
  }

  // 4. Apply Authentication
  const authHeaders = await getAuthenticationHeaders();
  Object.assign(headers, authHeaders); // Merge auth headers

  // 5. Execute the Request using axios
  const config: AxiosRequestConfig = {
    method: httpMethod as Method, // Cast to Axios's Method type
    url: url,
    headers: headers,
    params: queryParams,
    data: requestBody,
  };

  console.log(`[API Executor] Executing tool '${method}': ${config.method} ${config.url}`);
  // console.debug("[API Executor] Request Config:", config); // Optional: Log full config for debugging

  try {
    const response = await axios(config);
    // 6. Return the response data
    console.log(`[API Executor] Tool '${method}' executed successfully.`);
    return {
      content: [
        {
          type: "text",
           //Stringify the result for text output
          text: JSON.stringify(response.data)
        }
      ]
    };
  } catch (error: any) {
    console.error(`[API Executor] Error executing tool '${method}':`, error.message);
    if (axios.isAxiosError(error) && error.response) {
      console.error(`[API Executor] API Response Status: ${error.response.status}`);
      console.error(`[API Executor] API Response Data:`, error.response.data);
      return {
        content: [
          {
            type: "text",
             //Stringify the result for text output
            text: JSON.stringify(error.response.data)
          }
        ],
        isError: true
      };
    }
    // Re-throw original error if it's not an Axios error or has no response
    throw error;
  }
};