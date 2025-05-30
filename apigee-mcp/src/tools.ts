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

/**
 * Defines the structure for a tool that maps to an McpApi method.
 */
export type Tool = {
  /** The corresponding method name in the McpApi class. */
  method: string;
  /** A user-friendly name for the tool. */
  name: string;
  /** A description of what the tool does. */
  description: string;
  /** A Zod schema defining the parameters required by the tool's method. */
  parameters: z.ZodObject<any, any, any, any>;
  /** A category to group related tools. */
  category: string;
};

// =========================
// Parameter Schemas
// =========================

const listProductsParameters = z.object({}); // No parameters

const listProductSpecsParameters = z.object({
  productName: z.string().min(1, "Product name cannot be empty."),
});

const getSpecContentParameters = z.object({
  productName: z.string().min(1, "Product name cannot be empty."),
  specPath: z.string().min(1, "Specification path cannot be empty."),
});

const getAllProductSpecsContentParameters = z.object({}); // No parameters

// =========================
// Tools Definition
// =========================

/**
 * Returns an array of tools representing the available operations in McpApi.
 */
export const tools = (): Tool[] => [
  // =========================
  // Product & Spec Tools
  // =========================
  {
    method: "listProducts",
    name: "List Products",
    description: "Retrieves a list of available API Product names from the MCP.",
    parameters: listProductsParameters,
    category: "products"
  },
  {
    method: "listProductSpecs",
    name: "List Product Specifications",
    description: "Retrieves the list of API specifications (and associated metadata) linked to a specific API Product.",
    parameters: listProductSpecsParameters,
    category: "specs"
  },
  {
    method: "getSpecContent",
    name: "Get Specification Content",
    description: "Retrieves the raw content (e.g., YAML or JSON) of a specific API specification file identified by its product name and path.",
    parameters: getSpecContentParameters,
    category: "content"
  },
  {
    method: "getAllProductSpecsContent",
    name: "Get All Product Specifications Content",
    description: "Retrieves all products, lists their associated specs, and fetches the content for every spec, utilizing an in-memory cache.",
    parameters: getAllProductSpecsContentParameters,
    category: "content"
  }
];