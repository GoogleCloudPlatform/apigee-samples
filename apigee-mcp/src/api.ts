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
import axios, { AxiosRequestConfig, AxiosResponse } from "axios";

// --- Type Definitions based on OpenAPI Schema ---

export interface AccessToken {
  access_token: string;
  token_type: string; // Typically 'Bearer'
  expires_in?: number; // Optional in response, but useful
  issued_at?: number; // Optional in response
}

export interface ProductList {
  Products: {
    Name: string | string[];
  };
}

export interface Attribute {
  Name: string;
  Value: string;
}

export interface OperationConfig {
  apiSource: string;
  attributes: Attribute[];
  operations: {
    resource: string;
  };
  quota: {
    Interval: string;
    Limit: string;
    TimeUnit: string;
  };
}

export interface SpecList {
  Specs: {
    operationConfigs: OperationConfig | OperationConfig[];
    SpecLocation: string;
  };
}

// Represents the potential structure of error responses
export interface ApiError {
  code?: number;
  message?: string;
  status?: string;
  error?: string; // OAuth specific
  error_description?: string; // OAuth specific
  // Allow any other properties potentially returned
  [key: string]: any;
}

// --- Cache and Method Return Types ---

interface SpecCacheEntry {
  content: string;
  expiry: number;
}

// --- API Client Configuration ---

export interface McpApiOptions {
  baseUrl?: string;
  clientId?: string;
  clientSecret?: string;
}
export interface McpApiOptions {
  baseUrl?: string;
  clientId?: string;
  clientSecret?: string;
  /** Cache Time-To-Live for spec content in milliseconds. Defaults to 5 minutes (300000ms). Set to 0 to disable caching. */
  cacheTTL?: number;
}


// --- MCP API Client Class ---

export class McpApi {
  private baseUrl: string;
  private clientId: string;
  private clientSecret: string;
  private accessToken: string | null = null;
  private tokenExpiry: number | null = null; // Store expiry time (timestamp)
  private specCache: Map<string, SpecCacheEntry>; // Cache key: "productName/specPath"
  private cacheTTL: number; // Cache TTL in milliseconds

  constructor(options: McpApiOptions = {}) {
    this.baseUrl = options.baseUrl || process.env.MCP_BASE_URL || "http://0.0.0.0:8998/mcp"; // Default from spec
    this.clientId = options.clientId || process.env.MCP_CLIENT_ID || "";
    this.clientSecret = options.clientSecret || process.env.MCP_CLIENT_SECRET || "";

    // Default cache TTL to 5 minutes if not provided or negative, 0 disables cache
    this.cacheTTL = options.cacheTTL === undefined || options.cacheTTL < 0 ? 300000 : options.cacheTTL;
    this.specCache = new Map<string, SpecCacheEntry>();

    if (!this.clientId || !this.clientSecret) {
      console.warn(
        "Warning: MCP_CLIENT_ID or MCP_CLIENT_SECRET not provided via options or environment variables. Token acquisition will fail."
      );
    }
  }

  public getBaseUrl(): string {
    return this.baseUrl;
  }

  /**
   * Retrieves a valid access token, fetching a new one if necessary.
   * Handles the OAuth2 Client Credentials flow.
   */
  public async getValidAccessToken(): Promise<string> {
    // Check if current token is still valid (with a small buffer)
    const bufferSeconds = 30; // Get new token 30s before expiry
    if (this.accessToken && this.tokenExpiry && Date.now() < this.tokenExpiry - bufferSeconds * 1000) {
      return this.accessToken;
    }

    // Fetch a new token
    console.debug("Fetching new MCP access token...");
    const tokenUrl = `${this.baseUrl}/token`;
    const requestBody = new URLSearchParams();
    requestBody.append('grant_type', 'client_credentials');

    try {
      const config: AxiosRequestConfig = {
        method: "POST",
        url: tokenUrl,
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "Accept": "application/json",
        },
        // Axios handles Basic Auth encoding
        auth: {
          username: this.clientId,
          password: this.clientSecret,
        },
        data: requestBody,
      };

      const response: AxiosResponse<AccessToken> = await axios(config);
      const tokenData = response.data;

      if (!tokenData.access_token) {
        throw new Error("Received invalid token response from /token endpoint.");
      }

      this.accessToken = tokenData.access_token;
      // Calculate expiry timestamp if expires_in is provided
      this.tokenExpiry = tokenData.expires_in
        ? Date.now() + tokenData.expires_in * 1000
        : null; // If no expires_in, we can't cache based on time

      console.debug("Successfully obtained MCP access token.");
      return this.accessToken;

    } catch (error: any) {
      console.error("Error fetching MCP access token:", error.message);
      this.accessToken = null; // Invalidate token on error
      this.tokenExpiry = null;

      if (error.response) {
        const status = error.response.status;
        const errorData = error.response.data as ApiError;
        const errorDetails = errorData?.message || errorData?.error_description || JSON.stringify(errorData);
        throw new Error(`Token Error (Status ${status}): ${errorDetails}`);
      } else if (error.request) {
        throw new Error("Network Error: No response received from MCP /token endpoint.");
      } else {
        throw new Error(`Token Request Error: ${error.message}`);
      }
    }
  }

  /**
   * Makes authenticated requests to the MCP API with consistent error handling.
   * Automatically handles fetching/refreshing the Bearer token.
   */
  async makeRequest<T>(endpoint: string, method: "GET" | "POST" | "PUT" | "DELETE" = "GET", data: any = null): Promise<T> {
    try {
      const token = await this.getValidAccessToken();
      const url = `${this.baseUrl}${endpoint}`;
      console.debug(`Making MCP API request: ${method} ${url}`);

      const headers: Record<string, string> = {
        "Authorization": `Bearer ${token}`,
        "Accept": "application/json", // Default accept type
      };

      if (data && (method === "POST" || method === "PUT")) {
          headers["Content-Type"] = "application/json";
      }

      const config: AxiosRequestConfig = {
        method,
        url,
        headers,
        data: data ? data : undefined,
      };

      const response = await axios(config);
      console.debug(`Received response with status: ${response.status}`);
      // Special case for spec content which might not be JSON
      if (response.headers['content-type']?.includes('yaml') || response.headers['content-type']?.includes('text')) {
          return response.data as T; // Return raw string/data
      }
      return response.data as T;

    } catch (error: any) {
      console.error("MCP API request error:", error.message);

      if (error.response) {
        const status = error.response.status;
        const errorData = error.response.data as ApiError;
        let errorMessage = `MCP API Error (Status ${status})`;

        // Try to extract a meaningful message from the error response
        const details = errorData?.message || errorData?.error || JSON.stringify(errorData);
        if (details) {
            errorMessage += `: ${details}`;
        }

        // Handle potential token expiry/invalidity specifically
        if (status === 401) {
            console.warn("Received 401 Unauthorized. Invalidating cached token.");
            this.accessToken = null; // Force re-fetch on next request
            this.tokenExpiry = null;
            errorMessage += " (Token might be expired or invalid)";
        }

        throw new Error(errorMessage);
      } else if (error.request) {
        throw new Error("Network Error: No response received from MCP API. Check connection and base URL.");
      } else {
        // Error setting up the request
        throw new Error(`Request Setup Error: ${error.message}. Check request parameters.`);
      }
    }
  }

  // --- API Methods based on OpenAPI Paths ---

  /**
   * Retrieves a list of available API Product names.
   * Corresponds to: GET /products
   */
  async listProducts(): Promise<ProductList> {
    return this.makeRequest<ProductList>("/products", "GET");
  }

  /**
   * Retrieves the list of API specifications (and associated metadata) linked to a specific API Product.
   * Corresponds to: GET /products/{productName}/specs
   * @param productName The name of the API Product.
   */
  async listProductSpecs(productName: string): Promise<SpecList> {
    if (!productName) {
        throw new Error("productName is required for listProductSpecs");
    }
    const encodedProductName = encodeURIComponent(productName);
    return this.makeRequest<SpecList>(`/products/${encodedProductName}/specs`, "GET");
  }

  /**
   * Retrieves the raw content of a specific API specification file identified by its path.
   * Corresponds to: GET /products/{productName}/specs/{specPath}
   * @param productName The name of the API Product.
   * @param specPath The full resource path of the specification (e.g., projects/PROJECT_ID/locations/LOCATION/apis/API_ID/versions/VERSION_ID/specs/SPEC_ID).
   * @returns The raw spec content (likely YAML or JSON as a string).
   */
  async getSpecContent(productName: string, specPath: string): Promise<string> {
     if (!productName) {
        throw new Error("productName is required for getSpecContent");
    }
     if (!specPath) {
        throw new Error("specPath is required for getSpecContent");
    }
    // Note: specPath can contain slashes. encodeURIComponent handles them correctly for path segments.
    const encodedProductName = encodeURIComponent(productName);
    //const encodedSpecPath = encodeURIComponent(specPath); // Ensure the whole path segment is encoded

    // We expect raw content (string) here based on the OpenAPI spec example responses (text/yaml)
    return this.makeRequest<string>(`/products/${encodedProductName}/specs/${specPath}`, "GET");
  }

  /**
   * Retrieves the raw content of a specific API specification file, utilizing an in-memory cache.
   * @param productName The name of the API Product.
   * @param specPath The full resource path of the specification.
   * @returns The raw spec content (likely YAML or JSON as a string).
   */
  private async getSpecContentWithCache(productName: string, specPath: string): Promise<string> {
    const cacheKey = `${productName}::${specPath}`; // Use a clear separator

    // Check cache only if TTL > 0
    if (this.cacheTTL > 0) {
        const cachedEntry = this.specCache.get(cacheKey);
        if (cachedEntry && Date.now() < cachedEntry.expiry) {
            console.debug(`Cache hit for spec: ${cacheKey}`);
            return cachedEntry.content;
        } else if (cachedEntry) {
            console.debug(`Cache expired for spec: ${cacheKey}`);
            this.specCache.delete(cacheKey); // Remove expired entry
        } else {
            console.debug(`Cache miss for spec: ${cacheKey}`);
        }
    }

    // Fetch from API if not cached, expired, or caching disabled
    const content = await this.getSpecContent(productName, specPath);

    // Store in cache only if TTL > 0
    if (this.cacheTTL > 0) {
        const expiry = Date.now() + this.cacheTTL;
        this.specCache.set(cacheKey, { content, expiry });
        console.debug(`Cached spec: ${cacheKey} until ${new Date(expiry).toISOString()}`);
    }

    return content;
  }

  /**
   * Retrieves all products, their associated specs, and the content of each spec.
   * Spec content is cached in memory based on the configured `cacheTTL`.
   * @returns A Promise resolving to a Map where keys are product names and values are Maps
   *          of spec paths to their string content.
   *          Example: Map<"product-a", Map<"path/to/spec1", "spec-content-1">>
   */
  async getAllProductSpecsContent(): Promise<Map<string, Map<string, string>>> {
    const allSpecsContent = new Map<string, Map<string, string>>();
    console.log("Starting retrieval of all product specs content...");

    const productList = await this.listProducts();
    const productNames = productList.Products?.Name ?? [];
    let productNamesFinal: string [];
    if (!Array.isArray(productNames)) {
      productNamesFinal = [productNames];
    } else {
      productNamesFinal = productNames;
    }
    console.log(`Found ${productNamesFinal.length} products.`);

    for (const productName of productNamesFinal) {
      console.log(`Processing product: ${productName}`);
      const productSpecMap = new Map<string, string>();
      allSpecsContent.set(productName, productSpecMap);

      try {
        const specList = await this.listProductSpecs(productName);
        const configs = specList.Specs?.operationConfigs ?? [];
        let configsFinal: OperationConfig[];
        if(!Array.isArray(configs)){
          configsFinal = [configs];
        } else {
          configsFinal = configs;
        }
        const specLocation = specList.Specs?.SpecLocation;

        if (!specLocation) {
            console.warn(`Skipping specs for product "${productName}": Missing SpecLocation.`);
            continue;
        }

        console.log(` Found ${configsFinal.length} operation configs for product "${productName}".`);

        for (const config of configsFinal) {
          // Reconstruct the spec path using attributes as shown in the example usage
          const hubApiAttr = config.attributes.find(a => a.Name === 'hub_api');
          const hubVersionAttr = config.attributes.find(a => a.Name === 'hub_version');
          const hubSpecAttr = config.attributes.find(a => a.Name === 'hub_spec');

          if (hubApiAttr?.Value && hubVersionAttr?.Value && hubSpecAttr?.Value) {
            const specPath = `${specLocation}/apis/${hubApiAttr.Value}/versions/${hubVersionAttr.Value}/specs/${hubSpecAttr.Value}`;
            console.debug(` Fetching content for spec path: ${specPath}`);
            const content = await this.getSpecContentWithCache(productName, specPath);
            productSpecMap.set(specPath, content);
          } else {
            console.warn(` Could not construct spec path for an operationConfig in product "${productName}". Missing attributes.`);
          }
        }
      } catch (error: any) {
        console.error(`Failed to process specs for product "${productName}": ${error.message}`);
        // Continue to the next product even if one fails
      }
    }

    console.log("Finished retrieving all product specs content.");
    return allSpecsContent;
  }
}