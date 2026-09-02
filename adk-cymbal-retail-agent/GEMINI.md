# Cymbal Retail: Agent Development & Apigee Architecture Guidelines (Jetski)

This guide provides context, guidelines, and rules for Jetski agents working with the Cymbal Retail codebase.

---

## 🏛️ System Architecture Context

Cymbal Retail is an enterprise reference architecture demonstrating:
1. **Agent-to-Agent (A2A) Orchestration**: Root supervisor agent (`customerserviceagent`) coordinating domain sub-agents (`ordersagent`, `returnsagent`, `customersagent`, and `shippingagent`) using Google's Agent Development Kit (ADK) and Vertex AI Agent Platform Reasoning Engine.
2. **Apigee LLM AI Gateway (`llm-ai-gateway-v1`)**: Centralized AI governance layer supporting OpenAI-compatible (`/chat/completions`) and native (`/chat`) endpoints, semantic caching via Vector Search, prompt rate limiting, token consumption quotas, and Model Armor threat protection.
3. **Apigee Native MCP Gateway (`cymbal-discovery-v1` at `/mcp`)**: Standardized Model Context Protocol (MCP) gateway exposing domain backend microservices over JSON-RPC 2.0.
4. **Apigee AI Governance (`adk-retail-agent-llm-governance-v1`)**: Model Armor prompt injection defense, Cloud DLP real-time PII sanitization, and token usage accounting.
5. **Agent Identity & Agent Registry**: Managed IAM token exchange (`cymbal-idp` auth provider and `cymbal-auth-binding` registry entry) without hardcoded secrets in agent runtime code.
6. **OAuth 2.0 Authorization Server (`oauth-server`)**: RFC-compliant token generation enforcing `manager` and `customer` scopes with registered redirect callbacks (`http://127.0.0.1:9000/callback`).

---

## 🔑 Key Endpoints & Routing

- **LLM AI Gateway**:
  - `POST https://{APIGEE_HOST}/v1/llm-ai-gateway/chat/completions` (OpenAI format)
  - `POST https://{APIGEE_HOST}/v1/llm-ai-gateway/chat` (Native format)
  - `POST https://{APIGEE_HOST}/v1/llm-ai-gateway/projects/{PROJECT_ID}/locations/us-central1/publishers/google/models/gemini-2.5-flash:generateContent`
  - Headers: `x-apikey: {LLM_APIKEY}`, `x-llm-cache`, `x-llm-routing`, `x-model-tier`, `x-llm-model`
- **MCP Gateway**: `POST https://{APIGEE_HOST}/mcp`
  - Methods: `initialize`, `notifications/initialized`, `tools/list`, `tools/call`.
- **LLM Governance Gateway**: `POST https://{APIGEE_HOST}/v1/adk-retail-agent-llm-governance/v1/projects/{PROJECT_ID}/locations/us-central1/publishers/google/models/gemini-2.5-flash:generateContent`
  - Headers: `x-apikey: {APIKEY}`, `Authorization: Bearer {APP_DEFAULT_TOKEN}`
- **OAuth Server**:
  - `GET https://{APIGEE_HOST}/authorize?client_id={CLIENT_ID}&response_type=code&scope=manager&redirect_uri=http://127.0.0.1:9000/callback`
  - `POST https://{APIGEE_HOST}/token` (Requires HTTP Basic Auth `client_id:client_secret` or form body)
  - `GET https://{APIGEE_HOST}/.well-known/openid-configuration`
  - `GET https://{APIGEE_HOST}/.well-known/oauth-protected-resource/mcp`
- **Domain REST Proxies**:
  - Customers: `https://{APIGEE_HOST}/v2/samples/adk-cymbal-retail/customers` (Scope: `manager`)
  - Orders: `https://{APIGEE_HOST}/v2/samples/adk-cymbal-retail/orders` (Scope: `customer`)
  - Returns: `https://{APIGEE_HOST}/v2/samples/adk-cymbal-retail/returns` (Scope: `customer`)
  - Shipping: `https://{APIGEE_HOST}/v2/samples/adk-cymbal-retail/shipping` (Scope: `customer`)

---

## 🛠️ Testing & Verification Guidelines

### Unified Regression Suite
Run all automated test suites sequentially with automatic credential discovery:
```bash
./run_integration_tests.sh
```

### Individual Test Suites
1. **Cucumber BDD Suite (`npm test`):**
   - Covers 12 feature files: `llm-ai-gateway.feature` (10 scenarios), `llm-governance.feature`, `oauth-server.feature`, `mcp-*.feature`, and domain REST features.
2. **Native MCP End-to-End Suite:**
   - `python3 test-mcp-e2e.py` (17 tests covering 14 tools + 3 security edge cases).
3. **Agent Runtime Reasoning Engine Suite:**
   - `python/agents/cymbal-retail-agent-geap/.venv/bin/python3 test-agent-runtime-e2e.py` (5 tests covering engine get, session CRUD, tool invocation, persona, and Agent Identity).
4. **Hybrid Model Routing & AI Safety Suite:**
   - `python3 test-hybrid-routing.py` (Private Gemma 3 vs. Gemini 2.5 Flash routing, Model Armor & Cloud DLP).

---

## 💡 Important Rules for Development

1. **Reasoning Engine SDK Invocation:** Always fetch engines via `client.agent_engines.get(name=...)` with the full resource name before calling `.stream_query()` or session methods.
2. **Agent Identity CLI:** Manage auth providers using `gcloud beta agent-identity auth-providers` and registry bindings using `gcloud agent-registry`.
3. **OAuth Redirect Callbacks:** The `oauth-server` proxy validates that `redirect_uri` matches one of the registered developer app callbacks (`http://127.0.0.1:9000/callback` or `http://localhost:9000/callback`).
4. **Rate Limiting Mitigation:** Use exponential backoff and token caching in `test/integration/features/support/init.js` to prevent 429 Vertex AI quota errors during test execution.
