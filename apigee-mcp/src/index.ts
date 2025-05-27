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
import express from "express";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { RequestHandlerExtra } from "@modelcontextprotocol/sdk/shared/protocol.js";
import { McpApi, McpApiOptions } from "./api.js";
import { SSEServerTransport } from "@modelcontextprotocol/sdk/server/sse.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { generateOpenApiTools, OpenApiTool, tools } from "./openapi_tools.js";
import { executeOpenApiTool } from "./mcp_api_executor.js";

import type { ExecuteOpenApiToolInput } from "./mcp_api_executor.js";

/**
 * Main MCP server class for the custom MCP API integration.
 */
class ApiProductMcpServer extends McpServer {
  private api: McpApi;
  private openApiTools: OpenApiTool[] = []; // Store generated tools

  constructor(options: McpApiOptions = {}) {
    super({
      name: "api-product-mcp",
      version: "1.0.0",
      description: "Tools for interacting with the API Product and Specification MCP API."
    });

    // Initialize the API client using provided options or environment variables
    this.api = new McpApi({
      baseUrl: options.baseUrl || process.env.MCP_BASE_URL,
      clientId: options.clientId || process.env.MCP_CLIENT_ID,
      clientSecret: options.clientSecret || process.env.MCP_CLIENT_SECRET,
      cacheTTL: options.cacheTTL !== undefined
        ? options.cacheTTL
        : process.env.MCP_CACHE_TTL
          ? parseInt(process.env.MCP_CACHE_TTL, 10)
          : undefined // Use default TTL in McpApi if not specified
    });
  }

  /**
   * Fetches specs, generates OpenAPI tools, and registers them with the MCP server.
   * This method should be called after the server is instantiated.
   */
  async initialize() {
    console.log("Initializing ApiProductMcpServer: Fetching specs and generating tools...");
    try {
      const specData = await this.api.getAllProductSpecsContent();
      this.openApiTools = generateOpenApiTools(specData);

      // Register the dynamically generated tools
      this._registerDynamicTools();

      console.log("ApiProductMcpServer initialized successfully.");

    } catch (error) {
      console.error("Failed to initialize ApiProductMcpServer:", error);
      throw error; 
    }
  } 

  /**
   * Registers the dynamically generated OpenAPI tools with the MCP server.
   */
  private _registerDynamicTools() {
    if (this.openApiTools.length === 0) {
      console.warn("No dynamic OpenAPI tools were generated or found to register.");
      return;
    }

    console.log(`Registering ${this.openApiTools.length} dynamic OpenAPI tools...`);
    this.openApiTools.forEach(tool => {
      this.tool(
        tool.method,
        tool.description,
        tool.parameters.shape, // Zod schema from the tool definition
        async (params: any, _extra: RequestHandlerExtra<any, any>) => {
          console.log(`Executing dynamic tool: ${tool.name} (${tool.method}) with params:`, params);

          // Determine how to get authentication headers
          const getAuthHeaders = async (): Promise<Record<string, string>> => {

            // Otherwise (not OpenID or no user token provided), use the server's configured credentials
            console.log(`Using server-configured credentials for ${tool.method}.`);
            const token = await this.api.getValidAccessToken(); // Fetch token using client credentials
            return { 'Authorization': `Bearer ${token}` };
          };

          const executionInput: ExecuteOpenApiToolInput = {
            method: tool.method, // The specific OpenAPI operationId or similar identifier
            parameters: params,
            getAuthenticationHeaders: getAuthHeaders,
            executionDetails: tool.executionDetails
          };
          return await executeOpenApiTool(executionInput);
        }
      );
    });
    console.log("Dynamic OpenAPI tools registered successfully.");
  }
} // <-- Closing brace for ApiProductMcpServer class

/**
 * Main function to run the server.
 */
async function main() {
  // Read configuration from environment variables
  const clientId = process.env.MCP_CLIENT_ID;
  const clientSecret = process.env.MCP_CLIENT_SECRET;
  const mcpMode = process.env.MCP_MODE?.toUpperCase() || 'STDIO'; // Default to STDIO if empty or not set

  // Validate required credentials
  if (!clientId || !clientSecret) {
    console.error("Error: MCP_CLIENT_ID and MCP_CLIENT_SECRET environment variables must be set.");
    process.exit(1); // Exit if credentials are missing
  }

  // Create server instance (reads config from environment variables or uses defaults)
  const server = new ApiProductMcpServer();

  if (mcpMode === 'STDIO') {
    console.log("MCP_MODE is STDIO or not set, running in STDIO mode.");
    // Initialize the server (fetches specs, generates/registers tools)
    // Initialization requires credentials.
    // Note: Initialization might fail if credentials are required for spec fetching.
    try {
      await server.initialize();
    } catch (initError) {
       console.warn("Server initialization failed in STDIO mode (might be expected if credentials are required for spec fetching):", initError);
       // Continue without dynamic tools if initialization fails
    }

    const transport = new StdioServerTransport();
    await server.connect(transport);
    console.error("API Product MCP Server is running in STDIO mode...");

  } else if (mcpMode === 'SSE') {
    console.log("MCP_MODE is SSE, running in SSE mode.");
    const base_path = process.env.BASE_PATH || "mcp-proxy";

    // Initialize the server (fetches specs, generates/registers tools)
    await server.initialize(); // Initialization requires credentials, so it should work here.

    const app = express();
    let transport: SSEServerTransport | null = null;

    app.get(`/${base_path}/sse`, (req, res) => {
      transport = new SSEServerTransport(`/${base_path}/messages`, res);
      server.connect(transport);
    });

    app.post(`/${base_path}/messages`, (req, res) => { 
      if (transport) {
        transport.handlePostMessage(req, res);
      } else {
        res.status(400).send("SSE transport not initialized. Connect to /sse first.");
      }
    });

    const port = process.env.PORT || 3000;
    app.listen(port, () => {
      console.log(`API Product MCP Server listening on port ${port}`);
      console.log(`SSE endpoint available at http://localhost:${port}/${base_path}/sse`);
      console.log(`POST messages endpoint available at http://localhost:${port}/${base_path}/messages`);
      console.error("API Product MCP Server is running in SSE mode..."); // Log running state
    });
  } else {
    console.error(`Error: Invalid MCP_MODE specified: '${process.env.MCP_MODE}'. Must be 'SSE' or 'STDIO' (or unset for STDIO).`);
    process.exit(1);
  }
}

// Run the server
main().catch((error) => {
  console.error("Server initialization error:", error);
  process.exit(1);
});