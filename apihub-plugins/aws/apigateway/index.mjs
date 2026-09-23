// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Real-time AWS API Gateway sync Lambda.
//
// Consumes AWS EventBridge events for API Gateway v1 (REST) and v2
// (HTTP/WebSocket), re-fetches the affected API's current state, and
// publishes to API hub's :collectApiData endpoint. Authenticates to
// GCP via Workload Identity Federation using node:crypto stdlib only;
// zero npm dependencies, deployable via Lambda Console paste.

import { createHash, createHmac } from "node:crypto";
import {
  APIGatewayClient,
  GetRestApiCommand,
  GetStagesCommand,
  GetDeploymentCommand,
  GetExportCommand,
} from "@aws-sdk/client-api-gateway";
import {
  ApiGatewayV2Client,
  GetApiCommand,
  GetStagesCommand as GetStagesV2Command,
  GetRoutesCommand,
  ExportApiCommand,
} from "@aws-sdk/client-apigatewayv2";

// ---------------------------------------------------------------------
// Env vars and derived globals
// ---------------------------------------------------------------------

const APIHUB_HOST = requireEnv("APIHUB_HOST");
const PROJECT = requireEnv("PROJECT");
const LOCATION = requireEnv("LOCATION");
const PLUGIN_ID = requireEnv("PLUGIN_ID");
const PLUGIN_INSTANCE_ID = requireEnv("PLUGIN_INSTANCE_ID");
const WIF_AUDIENCE = requireEnv("WIF_AUDIENCE");
const WIF_SA_EMAIL = requireEnv("WIF_SA_EMAIL");
const AWS_REGION = process.env.AWS_REGION || "us-east-1";
const DETAIL_CONCURRENCY = parseInt(process.env.DETAIL_CONCURRENCY || "5", 10);
const ACTION_ID = process.env.ACTION_ID || "sync-metadata";
const TOKEN_REFRESH_BUFFER_SECONDS = parseInt(
  process.env.TOKEN_REFRESH_BUFFER_SECONDS || "300",
  10,
);

const COLLECT_URL =
  `${APIHUB_HOST}/v1/projects/${PROJECT}/locations/${LOCATION}:collectApiData`;
const PLUGIN_INSTANCE =
  `projects/${PROJECT}/locations/${LOCATION}/plugins/${PLUGIN_ID}/instances/${PLUGIN_INSTANCE_ID}`;
const LOCATION_NAME = `projects/${PROJECT}/locations/${LOCATION}`;

function requireEnv(name) {
  const v = process.env[name];
  if (!v) throw new Error(`${name} env var is required`);
  return v;
}

// ---------------------------------------------------------------------
// Attribute name constants (match production plugin_service attributes)
// ---------------------------------------------------------------------

const ATTR_API_TAGS = attrRef("plugin-aws-api-tags");
const ATTR_ENDPOINT_TYPE = attrRef("plugin-aws-endpoint-type");
const ATTR_STAGE_TAGS = attrRef("plugin-aws-stage-tags");
const ATTR_STAGE_VARIABLES = attrRef("plugin-aws-stage-variables");
const ATTR_API_STYLE = attrRef("system-api-style");
const ATTR_DEPLOYMENT_TYPE = attrRef("system-deployment-type");
const ATTR_MANAGEMENT_URL = attrRef("system-management-url");
const ATTR_SPEC_TYPE = attrRef("system-spec-type");

const API_STYLE_ALLOWED_VALUE = {
  REST: "rest",
  HTTP: "http",
  WEBSOCKET: "websocket",
};
const DEPLOYMENT_TYPE_ALLOWED_VALUE = "aws-api-gateway";
const SPEC_TYPE_OPENAPI = "openapi";

// Single synthetic Version per API. All stages roll up as Deployments
// under this one version.
const SYNTHETIC_VERSION_ID = "1";
const SYNTHETIC_VERSION_DISPLAY_NAME = "1";

function attrRef(id) {
  return `projects/${PROJECT}/locations/${LOCATION}/attributes/${id}`;
}

// ---------------------------------------------------------------------
// Concurrency semaphore (bounds per-invocation stage parallelism).
// ---------------------------------------------------------------------

class Semaphore {
  constructor(capacity) {
    this.capacity = capacity;
    this.active = 0;
    this.waiters = [];
  }

  async acquire() {
    if (this.active < this.capacity) {
      this.active++;
      return;
    }
    await new Promise((resolve) => this.waiters.push(resolve));
    this.active++;
  }

  release() {
    this.active--;
    const next = this.waiters.shift();
    if (next) next();
  }
}

async function runWithLimit(sem, task) {
  await sem.acquire();
  try {
    return await task();
  } finally {
    sem.release();
  }
}

// ---------------------------------------------------------------------
// Cached AWS clients (per region)
// ---------------------------------------------------------------------

const v1Clients = new Map();
const v2Clients = new Map();

function v1Client(region) {
  if (!v1Clients.has(region)) v1Clients.set(region, new APIGatewayClient({ region }));
  return v1Clients.get(region);
}
function v2Client(region) {
  if (!v2Clients.has(region)) v2Clients.set(region, new ApiGatewayV2Client({ region }));
  return v2Clients.get(region);
}

// ---------------------------------------------------------------------
// WIF token exchange (AWS SigV4 -> Google STS -> SA impersonation)
// ---------------------------------------------------------------------

const GOOGLE_STS_URL = "https://sts.googleapis.com/v1/token";
const IAM_CREDENTIALS_URL = "https://iamcredentials.googleapis.com/v1";
const GRANT_TYPE_TOKEN_EXCHANGE =
  "urn:ietf:params:oauth:grant-type:token-exchange";
const REQUESTED_TOKEN_TYPE_ACCESS =
  "urn:ietf:params:oauth:token-type:access_token";
const SUBJECT_TOKEN_TYPE_AWS =
  "urn:ietf:params:aws:token-type:aws4_request";
const CLOUD_PLATFORM_SCOPE = "https://www.googleapis.com/auth/cloud-platform";

let cachedToken = null;
let cachedTokenExpiresAt = 0;

function sha256Hex(s) {
  return createHash("sha256").update(s).digest("hex");
}

function hmac(key, str) {
  return createHmac("sha256", key).update(str).digest();
}

function deriveSigningKey(secretKey, dateStamp, region, service) {
  const kDate = hmac("AWS4" + secretKey, dateStamp);
  const kRegion = hmac(kDate, region);
  const kService = hmac(kRegion, service);
  return hmac(kService, "aws4_request");
}

// Builds a SigV4-signed STS GetCallerIdentity request payload consumable
// by Google STS as a WIF subject token.
function buildSignedAWSStsRequest(audience) {
  const accessKey = process.env.AWS_ACCESS_KEY_ID;
  const secretKey = process.env.AWS_SECRET_ACCESS_KEY;
  const sessionToken = process.env.AWS_SESSION_TOKEN;
  if (!accessKey || !secretKey) {
    throw new Error("Lambda AWS creds env vars missing");
  }

  const region = AWS_REGION;
  const service = "sts";
  const host = `sts.${region}.amazonaws.com`;
  const method = "POST";
  const canonicalUri = "/";
  const canonicalQuerystring = "Action=GetCallerIdentity&Version=2011-06-15";
  const payloadHash = sha256Hex("");

  const amzDate = new Date().toISOString().replace(/[-:]/g, "").replace(/\.[0-9]+/, "");
  const dateStamp = amzDate.slice(0, 8);

  const headers = {
    "host": host,
    "x-amz-date": amzDate,
    "x-goog-cloud-target-resource": audience,
  };
  if (sessionToken) headers["x-amz-security-token"] = sessionToken;

  const signedHeadersList = Object.keys(headers).sort();
  const canonicalHeaders = signedHeadersList.map((h) => `${h}:${headers[h]}\n`).join("");
  const signedHeaders = signedHeadersList.join(";");

  const canonicalRequest = [
    method,
    canonicalUri,
    canonicalQuerystring,
    canonicalHeaders,
    signedHeaders,
    payloadHash,
  ].join("\n");

  const credentialScope = `${dateStamp}/${region}/${service}/aws4_request`;
  const stringToSign = [
    "AWS4-HMAC-SHA256",
    amzDate,
    credentialScope,
    sha256Hex(canonicalRequest),
  ].join("\n");

  const signingKey = deriveSigningKey(secretKey, dateStamp, region, service);
  const signature = createHmac("sha256", signingKey).update(stringToSign).digest("hex");

  const authorization =
    `AWS4-HMAC-SHA256 Credential=${accessKey}/${credentialScope}, ` +
    `SignedHeaders=${signedHeaders}, Signature=${signature}`;

  const tokenHeaders = [
    { key: "Authorization", value: authorization },
    { key: "host", value: host },
    { key: "x-amz-date", value: amzDate },
    { key: "x-goog-cloud-target-resource", value: audience },
  ];
  if (sessionToken) tokenHeaders.push({ key: "x-amz-security-token", value: sessionToken });
  tokenHeaders.sort((a, b) => a.key.localeCompare(b.key));

  const subjectToken = {
    url: `https://${host}?${canonicalQuerystring}`,
    method: "POST",
    headers: tokenHeaders,
  };
  return encodeURIComponent(JSON.stringify(subjectToken));
}

async function exchangeForFederatedToken(audience) {
  const subjectToken = buildSignedAWSStsRequest(audience);
  const body = new URLSearchParams({
    audience,
    grantType: GRANT_TYPE_TOKEN_EXCHANGE,
    requestedTokenType: REQUESTED_TOKEN_TYPE_ACCESS,
    scope: CLOUD_PLATFORM_SCOPE,
    subjectTokenType: SUBJECT_TOKEN_TYPE_AWS,
    subjectToken,
  }).toString();

  const resp = await fetch(GOOGLE_STS_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });
  if (!resp.ok) {
    throw new Error(`Google STS HTTP ${resp.status}: ${await resp.text()}`);
  }
  const data = await resp.json();
  if (!data.access_token) {
    throw new Error(`Google STS missing access_token: ${JSON.stringify(data)}`);
  }
  return data.access_token;
}

async function impersonateSA(federatedToken, saEmail) {
  const url = `${IAM_CREDENTIALS_URL}/projects/-/serviceAccounts/` +
    `${encodeURIComponent(saEmail)}:generateAccessToken`;
  const resp = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${federatedToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ scope: [CLOUD_PLATFORM_SCOPE], lifetime: "3600s" }),
  });
  if (!resp.ok) {
    throw new Error(`SA impersonation HTTP ${resp.status}: ${await resp.text()}`);
  }
  const data = await resp.json();
  if (!data.accessToken) {
    throw new Error(`SA impersonation missing accessToken: ${JSON.stringify(data)}`);
  }
  const expiresAtSec = Math.floor(new Date(data.expireTime).getTime() / 1000);
  return { token: data.accessToken, expiresAt: expiresAtSec };
}

async function fetchAccessToken() {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedTokenExpiresAt - now > TOKEN_REFRESH_BUFFER_SECONDS) {
    return cachedToken;
  }
  const federatedToken = await exchangeForFederatedToken(WIF_AUDIENCE);
  const { token, expiresAt } = await impersonateSA(federatedToken, WIF_SA_EMAIL);
  cachedToken = token;
  cachedTokenExpiresAt = expiresAt;
  return cachedToken;
}

// ---------------------------------------------------------------------
// AWS account ID (fetched once at cold start via STS GetCallerIdentity).
// ---------------------------------------------------------------------

let cachedAccountId = null;

async function fetchAccountId() {
  if (cachedAccountId) return cachedAccountId;
  const accessKey = process.env.AWS_ACCESS_KEY_ID;
  const secretKey = process.env.AWS_SECRET_ACCESS_KEY;
  const sessionToken = process.env.AWS_SESSION_TOKEN;
  if (!accessKey || !secretKey) {
    throw new Error("Lambda AWS creds env vars missing");
  }

  const region = AWS_REGION;
  const service = "sts";
  const host = `sts.${region}.amazonaws.com`;
  const canonicalQuerystring = "Action=GetCallerIdentity&Version=2011-06-15";
  const payloadHash = sha256Hex("");
  const amzDate = new Date().toISOString().replace(/[-:]/g, "").replace(/\.[0-9]+/, "");
  const dateStamp = amzDate.slice(0, 8);

  const headers = { "host": host, "x-amz-date": amzDate };
  if (sessionToken) headers["x-amz-security-token"] = sessionToken;
  const signedHeadersList = Object.keys(headers).sort();
  const canonicalHeaders = signedHeadersList.map((h) => `${h}:${headers[h]}\n`).join("");
  const signedHeaders = signedHeadersList.join(";");
  const canonicalRequest = [
    "POST", "/", canonicalQuerystring, canonicalHeaders, signedHeaders, payloadHash,
  ].join("\n");
  const credentialScope = `${dateStamp}/${region}/${service}/aws4_request`;
  const stringToSign = [
    "AWS4-HMAC-SHA256", amzDate, credentialScope, sha256Hex(canonicalRequest),
  ].join("\n");
  const signingKey = deriveSigningKey(secretKey, dateStamp, region, service);
  const signature = createHmac("sha256", signingKey).update(stringToSign).digest("hex");
  const authorization =
    `AWS4-HMAC-SHA256 Credential=${accessKey}/${credentialScope}, ` +
    `SignedHeaders=${signedHeaders}, Signature=${signature}`;

  const reqHeaders = {
    "Authorization": authorization,
    "x-amz-date": amzDate,
    "Accept": "application/json",
  };
  if (sessionToken) reqHeaders["x-amz-security-token"] = sessionToken;

  const resp = await fetch(`https://${host}?${canonicalQuerystring}`, {
    method: "POST",
    headers: reqHeaders,
  });
  if (!resp.ok) {
    throw new Error(`STS GetCallerIdentity HTTP ${resp.status}: ${await resp.text()}`);
  }
  const data = await resp.json();
  const accountId = data?.GetCallerIdentityResponse?.GetCallerIdentityResult?.Account;
  if (!accountId) {
    throw new Error(`STS response missing Account: ${JSON.stringify(data)}`);
  }
  cachedAccountId = accountId;
  return cachedAccountId;
}

// ---------------------------------------------------------------------
// OriginalId helpers
// ---------------------------------------------------------------------

function buildApiOriginalId(accountId, region, apiId) {
  return `aws/${accountId}/regions/${region}/apis/${apiId}`;
}

function buildStageResourceId(accountId, region, apiId, stageName) {
  return `${buildApiOriginalId(accountId, region, apiId)}/stages/${stageName}`;
}

// ---------------------------------------------------------------------
// EventBridge parser
// ---------------------------------------------------------------------
//
// Returns { intent, service, region, apiId, apiType? } or null.
//   intent:  "upsert" | "delete"
//   service: "v1" | "v2"
//   apiType: "REST" | "HTTP" | "WEBSOCKET" (populated when derivable)
//
// DeleteStage returns intent "upsert": in curate, UPSERT is a full
// replacement, so re-fetching the parent API's reduced stage set is how
// the deleted stage disappears from API hub. No separate stage-level
// delete op is required.

function parseEvent(event) {
  const region = event.region;
  const detail = event.detail || {};
  const eventName = detail.eventName;
  const source = detail.eventSource;
  const req = detail.requestParameters || {};
  const resp = detail.responseElements || {};

  if (!region || !eventName) return null;
  const isV1 = source === "apigateway.amazonaws.com";
  const isV2 = source === "apigatewayv2.amazonaws.com";
  if (!isV1 && !isV2) return null;
  const service = isV1 ? "v1" : "v2";

  switch (eventName) {
    case "DeleteRestApi":
      return maybe(req.restApiId, { intent: "delete", service: "v1", region, apiType: "REST" });
    case "DeleteApi": {
      const apiType = detectV2ApiType(resp, req);
      return maybe(req.apiId, { intent: "delete", service: "v2", region, apiType });
    }
    case "UpdateRestApi":
      return maybe(req.restApiId, { intent: "upsert", service: "v1", region, apiType: "REST" });
    case "UpdateApi": {
      const apiType = detectV2ApiType(resp, req);
      return maybe(req.apiId, { intent: "upsert", service: "v2", region, apiType });
    }
    case "ImportRestApi":
    case "PutRestApi":
      return maybe(resp.id || req.restApiId, { intent: "upsert", service: "v1", region, apiType: "REST" });
    case "ImportApi":
    case "ReimportApi": {
      const apiType = detectV2ApiType(resp, req);
      return maybe(resp.apiId || req.apiId, { intent: "upsert", service: "v2", region, apiType });
    }
    case "CreateStage":
    case "UpdateStage":
    case "DeleteStage":
    case "CreateDeployment": {
      const apiId = req.restApiId || req.apiId || resp.restApiId || resp.apiId;
      const apiType = isV1 ? "REST" : detectV2ApiType(resp, req);
      return maybe(apiId, { intent: "upsert", service, region, apiType });
    }
    default:
      return null;
  }
}

function maybe(apiId, base) {
  if (!apiId) return null;
  return { ...base, apiId };
}

function detectV2ApiType(resp, req) {
  const proto = resp.protocolType || req.protocolType;
  if (proto === "WEBSOCKET") return "WEBSOCKET";
  if (proto === "HTTP") return "HTTP";
  return null;
}

// ---------------------------------------------------------------------
// AWS fetchers
// ---------------------------------------------------------------------

async function fetchRestData(region, apiId) {
  const c = v1Client(region);
  const api = await c.send(new GetRestApiCommand({ restApiId: apiId }));
  const stagesResp = await c.send(new GetStagesCommand({ restApiId: apiId }));
  const stages = stagesResp.item || [];

  const sem = new Semaphore(DETAIL_CONCURRENCY);
  const stageData = await Promise.all(stages.map((stage) => runWithLimit(sem, async () => {
    let deployment = null;
    if (stage.deploymentId) {
      try {
        deployment = await c.send(new GetDeploymentCommand({
          restApiId: apiId,
          deploymentId: stage.deploymentId,
        }));
      } catch (e) {
        console.log(`GetDeployment ${apiId}/${stage.deploymentId}: ${e.message}`);
      }
    }
    let specBytes = null;
    try {
      const exp = await c.send(new GetExportCommand({
        restApiId: apiId,
        stageName: stage.stageName,
        exportType: "oas30",
        accepts: "application/json",
      }));
      specBytes = Buffer.from(exp.body).toString("base64");
    } catch (e) {
      console.log(`GetExport ${apiId}/${stage.stageName}: ${e.message}`);
    }
    return { stage, deployment, specBytes };
  })));

  return { api, stageData, apiType: "REST" };
}

async function fetchV2Data(region, apiId) {
  const c = v2Client(region);
  const api = await c.send(new GetApiCommand({ ApiId: apiId }));
  const apiType = api.ProtocolType === "WEBSOCKET" ? "WEBSOCKET" : "HTTP";
  const stagesResp = await c.send(new GetStagesV2Command({ ApiId: apiId }));
  const stages = stagesResp.Items || [];

  let websocketRoutes = null;
  if (apiType === "WEBSOCKET") {
    websocketRoutes = await fetchAllRoutes(c, apiId);
  }

  const sem = new Semaphore(DETAIL_CONCURRENCY);
  const stageData = await Promise.all(stages.map((stage) => runWithLimit(sem, async () => {
    let specBytes = null;
    if (apiType === "HTTP") {
      try {
        const exp = await c.send(new ExportApiCommand({
          ApiId: apiId,
          StageName: stage.StageName,
          Specification: "OAS30",
          OutputType: "JSON",
        }));
        specBytes = Buffer.from(exp.body).toString("base64");
      } catch (e) {
        console.log(`ExportApi ${apiId}/${stage.StageName}: ${e.message}`);
      }
    }
    return { stage, specBytes };
  })));

  return { api, apiType, stageData, websocketRoutes };
}

async function fetchAllRoutes(client, apiId) {
  const routes = [];
  let nextToken;
  do {
    let resp;
    try {
      resp = await client.send(new GetRoutesCommand({
        ApiId: apiId,
        MaxResults: "100",
        NextToken: nextToken,
      }));
    } catch (e) {
      console.log(`GetRoutes ${apiId}: ${e.message}`);
      return routes;
    }
    for (const r of resp.Items || []) {
      if (r.RouteKey) routes.push(r.RouteKey);
    }
    nextToken = resp.NextToken;
  } while (nextToken);
  return routes;
}

// ---------------------------------------------------------------------
// Payload builders
// ---------------------------------------------------------------------

function toRfc3339(d) {
  if (!d) return null;
  if (d instanceof Date) return d.toISOString();
  return new Date(d).toISOString();
}

function buildApiBlock({ apiType, apiId, displayName, description, tagsJson, endpointType }) {
  const attributes = {};
  if (tagsJson) attributes[ATTR_API_TAGS] = jsonAttribute(tagsJson);
  if (endpointType) attributes[ATTR_ENDPOINT_TYPE] = stringAttribute(endpointType);

  return {
    displayName: displayName || apiId,
    description: description || "",
    apiStyle: enumAttribute(API_STYLE_ALLOWED_VALUE[apiType]),
    attributes,
  };
}

function jsonAttribute(jsonValue) {
  return { jsonValues: { values: [jsonValue] } };
}

function stringAttribute(value) {
  return { stringValues: { values: [value] } };
}

function enumAttribute(allowedValueId) {
  return { enumValues: { values: [{ id: allowedValueId }] } };
}

function uriAttribute(uri) {
  return { uriValues: { values: [uri] } };
}

function stageEndpoints(apiType, apiId, region, stageName, apiEndpoint) {
  if (apiType === "REST") {
    return [`https://${apiId}.execute-api.${region}.amazonaws.com/${stageName}`];
  }
  if (apiType === "WEBSOCKET") {
    const base = apiEndpoint || `wss://${apiId}.execute-api.${region}.amazonaws.com`;
    return [
      `${base}/${stageName}`,
      `https://${apiId}.execute-api.${region}.amazonaws.com/${stageName}/@connections`,
    ];
  }
  const base = apiEndpoint || `https://${apiId}.execute-api.${region}.amazonaws.com`;
  return [`${base}/${stageName}`];
}

function stageConsoleURL(apiType, apiId, region) {
  if (apiType === "HTTP") {
    return `https://${region}.console.aws.amazon.com/apigateway/main/api-detail?api=${apiId}&region=${region}`;
  }
  return `https://${region}.console.aws.amazon.com/apigateway/main/apis/${apiId}/stages?api=${apiId}&region=${region}`;
}

function buildDeploymentMetadata({ apiType, apiEndpoint, accountId, region, apiId, stage, stageUpdated }) {
  const stageName = apiType === "REST" ? stage.stageName : stage.StageName;
  const stageTags = apiType === "REST" ? stage.tags : stage.Tags;
  const stageVars = apiType === "REST" ? stage.variables : stage.StageVariables;
  const resourceUri = buildStageResourceId(accountId, region, apiId, stageName);

  const attributes = {};
  if (stageTags && Object.keys(stageTags).length > 0) {
    attributes[ATTR_STAGE_TAGS] = jsonAttribute(JSON.stringify(stageTags));
  }
  if (stageVars && Object.keys(stageVars).length > 0) {
    attributes[ATTR_STAGE_VARIABLES] = jsonAttribute(JSON.stringify(stageVars));
  }

  return {
    deployment: {
      displayName: stageName,
      deploymentType: enumAttribute(DEPLOYMENT_TYPE_ALLOWED_VALUE),
      resourceUri,
      endpoints: stageEndpoints(apiType, apiId, region, stageName, apiEndpoint),
      managementUrl: uriAttribute(stageConsoleURL(apiType, apiId, region)),
      attributes,
    },
    originalId: resourceUri,
    originalUpdateTime: stageUpdated,
  };
}

function buildSpecMetadata({ accountId, region, apiId, stageName, specBytes, stageUpdated }) {
  return {
    spec: {
      displayName: stageName,
      specType: enumAttribute(SPEC_TYPE_OPENAPI),
      contents: { contents: specBytes, mimeType: "application/json" },
    },
    originalId: `${buildStageResourceId(accountId, region, apiId, stageName)}/spec`,
    originalUpdateTime: stageUpdated,
  };
}

function buildAPIMetadata({ apiType, accountId, region, apiId, awsData }) {
  const apiUpdateTime = toRfc3339(
    apiType === "REST" ? awsData.api.createdDate : awsData.api.CreatedDate,
  );
  if (!apiUpdateTime) return null;

  const displayName = awsData.api.name || awsData.api.Name;
  const description = awsData.api.description || awsData.api.Description;
  const tagsJson = awsData.api.tags && Object.keys(awsData.api.tags).length > 0
    ? JSON.stringify(awsData.api.tags) : null;
  const endpointType = apiType === "REST"
    ? (awsData.api.endpointConfiguration?.types?.[0] || null)
    : "REGIONAL";

  const apiEndpoint = apiType === "REST" ? null : awsData.api.ApiEndpoint;

  const apiBlock = buildApiBlock({
    apiType, apiId, displayName, description, tagsJson, endpointType,
  });

  const deployments = [];
  const specs = [];
  for (const sd of awsData.stageData || []) {
    const stageName = apiType === "REST" ? sd.stage.stageName : sd.stage.StageName;
    if (!stageName) continue;
    const stageDeploymentId = apiType === "REST" ? sd.stage.deploymentId : sd.stage.DeploymentId;
    if (!stageDeploymentId) continue;

    const stageUpdated = toRfc3339(apiType === "REST" ? sd.stage.lastUpdatedDate : sd.stage.LastUpdatedDate);
    if (!stageUpdated) continue;

    deployments.push(buildDeploymentMetadata({
      apiType, apiEndpoint, accountId, region, apiId, stage: sd.stage, stageUpdated,
    }));
    if (sd.specBytes) {
      specs.push(buildSpecMetadata({
        accountId, region, apiId, stageName, specBytes: sd.specBytes, stageUpdated,
      }));
    }
  }

  if (deployments.length === 0) return null;

  const syntheticVersion = {
    version: { displayName: SYNTHETIC_VERSION_DISPLAY_NAME },
    deployments,
    specs,
    originalId: `${buildApiOriginalId(accountId, region, apiId)}/versions/${SYNTHETIC_VERSION_ID}`,
    originalUpdateTime: apiUpdateTime,
  };

  return {
    api: apiBlock,
    versions: [syntheticVersion],
    originalId: buildApiOriginalId(accountId, region, apiId),
    originalUpdateTime: apiUpdateTime,
  };
}

// Placeholder preserves the catalog entry when detail fetch fails or
// there are no deployed stages.
function buildPlaceholderAPIMetadata({ accountId, region, apiId }) {
  return {
    api: { displayName: apiId },
    originalId: buildApiOriginalId(accountId, region, apiId),
    originalUpdateTime: new Date().toISOString(),
  };
}

function buildDeleteAPIMetadata({ accountId, region, apiId, displayName }) {
  return {
    api: { displayName: displayName || apiId },
    originalId: buildApiOriginalId(accountId, region, apiId),
    originalUpdateTime: new Date().toISOString(),
  };
}

// ---------------------------------------------------------------------
// CollectApiData caller
// ---------------------------------------------------------------------

async function postCollect(payload) {
  const token = await fetchAccessToken();
  const resp = await fetch(COLLECT_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });
  const text = await resp.text();
  let parsed;
  try { parsed = JSON.parse(text); } catch { parsed = { raw: text }; }
  return { ok: resp.ok, status: resp.status, body: parsed };
}

function interpretCollectError(status, body) {
  const bodyStr = JSON.stringify(body || {}).toLowerCase();
  if (status === 404 && bodyStr.includes("plugin instance")) {
    return {
      kind: "setup_error",
      message: `Plugin instance ${PLUGIN_INSTANCE} not found. Create it before invoking this Lambda.`,
    };
  }
  if (status === 401 || status === 403) {
    return { kind: "auth_error", message: `Auth failed (HTTP ${status}). Verify WIF SA binding and IAM roles.` };
  }
  if (status >= 400 && status < 500) {
    return { kind: "validation_error", message: `Request rejected (HTTP ${status}).` };
  }
  return { kind: "transient_error", message: `Server error (HTTP ${status}); EventBridge will redeliver.` };
}

function wrapCollectRequest(collectionType, apiMetadata) {
  return {
    location: LOCATION_NAME,
    collectionType,
    pluginInstance: PLUGIN_INSTANCE,
    actionId: ACTION_ID,
    apiData: { apiMetadataList: { apiMetadata: [apiMetadata] } },
  };
}

// ---------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------

export const handler = async (event, context) => {
  console.log(`Event: ${JSON.stringify(event).slice(0, 500)}`);
  const intent = parseEvent(event);
  if (!intent) {
    console.log(`SKIP: event not actionable (source=${event?.detail?.eventSource}, name=${event?.detail?.eventName})`);
    return { skipped: true, reason: "event not actionable" };
  }

  // Prefer the account ID from the Lambda invocation context (free,
  // synchronous). Fall back to STS GetCallerIdentity for local testing.
  let accountId = accountIdFromContext(context);
  if (!accountId) accountId = await fetchAccountId();
  console.log(`INTENT: ${JSON.stringify(intent)} account=${accountId}`);

  if (intent.intent === "delete") return handleDelete(intent, accountId);
  return handleUpsert(intent, accountId);
};

function accountIdFromContext(context) {
  const arn = context?.invokedFunctionArn;
  if (!arn) return null;
  const parts = arn.split(":");
  return parts.length >= 5 ? parts[4] : null;
}

async function handleDelete(intent, accountId) {
  const { region, apiId, apiType } = intent;
  const payload = wrapCollectRequest(
    "COLLECTION_TYPE_DELETE",
    buildDeleteAPIMetadata({ accountId, region, apiId }),
  );
  const result = await postCollect(payload);
  return finalize(intent, result, { apiType });
}

async function handleUpsert(intent, accountId) {
  const { service, region, apiId } = intent;
  let awsData;
  try {
    awsData = service === "v1"
      ? await fetchRestData(region, apiId)
      : await fetchV2Data(region, apiId);
  } catch (e) {
    console.log(`AWS fetch failed for ${apiId}: ${e.message}; emitting placeholder`);
    const payload = wrapCollectRequest(
      "COLLECTION_TYPE_UPSERT",
      buildPlaceholderAPIMetadata({ accountId, region, apiId }),
    );
    const result = await postCollect(payload);
    return finalize(intent, result, { placeholder: true, error: e.message });
  }

  const apiType = awsData.apiType;
  const metadata = buildAPIMetadata({ apiType, accountId, region, apiId, awsData });
  if (!metadata) {
    // AWS fetch succeeded but the API has no deployed stages, so there
    // is nothing meaningful to publish. Emit a DELETE with the real API
    // display name (from awsData) so any prior catalog entry is removed
    // instead of preserved with a placeholder.
    console.log(`API ${apiId}: no deployed stages; emitting DELETE`);
    const displayName = awsData.api?.name || awsData.api?.Name || apiId;
    const payload = wrapCollectRequest(
      "COLLECTION_TYPE_DELETE",
      buildDeleteAPIMetadata({ accountId, region, apiId, displayName }),
    );
    const result = await postCollect(payload);
    return finalize(intent, result, { apiType, deleted: true, reason: "no deployed stages" });
  }

  const payload = wrapCollectRequest("COLLECTION_TYPE_UPSERT", metadata);
  const result = await postCollect(payload);
  return finalize(intent, result, { apiType, versionCount: metadata.versions.length });
}

function finalize(intent, result, extra) {
  if (!result.ok) {
    const err = interpretCollectError(result.status, result.body);
    console.log(`CollectApiData ${err.kind}: ${err.message} body=${JSON.stringify(result.body).slice(0, 1000)}`);
    return { intent, ok: false, status: result.status, error: err, ...extra };
  }
  console.log(`CollectApiData OK: apiId=${intent.apiId} region=${intent.region} intent=${intent.intent} extra=${JSON.stringify(extra)}`);
  return { intent, ok: true, status: result.status, ...extra };
}
