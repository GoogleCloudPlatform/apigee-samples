// Copyright 2025 Google LLC
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

const {app} = require('@azure/functions');

// =============================================================================
// Azure APIM -> API Hub event-driven push (Event Grid).
//
// Forwards real-time APIM API create/update/delete events to API Hub's
// collectApiData endpoint so a change is reflected in near real time. Each push
// UPSERTs API Hub resources (APIs, versions, deployments, specs, attributes)
// using stable original_ids, so repeated pushes converge instead of creating
// duplicates.
//
// Auth to Google Cloud uses Workload Identity Federation: the Function's Azure
// managed identity is exchanged for a short-lived Google access token, so no
// long-lived secret is stored.
// =============================================================================

// ---- env --------------------------------------------------------------
const APIHUB_HOST =
    process.env.APIHUB_HOST;  // e.g. https://apihub.googleapis.com
const PROJECT =
    process.env.PROJECT;  // API Hub host project
const LOCATION = process.env.LOCATION;  // europe-west1
const INSTANCE_ID =
    process.env.INSTANCE_ID;  // REQUIRED - real plugin instance id
const WIF_AUDIENCE =
    process.env
        .WIF_AUDIENCE;  // //iam.googleapis.com/projects/<PN>/locations/global/workloadIdentityPools/apihub-azure-onramp-pool/providers/azure-apim-oidc
const WIF_SA_EMAIL =
    process.env
        .WIF_SA_EMAIL;  // apihub-azure-onramp-sa@<project>.iam.gserviceaccount.com
const WIF_APP_ID_URI =
    process.env.WIF_APP_ID_URI;  // api://<APP_ID>  (Azure app registration
                                 // Application ID URI)
const AZURE_TENANT_ID =
    process.env.AZURE_TENANT_ID;  // Entra tenant id (also used in the deployment
                                  // management_url)
const AZURE_CLIENT_ID =
    process.env.AZURE_CLIENT_ID;  // leave UNSET for system-assigned MI

// Registered API Hub plugin id. MUST match your plugin instance resource name:
// projects/.../plugins/<PLUGIN_ID>/instances/<INSTANCE_ID>.
const PLUGIN_ID = process.env.PLUGIN_ID || 'system-azure-apim';

// Registered system-deployment-type allowed value. Must match the deployment
// type configured for your API Hub plugin instance.
const DEPLOYMENT_TYPE_ID = process.env.DEPLOYMENT_TYPE_ID || 'azure-apim';

// GCP identity endpoints (prod).
const STS_URL = process.env.STS_URL || 'https://sts.googleapis.com/v1/token';
const IAM_CRED_HOST =
    process.env.IAM_CRED_HOST || 'https://iamcredentials.googleapis.com';
// Azure platform-injected MI endpoint (Functions; NOT 169.254.169.254).
const IDENTITY_ENDPOINT = process.env.IDENTITY_ENDPOINT;
const IDENTITY_HEADER = process.env.IDENTITY_HEADER;

const ARM_RESOURCE = 'https://management.azure.com';
// 2024-05-01 covers the standard API types. Agent (A2A) APIs surface their
// fields only on newer preview versions -- set APIM_API_VERSION to a 2024-06+
// preview if you need A2A detection.
const APIM_API_VERSION = process.env.APIM_API_VERSION || '2024-05-01';
const COLLECT_URL = `${APIHUB_HOST}/v1/projects/${PROJECT}/locations/${
    LOCATION}:collectApiData`;
const PLUGIN_INSTANCE = `projects/${PROJECT}/locations/${LOCATION}/plugins/${
    PLUGIN_ID}/instances/${INSTANCE_ID}`;
const ACTION_ID = 'sync-metadata';

// =============================================================================
// AUTH: Azure managed-identity token -> Google token exchange (STS) -> service
// account impersonation (Workload Identity Federation).
// =============================================================================

// ---- WIF diagnostic: decode (do NOT log the raw token) ----------------
function decodeJwtClaims(jwt) {
  try {
    const c =
        JSON.parse(Buffer.from(jwt.split('.')[1], 'base64').toString('utf8'));
    return {
      iss: c.iss,
      aud: c.aud,
      sub: c.sub,
      oid: c.oid,
      appid: c.appid,
      ver: c.ver,
      tid: c.tid
    };
  } catch (e) {
    return {decodeError: e.message};
  }
}

// ---- Azure MI token ---------------------------------------------------
async function getAzureToken(resource) {
  if (!IDENTITY_ENDPOINT || !IDENTITY_HEADER)
    throw new Error(
        'MI endpoint missing - is system-assigned identity enabled on the Function?');
  const u = new URL(IDENTITY_ENDPOINT);
  u.searchParams.set('resource', resource);
  u.searchParams.set('api-version', '2019-08-01');
  if (AZURE_CLIENT_ID) u.searchParams.set('client_id', AZURE_CLIENT_ID);
  const r = await fetch(u, {headers: {'X-IDENTITY-HEADER': IDENTITY_HEADER}});
  if (!r.ok) throw new Error(`MI token HTTP ${r.status}: ${await r.text()}`);
  const d = await r.json();
  if (!d.access_token)
    throw new Error('MI token response missing access_token');
  return d.access_token;
}

// ---- GCP WIF chain ----------------------------------------------------
let cachedToken = null, cachedExp = 0;
async function fetchApiHubToken() {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedExp - now > 300) return cachedToken;
  // ---- fail fast on misconfiguration (clear errors instead of opaque 400s)
  // ----
  if (!WIF_AUDIENCE || !WIF_AUDIENCE.startsWith('//iam.googleapis.com/'))
    throw new Error(
        `WIF_AUDIENCE missing/malformed (must start with //iam.googleapis.com/). Got: [${
            WIF_AUDIENCE}]`);
  if (!WIF_APP_ID_URI)
    throw new Error('WIF_APP_ID_URI not set (expected api://<APP_ID>).');
  if (!WIF_SA_EMAIL) throw new Error('WIF_SA_EMAIL not set.');
  if (!INSTANCE_ID)
    throw new Error(
        'INSTANCE_ID not set - plugin_instance is REQUIRED by collectApiData.');
  const subjectToken = await getAzureToken(WIF_APP_ID_URI);
  // ---- WIF token diagnostics (decoded claims only; never the raw token) ----
  console.log(
      'AZURE_TOKEN_CLAIMS ' + JSON.stringify(decodeJwtClaims(subjectToken)));
  console.log(
      'STS_AUDIENCE_SENT [' + WIF_AUDIENCE +
      '] len=' + (WIF_AUDIENCE || '').length);
  console.log('STS_ENDPOINT ' + STS_URL);
  console.log('PLUGIN_INSTANCE ' + PLUGIN_INSTANCE);
  // ------------------------------------------------
  const stsBody = new URLSearchParams({
    audience: WIF_AUDIENCE,
    grant_type: 'urn:ietf:params:oauth:grant-type:token-exchange',
    requested_token_type: 'urn:ietf:params:oauth:token-type:access_token',
    scope: 'https://www.googleapis.com/auth/cloud-platform',
    subject_token_type: 'urn:ietf:params:oauth:token-type:jwt',
    subject_token: subjectToken,
  });
  const sts = await fetch(STS_URL, {
    method: 'POST',
    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    body: stsBody,
  });
  if (!sts.ok) throw new Error(`STS HTTP ${sts.status}: ${await sts.text()}`);
  const fed = (await sts.json()).access_token;
  const imp = await fetch(
      `${IAM_CRED_HOST}/v1/projects/-/serviceAccounts/${
          encodeURIComponent(WIF_SA_EMAIL)}:generateAccessToken`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${fed}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          scope: ['https://www.googleapis.com/auth/cloud-platform'],
          lifetime: '3600s'
        })
      });
  if (!imp.ok)
    throw new Error(`impersonation HTTP ${imp.status}: ${await imp.text()}`);
  const j = await imp.json();
  cachedToken = j.accessToken;
  cachedExp = Math.floor(new Date(j.expireTime).getTime() / 1000);
  return cachedToken;
}

// =============================================================================
// END AUTH
// =============================================================================

const nowIso = () => new Date().toISOString();

// ---- API Hub attribute ids -------------------------------------------
const ATTR_PRODUCTS = 'plugin-azure-apim-products';
const ATTR_TAGS = 'plugin-azure-apim-api-tags';
const ATTR_REVISION = 'plugin-azure-apim-revision';
const ATTR_SUBSCRIPTION_REQUIRED = 'plugin-azure-apim-subscription-required';
const ATTR_GATEWAY = 'plugin-azure-apim-gateway';
const SYSTEM_DEPLOYMENT_TYPE_ATTR = 'system-deployment-type';
const GATEWAY_MANAGED = 'managed';
const SYNTHETIC_VERSION_ID = 'v1';

// ---- API-style allowed values ----------------------------------------
const API_STYLE = {
  http: 'rest',
  soap: 'soap',
  graphql: 'graphql',
  grpc: 'grpc',
  websocket: 'websocket',
  odata: 'odata',
  a2a: 'a2a',  // agentic APIs
};

// ---- resource-name formatters ----------------------------------------
const locationResourceName = () => `projects/${PROJECT}/locations/${LOCATION}`;
const apisResourceName = (apiId) => `${locationResourceName()}/apis/${apiId}`;
const attributeResourceName = (attrId) =>
    `${locationResourceName()}/attributes/${attrId}`;

// ---- identifier helpers ----------------------------------------------
// azureBaseAPIID: strip APIM's ";rev=N" suffix. Do NOT lowercase: API Hub keys
// resources by the apiId/serviceName as-is.
const azureBaseAPIID = (id) => {
  const i = (id || '').indexOf(';rev=');
  return i >= 0 ? id.slice(0, i) : id;
};

// azureLastSegment: final path segment of an ARM resource id.
const azureLastSegment = (s) => {
  s = (s || '').replace(/^\/+|\/+$/g, '');
  const i = s.lastIndexOf('/');
  return i >= 0 ? s.slice(i + 1) : s;
};

// azureResourceURI: the shared original_id prefix and deployment resource_uri.
// serviceName + apiId are used as-is.
const azureResourceURI = (scope, apiId) =>
    `subscriptions/${scope.subscriptionId}/resourceGroups/${
        scope.resourceGroup}` +
    `/service/${scope.serviceName}/apis/${apiId}`;

// azureManagementURL: Azure portal deep link to the APIM APIs blade.
const azureManagementURL = (scope) =>
    `https://portal.azure.com/#@${AZURE_TENANT_ID}/resource/subscriptions/${
        scope.subscriptionId}` +
    `/resourceGroups/${
        scope.resourceGroup}/providers/Microsoft.ApiManagement/service/${
        scope.serviceName}/apim-apis`;

// azureGroupKeyAndDisplay: map one event's API to its version-set group. The
// logical API Hub Api is keyed by the version-set short id (so all versions
// converge on one Api), or the base apiId when unversioned.
function azureGroupKeyAndDisplay(api) {
  const key = api.versionSetId || azureBaseAPIID(api.id);
  const displayName = (api.versionSetId && api.versionSetName) ?
      api.versionSetName :
      (api.displayName || api.id);
  return {key, displayName};
}

// classifyAzureApiType: map the APIM api type to an internal type. Agent (A2A)
// APIs are detected from the raw api-type string ("a2a") returned by the REST
// response; fetchApimData additionally treats the presence of
// properties.a2aProperties as A2A.
function classifyAzureApiType(rawType) {
  switch ((rawType || '').toLowerCase()) {
    case 'soap':
      return 'soap';
    case 'websocket':
      return 'websocket';
    case 'graphql':
      return 'graphql';
    case 'grpc':
      return 'grpc';
    case 'odata':
      return 'odata';
    case 'a2a':
    case 'agent':
      return 'a2a';  // agentic; also detected via a2aProperties in
                     // fetchApimData
    default:
      return 'http';
  }
}

// azureSpecSources: which spec(s) to fetch per API type.
//   http -> OpenAPI (export); soap -> WSDL (export);
//   grpc -> proto, graphql -> SDL, odata -> EDMX (inline schema);
//   websocket -> none. a2a is NOT in this matrix: its Agent Card spec is
//   fetched from the gateway by fetchA2AAgentCard (called directly from
//   fetchApimData).
function azureSpecSources(apiType) {
  switch (apiType) {
    case 'http':
      return [{
        export: 'openapi+json-link',
        specTypeId: 'openapi',
        mimeType: 'application/json',
        kind: 'openapi'
      }];
    case 'soap':
      return [{
        export: 'wsdl-link',
        specTypeId: 'wsdl',
        mimeType: 'application/wsdl+xml',
        kind: 'wsdl'
      }];
    case 'grpc':
      return [{
        schemaContentType: 'text/protobuf',
        specTypeId: 'proto',
        mimeType: 'text/plain',
        kind: 'proto'
      }];
    case 'graphql':
      return [{
        schemaContentType: 'application/vnd.ms-azure-apim.graphql.schema',
        specTypeId: 'sdl',
        mimeType: 'application/graphql',
        kind: 'graphql'
      }];
    case 'odata':
      return [{
        schemaContentType: 'application/vnd.ms-azure-apim.odata.schema',
        specTypeId: 'edmx',
        mimeType: 'application/xml',
        kind: 'odata'
      }];
    default:
      return [];
  }
}

// ---- AttributeValues builders ----------------------------------------
const enumAttr = (id) => ({enumValues: {values: [{id}]}});
const jsonAttr = (name, jsonStr) =>
    ({attribute: name, jsonValues: {values: [jsonStr]}});
const stringAttr = (name, s) =>
    ({attribute: name, stringValues: {values: [s]}});

// ---- safe URL logging ------------------------------------------------
function urlHost(raw) {
  try {
    const u = new URL(raw);
    return u.host ? `${u.protocol}//${u.host}` : '<redacted-url>';
  } catch {
    return '<redacted-url>';
  }
}

// ---- event parsing (APIM-native) --------------------------------------
function parseResourceUri(uri) {
  const m = uri?.match(
      /subscriptions\/([^/]+)\/resourceGroups\/([^/]+)\/providers\/Microsoft\.ApiManagement\/service\/([^/]+)\/apis\/([^/?]+)/i);
  return m ? {
    subscriptionId: m[1],
    resourceGroup: m[2],
    serviceName: m[3],
    apiId: m[4]
  } :
             null;
}

function parseEvent(event) {
  const t = event?.eventType;
  if (!t?.startsWith('Microsoft.ApiManagement.API')) return null;
  const raw = event?.data?.resourceUri ||
      `${event?.topic || ''}/${event?.subject || ''}`;
  const scope = parseResourceUri(
      raw.replace(/\/{2,}/g, '/'));  // collapse // from the topic+subject join
  if (!scope) return null;
  return {
    intent: t.endsWith('Deleted') ? 'delete' : 'upsert',
    // Best-effort display name hint for the delete path (see deleteRequest).
    displayNameHint: event?.data?.name || event?.data?.title || '',
    ...scope,
  };
}

// ---- concurrency state gate (best-effort, fail-open) ------------------
async function actionGate(token) {
  if (!INSTANCE_ID) return 'PROCEED';
  try {
    const url = `${APIHUB_HOST}/v1/${PLUGIN_INSTANCE}/actions/${ACTION_ID}`;
    const r = await fetch(url, {headers: {Authorization: `Bearer ${token}`}});
    if (!r.ok) return 'PROCEED';
    const a = await r.json();
    if (a.state === 'DISABLED') return 'DROP';
    if (a.currentExecutionState === 'RUNNING') return 'DEFER';
  } catch { /* fail-open: the periodic sync is the safety net */
  }
  return 'PROCEED';
}

// ---- APIM data fetch (ARM REST) ---------------------------------------
async function armGet(url, token) {
  const r = await fetch(url, {headers: {Authorization: `Bearer ${token}`}});
  if (!r.ok) throw new Error(`ARM ${url} -> ${r.status}: ${await r.text()}`);
  return r.json();
}

// listNames pages an ARM collection and returns each entry's display name
// (falling back to its id). Best-effort: a failure yields "" enrichment, never
// fails the push.
async function listNames(url, token, context) {
  const names = [];
  let next = url;
  try {
    while (next) {
      const page = await armGet(next, token);
      for (const v of page.value || []) {
        const name = v?.properties?.displayName || v?.name;
        if (name) names.push(name);
      }
      next = page.nextLink || null;
    }
  } catch (e) {
    context.log(
        `enrichment fetch failed (${urlHost(url)}): ${e.message}; continuing`);
  }
  return names;
}

// listGatewayIds pages the service's self-hosted gateways into an array of ids.
// The built-in managed gateway is queried separately by its reserved "managed"
// id and is NOT returned here.
async function listGatewayIds(url, armToken) {
  const ids = [];
  let next = url;
  while (next) {
    const page = await armGet(next, armToken);
    for (const g of page.value || [])
      if (g?.name) ids.push(g.name);
    next = page.nextLink || null;
  }
  return ids;
}

// listGatewayApiIds pages a gateway's API collection into a Set of API ids.
// Throws on ARM error so the caller can decide whether a failed read should
// demote managed membership.
async function listGatewayApiIds(url, armToken) {
  const ids = new Set();
  let next = url;
  while (next) {
    const page = await armGet(next, armToken);
    for (const v of page.value || [])
      if (v?.name) ids.add(v.name);
    next = page.nextLink || null;
  }
  return ids;
}

// fetchGatewayInfo resolves gateway membership for a single API:
//   - managedGatewayUrl: the managed gateway base URL (ServiceClient.Get);
//     "" -> mapping falls back to the conventional <service>.azure-api.net
//     host.
//   - managed: whether the managed gateway still serves this API. Demoted to
//     false ONLY when the managed-gateway API list is read successfully and
//     omits this API (so a REMOVED gateway drops the Deployment). Fail-safe:
//     any read error keeps managed=true so a transient ARM error never silently
//     drops a live API's endpoint.
//   - selfHosted: ids of self-hosted gateways also serving this API.
async function fetchGatewayInfo(base, apiId, armToken, context) {
  let managedGatewayUrl = '';
  try {
    const svc =
        await armGet(`${base}?api-version=${APIM_API_VERSION}`, armToken);
    managedGatewayUrl = svc?.properties?.gatewayUrl || '';
  } catch (e) {
    context.log(
        `gateway: service get failed: ${e.message}; using conventional host`);
  }

  let managed = true;
  try {
    const managedApis = await listGatewayApiIds(
        `${base}/gateways/managed/apis?api-version=${APIM_API_VERSION}`,
        armToken);
    managed = managedApis.has(apiId);
  } catch (e) {
    context.log(
        `gateway: managed API list failed: ${e.message}; keeping managed=true`);
  }

  const selfHosted = [];
  try {
    for (const gwId of await listGatewayIds(
             `${base}/gateways?api-version=${APIM_API_VERSION}`, armToken)) {
      try {
        const gwApis = await listGatewayApiIds(
            `${base}/gateways/${encodeURIComponent(gwId)}/apis?api-version=${
                APIM_API_VERSION}`,
            armToken);
        if (gwApis.has(apiId)) selfHosted.push(gwId);
      } catch (e) {
        context.log(
            `gateway: ${gwId} API list failed: ${e.message}; continuing`);
      }
    }
  } catch (e) {
    context.log(`gateway: self-hosted list failed: ${e.message}; continuing`);
  }

  return {managed, managedGatewayUrl, selfHosted};
}

// exportSpec requests an ARM spec export and downloads it from the returned
// Blob SAS link.
async function exportSpec(base, apiId, format, armToken, context) {
  const exp = await armGet(
      `${base}/apis/${apiId}?export=true&format=${
          encodeURIComponent(format)}&api-version=${APIM_API_VERSION}`,
      armToken);
  const link = exp?.value?.link ||
      exp?.properties?.value?.link;  // hoist: properties.value -> value
  if (!link) return null;
  context.log(
      `spec export (${format}) for ${apiId} -> SAS host ${urlHost(link)}`);
  const sr = await fetch(
      link);  // SAS URL carries the token; never log it, no auth header
  if (!sr.ok) throw new Error(`spec download HTTP ${sr.status}`);
  return Buffer.from(await sr.arrayBuffer());
}

// fetchSchema returns the inline API schema document of the given content type.
// Returns null when the API has no such schema, so a missing schema degrades to
// metadata-only.
async function fetchSchema(base, apiId, contentType, armToken, context) {
  const list = await armGet(
      `${base}/apis/${apiId}/schemas?api-version=${APIM_API_VERSION}`,
      armToken);
  let schemaId = '';
  for (const s of list.value || []) {
    const ct = s?.properties?.contentType || '';
    if (ct.toLowerCase().includes(contentType.toLowerCase()))
      schemaId = s.name;  // substring match
  }
  if (!schemaId) {
    context.log(`API ${apiId} has no ${contentType} schema`);
    return null;
  }
  const doc = await armGet(
      `${base}/apis/${apiId}/schemas/${schemaId}?api-version=${
          APIM_API_VERSION}`,
      armToken);
  const d = doc?.properties?.document || {};
  const value =
      d.value || d.odata;  // hoist: document.odata -> document.value (OData)
  return value ? Buffer.from(value) : null;
}

// fetchSpecs gathers every spec the API type carries, skipping sources that
// fail or return no document. Never throws.
async function fetchSpecs(base, apiId, apiType, armToken, context) {
  const out = [];
  for (const src of azureSpecSources(apiType)) {
    try {
      const bytes = src.schemaContentType ?
          await fetchSchema(
              base, apiId, src.schemaContentType, armToken, context) :
          await exportSpec(base, apiId, src.export, armToken, context);
      if (bytes && bytes.length) {
        out.push({
          contentsB64: bytes.toString('base64'),
          specTypeId: src.specTypeId,
          mimeType: src.mimeType,
          kind: src.kind
        });
      }
    } catch (e) {
      context.log(`spec fetch (${src.kind}) failed for ${apiId}: ${
          e.message}; continuing`);
    }
  }
  return out;
}

// fetchA2AAgentCard returns the A2A "spec" -- the Agent Card JSON -- as a
// single spec entry (spec type a2a-agent-card). The card is served by the APIM
// gateway (a fixed, egress-safe host) at properties.a2aProperties.agentCardPath
// (default /agent-card.json); A2A gateway APIs are subscriptionRequired=false
// so the GET is unauthenticated. Best-effort: a miss yields metadata-only (no
// spec), never throws. Mechanism verified with testing_spec/a2atest.
async function fetchA2AAgentCard(scope, api, props, context) {
  try {
    const a2a = props.a2aProperties || {};
    const cardPath = a2a.agentCardPath || '/agent-card.json';
    const card = cardPath.startsWith('/') ? cardPath : '/' + cardPath;
    const gatewayHost = scope.serviceName.toLowerCase() + '.azure-api.net';
    const apiPath = (api.path || '').replace(/^\/+|\/+$/g, '');
    const url = apiPath ? `https://${gatewayHost}/${apiPath}${card}` :
                          `https://${gatewayHost}${card}`;
    context.log(`A2A agent card fetch: GET ${url}`);
    const r = await fetch(url, {headers: {Accept: 'application/json'}});
    if (!r.ok) {
      context.log(
          `A2A agent card GET -> HTTP ${r.status}; publishing metadata-only`);
      return [];
    }
    const bytes = Buffer.from(await r.arrayBuffer());
    if (!bytes.length) return [];
    return [{
      contentsB64: bytes.toString('base64'),
      specTypeId: 'a2a-agent-card',
      mimeType: 'application/json',
      kind: 'agent-card',
    }];
  } catch (e) {
    context.log(
        `A2A agent card fetch failed: ${e.message}; publishing metadata-only`);
    return [];
  }
}

// fetchApimData reads one API (identity from the event scope) into the
// normalized shape used to build the API Hub payload.
async function fetchApimData(scope, context) {
  const armToken = await getAzureToken(ARM_RESOURCE);
  const apiId = scope.apiId;  // current-revision apiId (as-is)
  const base =
      `${ARM_RESOURCE}/subscriptions/${scope.subscriptionId}/resourceGroups/${
          scope.resourceGroup}` +
      `/providers/Microsoft.ApiManagement/service/${scope.serviceName}`;

  const apiResp = await armGet(
      `${base}/apis/${apiId}?api-version=${APIM_API_VERSION}`, armToken);
  const p = apiResp.properties || {};

  // Version set: prefer the inline object, else resolve the name from the id.
  let versionSetId = '', versionSetName = '';
  if (p.apiVersionSet && (p.apiVersionSet.id || p.apiVersionSet.name)) {
    versionSetId = azureLastSegment(p.apiVersionSet.id || '');
    versionSetName = p.apiVersionSet.name || '';
  }
  if (!versionSetId && p.apiVersionSetId)
    versionSetId = azureLastSegment(p.apiVersionSetId);
  if (versionSetId && !versionSetName) {
    try {
      const vs = await armGet(
          `${base}/apiVersionSets/${versionSetId}?api-version=${
              APIM_API_VERSION}`,
          armToken);
      versionSetName = vs?.properties?.displayName || '';
    } catch (e) {
      context.log(`version set ${versionSetId} lookup failed: ${
          e.message}; continuing`);
    }
  }

  // A2A detection: the raw REST response carries either type=="a2a" or a
  // properties.a2aProperties block.
  let apiType = classifyAzureApiType(p.type || p.apiType);
  if (apiType !== 'a2a' && p.a2aProperties) apiType = 'a2a';

  const api = {
    id: apiId,
    displayName: p.displayName || '',
    description: p.description || '',
    path: (p.path || '').replace(/^\/+/, ''),
    apiType,
    revision: p.apiRevision || '',
    isCurrent: p.isCurrent !== false,
    version: p.apiVersion || '',
    versionSetId,
    versionSetName,
    subscriptionRequired: !!p.subscriptionRequired,
    products: await listNames(
        `${base}/apis/${apiId}/products?api-version=${APIM_API_VERSION}`,
        armToken, context),
    tags: await listNames(
        `${base}/apis/${apiId}/tags?api-version=${APIM_API_VERSION}`, armToken,
        context),
  };

  // Gateway membership (managed URL, managed vs. removed, self-hosted).
  // Drives whether a Deployment is emitted below.
  const gw = await fetchGatewayInfo(base, apiId, armToken, context);
  api.managed = gw.managed;
  api.managedGatewayUrl = gw.managedGatewayUrl;
  api.selfHosted = gw.selfHosted;

  // A2A APIs carry no schema resource; their "spec" is the Agent Card served by
  // the gateway. Everything else uses the export/inline-schema matrix.
  const specs = api.apiType === 'a2a' ?
      await fetchA2AAgentCard(scope, api, p, context) :
      await fetchSpecs(base, apiId, api.apiType, armToken, context);
  return {api, specs};
}

// ---- payload builders ------------------------------------------------

// buildVersionMetadata: version attributes + managed-gateway Deployment + specs.
function buildVersionMetadata(scope, api, specs) {
  const versionId = api.version || SYNTHETIC_VERSION_ID;
  const resourceUri = azureResourceURI(scope, api.id);
  const now = nowIso();

  // ----- version-scoped attributes (order-independent; keys are resource
  // names)
  const attributes = {};
  const tagsJSON =
      (api.tags && api.tags.length) ? JSON.stringify(api.tags) : '';
  if (tagsJSON) {
    const n = attributeResourceName(ATTR_TAGS);
    attributes[n] = jsonAttr(n, tagsJSON);
  }
  const productsJSON =
      (api.products && api.products.length) ? JSON.stringify(api.products) : '';
  if (productsJSON) {
    const n = attributeResourceName(ATTR_PRODUCTS);
    attributes[n] = jsonAttr(n, productsJSON);
  }
  if (api.revision) {
    const n = attributeResourceName(ATTR_REVISION);
    attributes[n] = stringAttr(n, api.revision);
  }
  {
    const n = attributeResourceName(ATTR_SUBSCRIPTION_REQUIRED);
    attributes[n] =
        stringAttr(n, String(!!api.subscriptionRequired));  // always stamped
  }

  // ----- deployment: managed gateway ONLY. A version served by no managed
  // gateway has no reachable endpoint, so NO Deployment is emitted -- the
  // Version + Spec are still upserted. This is what makes an update that
  // REMOVES the gateway drop the stale deployment/endpoint on the next push
  // instead of leaving a dangling endpoint. NOTE: removal takes effect only if
  // API Hub replaces a version's deployments on UPSERT. If deployments are
  // merged instead, a gateway removal also needs an explicit deployment DELETE.
  const deployments = [];
  if (api.managed) {
    const gatewayUrl = api.managedGatewayUrl ||
        ('https://' + scope.serviceName.toLowerCase() + '.azure-api.net');
    let gatewayHost = gatewayUrl;
    try {
      gatewayHost = new URL(gatewayUrl).hostname;
    } catch { /* keep raw */
    }
    const scheme = api.apiType === 'websocket' ? 'wss' : 'https';
    let endpoint = `${scheme}://${gatewayHost}`;
    if (api.path) endpoint = `${endpoint}/${api.path.replace(/^\/+/, '')}`;

    // gateway attribute {gateway, gatewayUrl[, selfHosted]}: key order and the
    // omitempty on selfHosted match Go's json.Marshal of azureGatewayAttr.
    const gwObj = {gateway: GATEWAY_MANAGED, gatewayUrl};
    if (api.selfHosted && api.selfHosted.length) {
      gwObj.selfHosted = api.selfHosted.map((id) => ({id}));
    }
    const gatewayAttrName = attributeResourceName(ATTR_GATEWAY);

    deployments.push({
      deployment: {
        displayName: scope.serviceName,  // the APIM service name
        deploymentType: {
          attribute: attributeResourceName(SYSTEM_DEPLOYMENT_TYPE_ATTR),
          enumValues: {values: [{id: DEPLOYMENT_TYPE_ID}]},
        },
        resourceUri,
        managementUrl: {uriValues: {values: [azureManagementURL(scope)]}},
        endpoints: [endpoint],
        attributes: {
          [gatewayAttrName]: jsonAttr(gatewayAttrName, JSON.stringify(gwObj))
        },
      },
      originalId: resourceUri,
      originalUpdateTime: now,
    });
  }

  // ----- specs (0 or 1 per this version, per the spec-source matrix)
  const specMetas =
      (specs ||
       []).map((s) => ({
                 spec: {
                   displayName: `${scope.serviceName}-${versionId}`,
                   specType: enumAttr(s.specTypeId),
                   contents: {contents: s.contentsB64, mimeType: s.mimeType},
                 },
                 originalId:
                     `${resourceUri}/versions/${versionId}/specs/${s.kind}`,
                 originalUpdateTime: now,
               }));

  const vm = {
    version: {displayName: versionId, attributes},
    originalId: `${resourceUri}/versions/${versionId}`,
    originalUpdateTime: now,
  };
  if (deployments.length) vm.deployments = deployments;
  if (specMetas.length) vm.specs = specMetas;
  return vm;
}

// buildApiMetadata: one API Hub Api (keyed by version-set/base id) carrying the
// event's version. Incremental UPSERT: only this version is sent; sibling
// versions keep their own original_ids untouched.
function buildApiMetadata(scope, api, versions) {
  const {key, displayName} = azureGroupKeyAndDisplay(api);
  return {
    api: {
      name: apisResourceName(key),
      displayName,
      description: api.description || '',
      apiStyle: enumAttr(API_STYLE[api.apiType] || API_STYLE.http),
      // No fingerprint: API Hub derives one from displayName.
    },
    versions,
    originalId: azureResourceURI(scope, key),
    originalUpdateTime: nowIso(),
  };
}

function upsertRequest(apiMetadata) {
  return {
    location: locationResourceName(),
    collectionType: 'COLLECTION_TYPE_UPSERT',
    pluginInstance: PLUGIN_INSTANCE,
    actionId: ACTION_ID,
    apiData: {apiMetadataList: {apiMetadata: [apiMetadata]}},
  };
}

// deleteRequest sends a DELETE op with only api.displayName +
// originalUpdateTime; API Hub derives the lookup fingerprint from displayName.
// The API is already gone, so we cannot re-read its display name; we use the
// event hint, else the base apiId. Deletes are best-effort here -- the periodic
// sync reconciles authoritatively.
function deleteRequest(displayName) {
  return {
    location: locationResourceName(),
    collectionType: 'COLLECTION_TYPE_DELETE',
    pluginInstance: PLUGIN_INSTANCE,
    actionId: ACTION_ID,
    apiData: {
      apiMetadataList:
          {apiMetadata: [{api: {displayName}, originalUpdateTime: nowIso()}]}
    },
  };
}

async function postCollect(payload, token) {
  const r = await fetch(COLLECT_URL, {
    method: 'POST',
    headers:
        {Authorization: `Bearer ${token}`, 'Content-Type': 'application/json'},
    body: JSON.stringify(payload),
  });
  const text = await r.text();
  if (!r.ok) console.error(`collectApiData FAILED ${r.status}: ${text}`);
  return {ok: r.ok, status: r.status, body: text};
}

// ---- entry point ------------------------------------------------------
async function eventGridHandler(event, context) {
  context.log(`event: ${event?.eventType} subject=${event?.subject}`);
  const scope = parseEvent(event);
  if (!scope) return {skipped: 'not an APIM API event'};
  context.log(
      `intent=${scope.intent} api=${scope.apiId} svc=${scope.serviceName}`);

  const token = await fetchApiHubToken();
  const gate = await actionGate(token);
  if (gate === 'DROP') return {skipped: 'action disabled'};
  if (gate === 'DEFER')
    throw new Error('full sync RUNNING - defer via Event Grid retry');

  if (scope.intent === 'delete') {
    const displayName = scope.displayNameHint || azureBaseAPIID(scope.apiId);
    const res = await postCollect(deleteRequest(displayName), token);
    context.log(`delete(displayName=${displayName}) -> ${res.status} ${
        res.body.slice(0, 500)}`);
    return res;
  }

  const {api, specs} = await fetchApimData(scope, context);
  context.log(
      `fetched api=${api.id} type=${api.apiType} version=${
          api.version || SYNTHETIC_VERSION_ID} ` +
      `versionSet=${api.versionSetId || '-'} managed=${
          api.managed} selfHosted=${(api.selfHosted || []).length} ` +
      `specs=${specs.length} products=${api.products.length} tags=${
          api.tags.length}`);
  const apiMetadata =
      buildApiMetadata(scope, api, [buildVersionMetadata(scope, api, specs)]);
  const res = await postCollect(upsertRequest(apiMetadata), token);
  context.log(`upsert(originalId=${apiMetadata.originalId}) -> ${res.status} ${
      res.body.slice(0, 500)}`);
  return res;
}

app.eventGrid('onrampApimSync', {handler: eventGridHandler});
module.exports = {
  eventGridHandler,
  parseEvent,
  classifyAzureApiType,
  azureSpecSources,
  azureResourceURI,
  azureGroupKeyAndDisplay,
  buildApiMetadata,
  buildVersionMetadata,
};
