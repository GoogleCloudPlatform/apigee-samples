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
import { z } from "zod";
import yaml from 'js-yaml'; // For parsing OpenAPI specs
import { OpenAPIV3 } from 'openapi-types'; // For OpenAPI type hints
import { RequestHandlerExtra } from "@modelcontextprotocol/sdk/shared/protocol.js";

/**
 * Contains the necessary details for the MCP server to execute the OpenAPI operation.
 * This information is not intended for direct use by the client/LLM.
 */
interface OpenApiExecutionDetails {
  targetServer?: string;
  httpMethod: OpenAPIV3.HttpMethods;
  apiPath: string;
  openapiParameters?: (OpenAPIV3.ReferenceObject | OpenAPIV3.ParameterObject)[];
  openapiRequestBody?: OpenAPIV3.ReferenceObject | OpenAPIV3.RequestBodyObject;
  openIdConnectUrl?: string; // Added field for OpenID Connect URL
}

export type Tool = {
    name: string;
    description: string;
    parameters: z.ZodObject<any, any, any, any>;
    execute: (params: Record<string, any>, extra: RequestHandlerExtra<any, any>) => Promise<any>;
};

export const tools: Tool[] = []
/**
 * Defines the structure for a dynamically generated tool based on an OpenAPI operation.
 * The 'method' field acts as an identifier for the MCP server to execute the call.
 */
export interface OpenApiTool {
  /**
   * A unique identifier for the tool, derived from the OpenAPI operation.
   * Used by the MCP server to identify which API call to make.
   * Example: 'api_myProduct_getUserById'
   */
  method: string;
  /** A user-friendly name for the tool, typically the operation summary. */
  name: string;
  /** A description of what the tool does, from the operation description or summary. */
  description: string;
  /** A Zod schema defining the parameters required by the OpenAPI operation. */
  parameters: z.ZodObject<any, any, any, any>;
  /** The category, based on the API product name. */
  category: string;
  /** The original API product name this tool belongs to. */
  productName: string;
  /** The path of the source OpenAPI spec file. */
  specPath: string;
  /** Internal details needed by the MCP server to execute the API call. */
  executionDetails: OpenApiExecutionDetails;
}

// Helper function to map OpenAPI parameter types to Zod types
function mapOpenApiTypeToZod(schemaOrRef:  OpenAPIV3.ParameterObject | OpenAPIV3.ReferenceObject | OpenAPIV3.SchemaObject,
                             spec: OpenAPIV3.Document,
                             visitedRefs: Set<string> = new Set()
): z.ZodTypeAny {
    //const schemaSource = 'schema' in param ? param.schema : param;
    //if (!schemaSource || isReferenceObject(schemaSource)) {
        // Handle reference objects or missing schema - return z.any() or implement reference resolution
    //    return z.any().describe('Unresolved reference or missing schema');
    //}

    // Assert the type after the check - we know it's a SchemaObject here
    //const schema = schemaSource as OpenAPIV3.SchemaObject;

    // --- Handle ParameterObject wrapper ---
    let isOptional = false;
    let descriptionFromParam: string | undefined = undefined;
    let targetSchemaOrRef: OpenAPIV3.SchemaObject | OpenAPIV3.ReferenceObject;

    // Check if it's a ParameterObject (has 'in' and 'name')
    if ('in' in schemaOrRef && 'name' in schemaOrRef) {
        const param = schemaOrRef as OpenAPIV3.ParameterObject;
        if (!param.schema) {
            // Parameter without schema? Use z.any() with description.
            console.warn(`[OpenAPI Tools] Parameter '${param.name}' has no schema. Using z.any().`);
            let anyType = z.any().describe(param.description || `Parameter ${param.name} with no schema defined`);
            // Apply optionality based on the parameter's required status
            return param.required ? anyType : anyType.optional();
        }
        targetSchemaOrRef = param.schema; // Target the schema within the parameter
        isOptional = !param.required; // Optionality comes from the parameter
        descriptionFromParam = param.description; // Parameter description takes precedence
    } else {
        // It's already a SchemaObject or ReferenceObject
        targetSchemaOrRef = schemaOrRef as OpenAPIV3.SchemaObject | OpenAPIV3.ReferenceObject;
    }
    // --- End ParameterObject wrapper ---

    // --- Handle Reference Resolution ---
    let schema: OpenAPIV3.SchemaObject;
    if (isReferenceObject(targetSchemaOrRef)) {
        const refString = targetSchemaOrRef.$ref;

        // Basic cycle detection
        if (visitedRefs.has(refString)) {
            console.warn(`[OpenAPI Tools] Circular reference detected: ${refString}. Returning z.any() to avoid infinite loop.`);
            // Return a Zod type indicating the circular ref, apply optionality later if needed
            const circularType = z.any().describe(`Circular reference: ${refString}`);
            return isOptional ? circularType.optional() : circularType;
        }

        // Resolve the reference
        const resolved = resolveReference<OpenAPIV3.SchemaObject>(spec, refString);
        if (!resolved) {
            // Failed to resolve, return z.any() with description
            const unresolvedType = z.any().describe(`Unresolved reference: ${refString}`);
            return isOptional ? unresolvedType.optional() : unresolvedType;
        }

        // Add ref to visited set for the recursive call
        const newVisitedRefs = new Set(visitedRefs);
        newVisitedRefs.add(refString);

        // Recursively call with the RESOLVED schema, passing the new visited set
        // The optionality/description from the *original* context (parameter) will be applied *after* this call returns.
        const resolvedType = mapOpenApiTypeToZod(resolved, spec, newVisitedRefs);

        // Apply description (prefer original parameter's if present) and optionality
        const finalDescription = descriptionFromParam || resolved.description; // Use resolved schema's description as fallback
        let finalType = finalDescription ? resolvedType.describe(finalDescription) : resolvedType;
        return isOptional ? finalType.optional() : finalType;

    } else {
        // It was not a reference object to begin with, or was already resolved in a previous step
        schema = targetSchemaOrRef as OpenAPIV3.SchemaObject;
    }
    // --- End Reference Resolution ---

    // --- Core Type Mapping Logic (using the resolved 'schema') ---

    let zodType: z.ZodTypeAny;

    switch (schema.type) {
        case 'string':
            zodType = z.string();
            if (schema.enum) {
                if (schema.enum.every(e => typeof e === 'string')) {
                    const enumValues = schema.enum as [string, ...string[]];
                    if (enumValues.length > 0) {
                        zodType = z.enum(enumValues);
                    } else {
                        console.warn(`[OpenAPI Tools] Empty enum array found for string type. Using z.string(). Schema: ${JSON.stringify(schema)}`);
                   }
                } else {
                    console.warn(`[OpenAPI Tools] Non-string enum values found. Using z.string(). Schema: ${JSON.stringify(schema)}`);
               }
            }
            // Add common format handling
            // Apply format refinements directly to the string type
            if (schema.format === 'date-time') zodType = (zodType as z.ZodString).datetime({ message: "Invalid date-time format" });
            // Note: Zod v3 doesn't have a built-in .date() for strings, you might need a custom regex or refine
            if (schema.format === 'email') zodType = (zodType as z.ZodString).email({ message: "Invalid email format" });
            if (schema.format === 'uuid') zodType = (zodType as z.ZodString).uuid({ message: "Invalid UUID format" });
            // Add minLength, maxLength, pattern if needed
             // Add length and pattern constraints
             if (schema.minLength !== undefined) zodType = (zodType as z.ZodString).min(schema.minLength);
             if (schema.maxLength !== undefined) zodType = (zodType as z.ZodString).max(schema.maxLength);
             if (schema.pattern !== undefined) zodType = (zodType as z.ZodString).regex(new RegExp(schema.pattern)); 
            break;
        case 'integer':
            zodType = z.number().int();
            break;
        case 'number':
            zodType = z.number();
            break;
        case 'boolean':
            zodType = z.boolean();
            break;
        case 'array':
            if (schema.items) {
                 // Recursively map the items' schema, passing the spec and a *new* visited set
                 zodType = z.array(mapOpenApiTypeToZod(schema.items, spec, new Set(visitedRefs)));
                 // Add array constraints
                 if (schema.minItems !== undefined) zodType = (zodType as z.ZodArray<any>).min(schema.minItems);
                 if (schema.maxItems !== undefined) zodType = (zodType as z.ZodArray<any>).max(schema.maxItems);
            } else {
                zodType = z.array(z.any());
            }
            break;
        case 'object':
            if (schema.properties) {
                const shape: z.ZodRawShape = {};
                for (const propName in schema.properties) {
                    // Recursively map properties, passing the spec and a *new* visited set
                    shape[propName] = mapOpenApiTypeToZod(schema.properties[propName], spec, new Set(visitedRefs));
                    // Optionality is determined by the 'required' array of the *object schema itself*
                    if (!schema.required?.includes(propName)) {
                         shape[propName] = shape[propName].optional();
                    }
                }
                zodType = z.object(shape);

                // Handle additionalProperties: allow extra fields if true or specified as a schema
                if (schema.additionalProperties === true) {
                    zodType = (zodType as z.ZodObject<any>).passthrough(); // Allow any other properties
                } else if (typeof schema.additionalProperties === 'object') {
                    // If additionalProperties is a schema, ideally use z.record, but z.object().catchall()
                    // conflicts with defined properties. .passthrough() is a common compromise.
                    console.warn(`[OpenAPI Tools] Object with both properties and schema-defined additionalProperties found. Using z.object().passthrough() for ${schema.title || 'object'}. Validation of additional properties won't use the specific schema.`);
                    zodType = (zodType as z.ZodObject<any>).passthrough();
                } // If false or omitted, Zod's default is strict (no extra properties)
            } else if (schema.additionalProperties) {
                 // Handle map-like objects (additionalProperties)
                 const valueType = typeof schema.additionalProperties === 'object'
                    // Recursively map the value type for the record
                    ? mapOpenApiTypeToZod(schema.additionalProperties, spec, new Set(visitedRefs))
                    : z.any();
                 zodType = z.record(z.string(), valueType);
            }
             else {
                zodType = z.object({});
            }
            break;
        default:
            if (Array.isArray(schema.type)) {
                // OpenAPI 3.1 style type arrays (e.g., ['string', 'null'])
                const nonNullTypes = (schema.type as string[]).filter((t: string) => t !== 'null');
                const zodTypes = nonNullTypes.map((t: string) => {
                    // Create a temporary schema object for each type
                    const tempSchema = { ...schema, type: t as OpenAPIV3.NonArraySchemaObjectType }; // Cast type string
                    // Map recursively, ensuring a new visited set for each branch if needed
                    return mapOpenApiTypeToZod(tempSchema, spec, new Set(visitedRefs));
                });

                if (zodTypes.length === 0 && (schema.type as string[]).includes('null')) {
                    zodType = z.null(); // Only type was 'null'
                } else if (zodTypes.length === 1) {
                    zodType = zodTypes[0]; // Only one non-null type
                } else if (zodTypes.length > 1) {
                    // Create a union of the possible non-null types
                    // Need to cast correctly for z.union signature
                    const unionTypes = zodTypes as [z.ZodTypeAny, z.ZodTypeAny, ...z.ZodTypeAny[]];
                    zodType = z.union(unionTypes);
                } else {
                    // No types found? Should not happen if schema.type was a non-empty array.
                    console.warn(`[OpenAPI Tools] Invalid type array found: ${JSON.stringify(schema.type)}. Using z.any().`);
                    zodType = z.any();
                }

                // If 'null' was in the original array, make the resulting Zod type nullable
                if ((schema.type as string[]).includes('null') && zodType && !(zodType instanceof z.ZodNull)) {
                    // Use z.union([type, z.null()]) for nullable effect in Zod v3
                    zodType = z.union([zodType, z.null()]);
                }

            } else if (!schema.type && (schema.properties || schema.additionalProperties || ('items' in schema && schema.items))) {
                // Type is missing, but structure suggests object or array. Check 'items' safely.
                const inferredType = 'items' in schema && schema.items ? 'array' : 'object';
                console.warn(`[OpenAPI Tools] Missing type for schema ${schema.title || ''}. Inferring type: '${inferredType}'.`);
                // Create temp schema and cast it to satisfy the function signature
                const tempSchema = { ...schema, type: inferredType as OpenAPIV3.NonArraySchemaObjectType | 'array' };
                zodType = mapOpenApiTypeToZod(tempSchema as OpenAPIV3.SchemaObject, spec, new Set(visitedRefs)); // Re-process with inferred type

            } else {
                console.warn(`[OpenAPI Tools] Unknown or missing schema type: '${schema.type}'. Using z.any(). Schema: ${JSON.stringify(schema)}`);
                zodType = z.any();
            }
    }

    // --- Handle OpenAPI 3.0 `nullable: true` ---
    // This should wrap the result of the switch statement. Zod v3 uses z.union([type, z.null()]).
    if (schema.nullable) {
        // Avoid double-wrapping if already handled by type: ['...', 'null'] or if it's already z.null()
        const isAlreadyNullable = (zodType instanceof z.ZodUnion && zodType.options.some((opt: z.ZodTypeAny) => opt instanceof z.ZodNull)) || (zodType instanceof z.ZodNull);
        if (!isAlreadyNullable) {
             zodType = z.union([zodType, z.null()]);
        }
    }

    // --- Apply Description ---
    // Prefer description from ParameterObject if it exists, otherwise use Schema description
    const description = descriptionFromParam || schema.description;
    if (description) {
        zodType = zodType.describe(description);
    }

    // --- Apply Optionality ---
    // Apply .optional() if the context was a non-required ParameterObject
    if (isOptional) {
        // .optional() in Zod means the key can be missing OR the value can be undefined.
        // This aligns well with an optional parameter in OpenAPI.
        return zodType.optional();
    }

    return zodType;
}

/**
 * Resolves a local $ref pointer within the OpenAPI document.
 * Handles basic JSON Pointer syntax like ~1 for / and ~0 for ~.
 * Does not handle external file references.
 *
 * @param spec The root OpenAPI document object.
 * @param ref The $ref string (e.g., '#/components/schemas/User').
 * @returns The resolved object or null if resolution fails.
 */
function resolveReference<T = any>(spec: OpenAPIV3.Document, ref: string): T | null {
    if (!ref.startsWith('#/')) {
        console.warn(`[Resolver] Skipping non-local or invalid reference: ${ref}`);
        return null; // Only handle local references starting with #/
    }

    const path = ref.substring(2).split('/'); // Remove '#/' and split
    let current: any = spec;

    try {
        for (const segment of path) {
            if (current === null || typeof current !== 'object') {
                console.warn(`[Resolver] Invalid path segment encountered while resolving ${ref} at ${segment}`);
                return null;
            }
            // Decode URI component according to JSON Pointer spec (https://tools.ietf.org/html/rfc6901)
            const decodedSegment = decodeURIComponent(segment.replace(/~1/g, '/').replace(/~0/g, '~'));
            if (!(decodedSegment in current)) {
                console.warn(`[Resolver] Reference path not found: ${ref} at segment '${decodedSegment}'`);
                return null;
            }
            current = current[decodedSegment];
        }

        if (current === undefined) {
            console.warn(`[Resolver] Resolved reference ${ref} to undefined.`);
            return null; // Or handle as needed, maybe throw?
        }
        return current as T;
    } catch (error: any) {
        console.error(`[Resolver] Error resolving reference ${ref}: ${error.message}`);
        return null;
    }
}

// Helper to create a unique and valid method name
function sanitizeForMethodName(input: string): string {
    return input
        .replace(/[^a-zA-Z0-9_]+/g, '_')
        .replace(/^_+|_+$/g, '');
}

/** Type guard to check if an object is a ReferenceObject */
function isReferenceObject(obj: any): obj is OpenAPIV3.ReferenceObject {
    return obj && typeof obj === 'object' && '$ref' in obj;
}

/**
 * Generates an array of tools based on the operations found in parsed OpenAPI specs.
 *
 * @param specData - A Map where keys are product names and values are Maps of spec paths to their string content.
 * @returns An array of OpenApiTool objects.
 */
export const generateOpenApiTools = (specData: Map<string, Map<string, string>>): OpenApiTool[] => {
  const dynamicTools: OpenApiTool[] = [];

  specData.forEach((specMap, productName) => {
    specMap.forEach((specContent, specPath) => {
      try {
        const spec = yaml.load(specContent) as OpenAPIV3.Document;

        if (!spec || typeof spec !== 'object' || !spec.paths) {
            console.warn(`[OpenAPI Tools] Skipping spec ${specPath} for product ${productName}: Invalid or missing paths.`);
            return;
        }

        // --- Check for Global OpenID Connect Security Scheme ---
        let globalRequiresOpenIdAuth = false;
        let globalOpenIdConnectUrl: string | undefined = undefined; // Store the URL if found globally
        if (spec.security && spec.components?.securitySchemes) {
            for (const requirement of spec.security) {
                for (const schemeName in requirement) {
                    const scheme = spec.components.securitySchemes[schemeName];
                    if (scheme) {
                        let resolvedScheme = scheme;
                        if (isReferenceObject(scheme)) {
                            resolvedScheme = resolveReference<OpenAPIV3.SecuritySchemeObject>(spec, scheme.$ref) ?? resolvedScheme;
                        }
                        if (!isReferenceObject(resolvedScheme) && resolvedScheme.type === 'openIdConnect') {
                            globalRequiresOpenIdAuth = true;
                            globalOpenIdConnectUrl = resolvedScheme.openIdConnectUrl; // Capture the URL
                            break; // Found one, no need to check further global requirements
                        }
                    }
                }
                if (globalRequiresOpenIdAuth) break; // Exit outer loop too
            }
        }
        // --- End Global Security Scheme Check ---


        const targetServer = spec.servers?.[0]?.url;
        
        for (const apiPath in spec.paths) {
          const pathItem = spec.paths[apiPath];
          if (!pathItem) continue;

          // Combine path-level and operation-level parameters
          const pathParams = pathItem.parameters || [];

          for (const httpMethod in pathItem) {
            if (!Object.values(OpenAPIV3.HttpMethods).includes(httpMethod as OpenAPIV3.HttpMethods)) continue;

            const operation = pathItem[httpMethod as keyof OpenAPIV3.PathItemObject] as OpenAPIV3.OperationObject;
            if (!operation) continue;

            const operationId = operation.operationId; // Use operationId if available for a more stable method name
            const safeMethodNameBase = operationId ? sanitizeForMethodName(operationId) : sanitizeForMethodName(`${httpMethod}_${apiPath}`);
            const dynamicMethodName = `api_${safeMethodNameBase}`;
            const dynamicToolName = operation.summary || `${httpMethod.toUpperCase()} ${apiPath}`;
            const dynamicDescription = operation.description || operation.summary || `Executes ${httpMethod.toUpperCase()} on ${apiPath}`;

            const toolParamsShape: z.ZodRawShape = {};
            const operationParams = operation.parameters || [];
            const allParams = [...pathParams, ...operationParams]; // Path params first, then operation params

            allParams.forEach(paramOrRef => {
                 // Resolve the parameter definition if it's a reference
                 let resolvedParam: OpenAPIV3.ParameterObject | null = null;
                 if (isReferenceObject(paramOrRef)) {
                     resolvedParam = resolveReference<OpenAPIV3.ParameterObject>(spec, paramOrRef.$ref);
                     if (!resolvedParam) {
                         console.warn(`[OpenAPI Tools] Skipping unresolved parameter reference: ${paramOrRef.$ref} in ${dynamicMethodName}`);
                         return; // Skip this parameter
                     }
                 } else {
                     resolvedParam = paramOrRef as OpenAPIV3.ParameterObject;
                 }
 
                 // Now map the resolved parameter (which contains its schema) to a Zod type
                 // The mapOpenApiTypeToZod function handles ParameterObjects internally
                 toolParamsShape[resolvedParam.name] = mapOpenApiTypeToZod(resolvedParam, spec);
            });

            // --- Determine if OpenID Connect is required for this specific operation ---
            let operationRequiresOpenIdAuth = false;
            let foundOpenIdConnectUrl: string | undefined = undefined; // Store URL for this specific operation
            const operationSecurity = operation.security; // Security defined at the operation level

            if (operationSecurity === undefined) {
                // Operation inherits global security
                foundOpenIdConnectUrl = globalOpenIdConnectUrl;
                operationRequiresOpenIdAuth = globalRequiresOpenIdAuth;
            } else if (operationSecurity.length > 0 && spec.components?.securitySchemes) {
                // Operation has specific security requirements, check them
                for (const requirement of operationSecurity) {
                    for (const schemeName in requirement) {
                        const scheme = spec.components.securitySchemes[schemeName];
                        if (scheme) {
                            let resolvedScheme = scheme;
                            if (isReferenceObject(scheme)) {
                                resolvedScheme = resolveReference<OpenAPIV3.SecuritySchemeObject>(spec, scheme.$ref) ?? resolvedScheme;
                            }
                            if (!isReferenceObject(resolvedScheme) && resolvedScheme.type === 'openIdConnect') {
                                operationRequiresOpenIdAuth = true;
                                foundOpenIdConnectUrl = resolvedScheme.openIdConnectUrl; // Capture the URL
                                break; // Found one, no need to check further requirements for this operation
                            }
                        }
                    }
                    if (operationRequiresOpenIdAuth) break; // Exit outer loop too
                }
            }
            // else if operationSecurity.length === 0:
            // Explicitly no security for this operation, operationRequiresOpenIdAuth remains false.
            else {
                // operationSecurity is [], explicitly no auth needed
            }
            // --- End Security Scheme Check ---

            // Process request body
            if (operation.requestBody) {
                const requestBodyOrRef = operation.requestBody;
                let resolvedRequestBody: OpenAPIV3.RequestBodyObject | null = null;

                if (isReferenceObject(requestBodyOrRef)) {
                    resolvedRequestBody = resolveReference<OpenAPIV3.RequestBodyObject>(spec, requestBodyOrRef.$ref);
                    if (!resolvedRequestBody) {
                         console.warn(`[OpenAPI Tools] Skipping unresolved request body reference: ${requestBodyOrRef.$ref} in ${dynamicMethodName}`);
                    }
                } else {
                    resolvedRequestBody = requestBodyOrRef as OpenAPIV3.RequestBodyObject;
                }

                if (resolvedRequestBody) {
                    const requestBodyDesc = resolvedRequestBody.description;
                    const isRequestBodyRequired = resolvedRequestBody.required || false;

                    // Prefer application/json schema
                    const jsonContent = resolvedRequestBody.content?.['application/json'];
                    if (jsonContent?.schema) {
                        const jsonSchemaOrRef = jsonContent.schema;
                        // Map the schema (or reference) to a Zod type
                        let bodyType = mapOpenApiTypeToZod(jsonSchemaOrRef, spec);
                        // Add description from request body or schema (safely accessing schema description)
                        const schemaDescription = jsonContent.schema && !isReferenceObject(jsonContent.schema)
                            ? jsonContent.schema.description
                            : undefined;
                        bodyType = bodyType.describe(requestBodyDesc || schemaDescription || 'Request body payload');
                        // Apply optionality based on request body's required status
                        if (!isRequestBodyRequired) {
                            bodyType = bodyType.optional();
                        }
                        toolParamsShape['body'] = bodyType; // Add to the tool's parameters under the key 'body'
                    } else if (isRequestBodyRequired) {
                        // Warn if required body has no JSON schema
                        console.warn(`[OpenAPI Tools] Required request body for ${dynamicMethodName} does not have an 'application/json' schema. Tool parameter 'body' might accept 'any' or be missing.`);
                        // Optionally add z.any() for required non-JSON bodies
                        // toolParamsShape['body'] = z.any().describe(requestBodyDesc || 'Request body (non-JSON or missing schema)');
                    }
                }
            }

            // --- Add Optional Authorization Header if OpenID Connect is used ---
            if (operationRequiresOpenIdAuth) {
                toolParamsShape['X-User-Authorization'] = z.string()
                    .optional()
                    .describe('Optional: Provide a Bearer token for OpenID Connect authentication (e.g., "Bearer <token>"). If not provided, the system will attempt to use its configured credentials.');
            }
            // --- End Add Authorization Header ---

            dynamicTools.push({
              method: dynamicMethodName,
              name: dynamicToolName,
              description: dynamicDescription,
              parameters: z.object(toolParamsShape),
              category: `api_${productName}`,
              productName: productName,
              specPath: specPath,
              executionDetails: {
                targetServer: targetServer,
                httpMethod: httpMethod as OpenAPIV3.HttpMethods,
                apiPath: apiPath,
                openapiParameters: allParams, // Store original params (refs or objects) for executor
                openapiRequestBody: operation.requestBody, // Store original request body (ref or object) for executor
                openIdConnectUrl: foundOpenIdConnectUrl // Add the found URL (will be undefined if not applicable)
              }
            });
          }
        }
      } catch (parseError: any) {
        console.error(`[OpenAPI Tools] Failed to parse/process spec ${specPath} for product ${productName}: ${parseError.message}`);
      }
    });
  });

  console.log(`[OpenAPI Tools] Generated ${dynamicTools.length} dynamic API operation tools.`);
  return dynamicTools;
};