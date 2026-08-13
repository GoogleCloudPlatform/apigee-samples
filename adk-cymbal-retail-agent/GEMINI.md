# Cymbal Retail: Agent Development & Apigee Architecture Guidelines (Jetski)

This guide provides context, guidelines, and rules for Jetski agents working with the Cymbal Retail codebase.

---

## 🏛️ System Architecture Context

Cymbal Retail is an enterprise reference architecture demonstrating:
1. **Agent-to-Agent (A2A) Orchestration**: Root supervisor agent (`customerserviceagent`) coordinating domain sub-agents (`ordersagent`, `returnsagent`, `customersagent`, and `shippingagent`) using Google's Agent Development Kit (ADK) and Vertex AI.
2. **Apigee Native MCP Gateway (`/mcp`)**: Standardized Model Context Protocol (MCP) gateway exposing backend microservices over JSON-RPC 2.0.
3. **Apigee AI Governance (`/v1/adk-retail-agent-llm-governance`)**: Google Cloud Model Armor threat defense, Cloud DLP real-time PII sanitization, and token usage accounting.
4. **OAuth 2.0 Authorization Server (`oauth-server`)**: RFC-compliant token generation enforcing `manager` and `customer` scopes.

---

## 🔑 Key Endpoints & Routing

- **MCP Gateway**: `POST https://{APIGEE_HOST}/mcp`
  - Methods: `initialize`, `notifications/initialized`, `tools/list`, `tools/call`.
- **LLM Governance Gateway**: `POST https://{APIGEE_HOST}/v1/adk-retail-agent-llm-governance/v1/projects/{PROJECT_ID}/locations/us-central1/publishers/google/models/gemini-2.5-flash:generateContent`
  - Headers: `x-apikey: {APIKEY}`, `Authorization: Bearer {APP_DEFAULT_TOKEN}`
- **OAuth Server**:
  - `GET https://{APIGEE_HOST}/authorize`
  - `POST https://{APIGEE_HOST}/token` (Requires HTTP Basic Auth `client_id:client_secret`)
  - `GET https://{APIGEE_HOST}/.well-known/openid-configuration`
  - `GET https://{APIGEE_HOST}/.well-known/oauth-protected-resource/mcp`
- **Domain REST Proxies**:
  - Customers: `https://{APIGEE_HOST}/v2/samples/adk-cymbal-retail/customers` (Scope: `manager`)
  - Orders: `https://{APIGEE_HOST}/v2/samples/adk-cymbal-retail/orders` (Scope: `customer`)
  - Returns: `https://{APIGEE_HOST}/v2/samples/adk-cymbal-retail/returns` (Scope: `customer`)
  - Shipping: `https://{APIGEE_HOST}/v2/samples/adk-cymbal-retail/shipping` (Scope: `customer`)

---

## 🛠️ Testing & Verification Guidelines

### Automated BDD Cucumber Suite
Run all 61 scenarios (406 steps) across 11 feature files:
```bash
./run_integration_tests.sh
```

### Python Native MCP End-to-End Suite
Run the 17-test Python verification suite covering all 14 MCP tools and negative security tests:
```bash
python3 test-mcp-e2e.py
```

### Hybrid Model Routing & AI Safety Suite
Run the hybrid routing verification script testing local Gemma 3 (4B) and frontier Gemini routes:
```bash
python3 test-hybrid-routing.py
```

### Performance & Concurrency Load Benchmark
Run the concurrency benchmark simulating 1 to 15 concurrent workshop attendees:
```bash
python3 perf-test-gemma.py
```

### Qwiklabs & Workshop Turnkey Setup
Deploy CPU-optimized Gemma 3 (4B) on Cloud Run and test hybrid routing in one command:
```bash
./setup-qwiklabs-gemma.sh
```

### Workshop Architecture: Model A (Standard Qwiklabs Sandbox)
- **1 Student per GCP Project:** Each student runs their own isolated Cloud Run CPU instance (4 vCPUs, 8GB RAM, `--min-instances=0`).
- **Quota & Cost:** 0 GPU quota needed, $0 idle cost, 100% reliability, ~7.25s p50 latency.
- **Private Zero-Trust Target:** Apigee target connection uses `<Authentication><GoogleIDToken>` with service account `llm-cymbal-retail-agent@PROJECT_ID.iam.gserviceaccount.com`.

### Rate Limiting & Quota Rules
- When running automated tests against Vertex AI Gemini models, avoid hammering requests consecutively.
- Use the built-in token caching and exponential backoff retry handler in `test/integration/features/support/init.js` to avoid Vertex AI 429 quota exhaustion.
- Offload high-frequency simple prompts to private Gemma 3 (`x-model-tier: local`) to preserve Vertex AI quotas.
