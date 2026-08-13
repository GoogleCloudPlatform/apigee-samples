# Cymbal Retail: ADK & Apigee Enterprise AI Governance Showcase

[![Google Cloud](https://img.shields.io/badge/Google%20Cloud-%234285F4.svg?style=for-the-badge&logo=google-cloud&logoColor=white)](https://cloud.google.com)
[![Vertex AI](https://img.shields.io/badge/Vertex%20AI-Agent%20Engine-blue?style=for-the-badge)](https://cloud.google.com/vertex-ai)
[![Apigee](https://img.shields.io/badge/Apigee-API%20Management-FF6F00?style=for-the-badge)](https://cloud.google.com/apigee)
[![Model Context Protocol](https://img.shields.io/badge/Protocol-MCP%20JSON--RPC-green?style=for-the-badge)](https://modelcontextprotocol.io)

An enterprise demonstration reference project showcasing **Agent-to-Agent (A2A)** autonomous orchestration built with Google's **Agent Development Kit (ADK)** and **Vertex AI Agent Engine**, integrated with standardized **Model Context Protocol (MCP)** tool gateways, and fully governed by **Apigee API Management** (featuring **Google Cloud Model Armor** threat defense and **Cloud SDP** real-time PII sanitization).

---

## 🏛️ System Architecture

```mermaid
graph TD
    User([👤 User / Client App / ADK Agent]) -->|HTTPS POST| ApigeeGov[🛡️ Apigee AI Governance & Hybrid Router<br>/v1/adk-retail-agent-llm-governance]
    
    subgraph "Apigee Enterprise AI Governance & Routing Layer"
        ApigeeGov -->|1. Threat Defense| ModelArmor[🤖 Google Cloud Model Armor]
        ApigeeGov -->|2. Data Sanitization| DLP[🔍 Cloud DLP PII Redaction]
        ApigeeGov -->|3. Dynamic Classification| Router{Prompt Complexity Classifier}
        ApigeeGov -->|4. Observability| Analytics[📊 Apigee Token Data Collectors]
    end
    
    Router -->|Simple Queries / Greetings / Mock Data| Gemma[🏠 Private Gemma 3 4B<br>Cloud Run CPU / Scale-to-Zero]
    Router -->|Complex Reasoning & Handoffs| Supervisor[👔 Root Supervisor Agent<br>customerserviceagent (Gemini 2.5 Flash)]
    
    subgraph "Vertex AI Agent Engine (A2A Handoff Network)"
        Supervisor -->|A2A: transfer_to_agent| Orders[📦 Orders Sub-Agent]
        Supervisor -->|A2A: transfer_to_agent| Returns[🔄 Returns Sub-Agent]
        Supervisor -->|A2A: transfer_to_agent| Customers[👤 Customers Sub-Agent]
        Supervisor -->|A2A: transfer_to_agent| Shipping[🚚 Shipping Sub-Agent]
    end
    
    Orders -->|MCP JSON-RPC 2.0| MCPGate[🌐 Apigee Native MCP Gateway<br>/mcp]
    Returns -->|MCP JSON-RPC 2.0| MCPGate
    Customers -->|MCP JSON-RPC 2.0| MCPGate
    Shipping -->|MCP JSON-RPC 2.0| MCPGate
    
    MCPGate -->|OAuth 2.0 Token Auth & Target Transformation| Services[(📦 Cymbal REST Microservices<br>/v2/samples/adk-cymbal-retail/*)]
```

---

## ✨ Key Enterprise Capabilities

### 1. Autonomous Multi-Agent Orchestration (A2A)
Instead of forcing a single LLM prompt to navigate complex enterprise APIs, the architecture implements a **Supervisor / Worker network**:
* **`customerserviceagent` (Supervisor):** Clarifies customer intent and delegates execution context cleanly to domain workers via `transfer_to_agent`.
* **Specialized Sub-Agents:** `ordersagent`, `returnsagent`, `customersagent`, and `shippingagent` operate with isolated system instructions, specialized domain prompts, and scoped tool permissions.

### 2. Unified Apigee Native MCP Gateway (`/mcp`)
All backend microservices are exposed via Apigee as a standardized **Model Context Protocol (MCP)** server layout at `/mcp`. Agents negotiate tool discovery (`tools/list`), session initialization (`initialize`), and execution (`tools/call`) using JSON-RPC 2.0 over HTTP:
* **Customers (3 tools):** `getAllCustomers`, `getCustomerById`, `createCustomer` / `updateCustomer` (Requires `manager` scope).
* **Orders (4 tools):** `getAllOrders`, `getOrderById`, `createOrder`, `updateOrder` (Requires `customer` scope).
* **Returns (5 tools):** `getAllReturns`, `getReturnById`, `createReturnRequest`, `updateReturnStatus`, `processRefund` (Requires `customer` scope).
* **Shipping (1 tool):** `createShippingLabel` (Requires `customer` scope).

### 3. Dynamic Hybrid AI Routing & Private Gemma 3 (4B)
To eliminate Vertex AI 429 quota exhaustion and reduce inference costs:
* **Intelligent Prompt Classifier:** Evaluates prompt complexity and header directives (`x-model-tier: local` or `x-model-tier: frontier`).
* **Private Local Routing:** Routes simple greetings, FAQs, and mock microservice calls to a self-contained **Gemma 3 (4B)** instance running on **Cloud Run (CPU with Scale-to-Zero)**.
* **Frontier Routing:** Routes multi-agent planning and complex reasoning tasks to **Gemini 2.5 Flash**.
* **Protocol Translation:** Bidirectionally converts between Vertex AI `generateContent` JSON and OpenAI `/v1/chat/completions` JSON schemas.

### 4. Apigee Enterprise AI Governance (`/v1/adk-retail-agent-llm-governance`)
Every LLM generation request is proxied through Apigee, enforcing uniform security across both Gemma and Gemini:
* **Pre-Generation Threat Filtering (Model Armor):** Intercepts Prompt Injections, Jailbreaks, Hate Speech, and Malicious URIs before reaching models.
* **On-the-Fly PII Redaction (Cloud DLP):** Executes transformation templates to mask Social Security Numbers, Credit Cards, and sensitive entries with `#`.
* **Token Cost Attribution & RAI Analytics:** XML Data Collectors record exact prompt, candidate, and thought token counts, compiling custom enterprise visual reports directly in Apigee Analytics.

### 5. OAuth 2.0 RFC-Compliant Token Protection & Scope Authorization
* **OAuth 2.0 Token Verification (`OA-VerifyAccessToken`):** All domain REST API proxies (`cymbal-customers-v2`, `cymbal-orders-v2`, `cymbal-returns-v2`, `cymbal-shipping-v2`, and `/mcp`) enforce OAuth 2.0 Bearer access tokens with fine-grained scopes (`customer`, `manager`).
* **Tool Filtering via Payload Authorization:** The MCP gateway (`cymbal-discovery-v1`) validates and filters available tools based on the MCP payload operations permitted by the caller's active token.
* **OAuth 2.0 Authorization Server (`oauth-server`):** Built-in RFC-compliant authorization server supporting Authorization Code grant flow, OpenID discovery (`/.well-known/openid-configuration`), and Protected Resource Metadata (`/.well-known/oauth-protected-resource/mcp`).

---

## 📁 Repository Layout

```text
├── config/                  # Backend microservice OpenAPI specs & target YAMLs
├── oauth_client/            # Web chat client app for testing the remote agent on Agent Runtime
├── proxies/                 # Apigee API Management proxy deployment bundles
│   ├── adk-retail-agent-llm-governance-v1/   # AI safety, hybrid routing & token logging proxy
│   ├── cymbal-customers-v2/                  # Domain backend REST proxy (Customers)
│   ├── cymbal-orders-v2/                     # Domain backend REST proxy (Orders)
│   ├── cymbal-returns-v2/                    # Domain backend REST proxy (Returns)
│   ├── cymbal-shipping-v2/                   # Domain backend REST proxy (Shipping)
│   ├── cymbal-discovery-v1/                  # Native Apigee MCP Gateway (/mcp)
│   └── oauth-server/                         # OAuth 2.0 Authorization Server
├── python/agents/           # ADK Python agent definitions & toolsets
│   ├── cymbal-retail-agent/                  # Standard retail agent (Local ADK dev)
│   ├── cymbal-retail-agent-apigeellm/        # Governed agent w/Apigee LLM gateway (Local ADK dev)
│   ├── cymbal-retail-agent-geap/             # Version for GEAP Agent Runtime
│   └── cymbal-retail-agent-governance/       # AI Governance agent configuration
├── sharedflowbundles/       # Reusable Apigee flows (LLM extraction & cloud logging)
├── test/integration/        # Apickli BDD Cucumber automated regression suites (11 feature files)
│   └── features/
│       ├── customers-api.feature             # REST Customers endpoints & lifecycle
│       ├── orders-api.feature                # REST Orders endpoints & lifecycle
│       ├── returns-api.feature               # REST Returns endpoints & process-refund
│       ├── shipping-api.feature              # REST Shipping endpoints & label rates
│       ├── llm-governance.feature            # AI Safety, hybrid routing, DLP, token quotas
│       ├── mcp-customers-api.feature         # MCP JSON-RPC Customers tools
│       ├── mcp-orders-api.feature            # MCP JSON-RPC Orders tools
│       ├── mcp-returns-api.feature           # MCP JSON-RPC Returns tools
│       ├── mcp-shipping-api.feature          # MCP JSON-RPC Shipping tools
│       ├── mcp-multicloud-governance.feature # MCP Discovery & Payload Auth
│       └── oauth-server.feature              # OAuth 2.0 RFC compliance & error flows
├── setup-qwiklabs-gemma.sh  # Turnkey Qwiklabs workshop setup script (Cloud Run CPU Gemma 3 4B)
├── deploy-gemma-cpu-cloudrun.sh # CPU-Optimized Gemma 3 (4B) Cloud Run deployment
├── deploy-gemma-cloudrun.sh # GPU-Optimized Gemma 2 (9B) Cloud Run deployment (vLLM)
├── redeploy-all-proxies.sh  # Clean Apigee proxy deployment helper script
├── test-hybrid-routing.py   # Python Hybrid AI Routing (Gemma vs Gemini) verification script
├── perf-test-gemma.py       # Python Performance & Concurrency Load Benchmark (4 tiers)
├── test-mcp-e2e.py          # Python End-to-End MCP & Security regression test suite
├── deploy-adk-cymbal-retail-agent.sh         # Automated GCP/Apigee deployer script
├── setup.sh                 # Main entrypoint provisioning script
└── run_integration_tests.sh                  # Automated BDD verification runner
```

---

## 🚀 Getting Started & Setup

### Prerequisites
* Google Cloud CLI (`gcloud`) authenticated with Project Admin permissions.
* Python `>=3.12` with `uv` or `poetry`.
* Node.js `>=18` (for BDD test execution).

### 1. Production Deployment & GCP Provisioning
To provision and deploy the entire enterprise infrastructure from scratch, set the values in `env.sh`, then run:

```bash
source env.sh 
./setup.sh
```

Upon successful deployment, the script outputs the credentials and endpoints needed for testing.

### 2. Turnkey Gemma 3 (4B) Workshop Setup (Qwiklabs / Workshops)
To deploy **Gemma 3 (4B)** on Cloud Run CPU (**4 vCPUs, 8GB RAM, Scale-to-Zero**) without requiring GPU quotas, and test hybrid routing in a single turnkey command:

```bash
./setup-qwiklabs-gemma.sh
```

### 3. Clean Redeployment of Proxies
To cleanly redeploy all 7 Apigee API proxies to the active environment:

```bash
./redeploy-all-proxies.sh
```

---

## 🧪 Testing and Verification

### 1. Running Full BDD Integration Regression Suite
The automated BDD suite executes **61 scenarios (406 steps)** verifying all REST proxies, Native MCP tools, AI Governance rules, Hybrid Routing, and OAuth RFC compliance:

```bash
./run_integration_tests.sh
```

> **Note:** The test runner (`test/integration/features/support/init.js`) includes automated OAuth token caching and exponential backoff retry handling for Vertex AI rate limit mitigation.

### 2. Running Python MCP End-to-End & Security Suite
To execute the comprehensive Python test suite covering all 14 MCP tools, error handling, and security rejection checks:

```bash
python3 test-mcp-e2e.py
```

* Tests all 14 MCP tool calls (`getAllCustomers`, `getOrderById`, `createReturnRequest`, etc.).
* Tests security rejections for unknown tools (`401 Unauthorized`), unauthenticated executions (`401 Unauthorized`), and unsupported JSON-RPC methods (`400 Bad Request`).

### 3. Verifying Hybrid Model Routing & AI Safety
To test intelligent dynamic routing between local Gemma 3 (4B) and frontier Gemini 2.5 Flash with uniform Model Armor & Cloud DLP protection:

```bash
python3 test-hybrid-routing.py
```

### 4. Running Performance & Concurrency Load Benchmarks
To run the automated concurrency benchmark simulating multi-user load across 4 tiers:

```bash
python3 perf-test-gemma.py
```

### 5. Testing Agents Locally with ADK Web UI
To interact with the agents locally using the ADK development server:
```bash
cd python/agents/cymbal-retail-agent # or cd python/agents/cymbal-retail-agent-apigeellm
uv sync
uv run adk web --reload_agents
```

### 6. Testing Remote Agent on GEAP via Client Web App
The project includes a web application client to test the live deployed GEAP agent with interactive OAuth 2.0 user consent:

1. **Source configuration environment variables:**
   ```bash
   source env.sh
   ```
2. **Launch the OAuth mock client server:**
   ```bash
   cd oauth_client
   uv run python app.py
   ```
3. **Open browser to test:**
   * Navigate to `http://localhost:9000`.
   * Send a query requiring authentication (e.g. *"list all orders"* or *"check status of order 123"*).
   * Click **Login** on the consent card to authenticate.
   * Verify that subsequent order queries execute directly without prompting for login again.

---

## ⚡ Performance Benchmarks & Workshop Sizing Architecture

### Recommended Deployment Model: **Model A (Standard Qwiklabs Sandbox)**
In customer workshops and Qwiklabs training formats, the recommended architecture is **Model A: 1 Student per Dedicated GCP Sandbox Project**:
* **Infrastructure:** Each attendee runs their own isolated Cloud Run CPU instance (**4 vCPUs, 8GB RAM, Scale-to-Zero**) via `./setup-qwiklabs-gemma.sh`.
* **Zero GPU Quota:** Operates completely on standard CPU quotas without requiring scarce A100/L4 GPU allocations.
* **$0 Idle Cost:** Scale-to-Zero (`--min-instances=0`) automatically terminates compute resources when students are inactive.
* **Private Zero-Trust Target Security:** Apigee securely authenticates with Cloud Run using Google Cloud OIDC tokens (`<Authentication><GoogleIDToken>`).

### Empirical Concurrency & Stress Test Matrix

| Concurrency Tier | Scope / Load Type | Total Requests | Success Rate | p50 Latency | Throughput | Primary Behavior / Root Cause |
| :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| **1 User (Model A: Qwiklabs)** | **Individual Student** | 3 | **100.0%** | **7.25s** | 5.68 tok/s | ✅ **Optimal for student workshops** |
| **5 Users (Shared Container)** | Moderate Concurrency | 10 | **10.0%** | **21.16s** | 2.39 tok/s | ⚠️ CPU contention & client timeout |
| **15 Users (Shared Container)**| Peak Multi-tenant | 15 | **0.0%** | >30.0s | 0.00 tok/s | ❌ Single CPU container queue saturation |
| **Frontier Gemini 2.5 Flash** | Multi-Agent Reasoning | 10 | **100.0%** | **1.99s** | **141.52 tok/s**| ✅ Massively parallel TPU compute |

> **Key Architectural Takeaway:** A single 4-vCPU container processes requests sequentially or via CPU time-slicing. In **Model A (1 student per GCP project)**, students experience **100% reliability at ~7.25s p50 latency**. For shared multi-tenant deployments with 10+ concurrent users, either scale out Cloud Run instances (`--max-instances=10 --concurrency=1`) with pre-baked images, or route complex prompts to Gemini 2.5 Flash.

---

## 📄 License
Copyright 2026 Google LLC. Licensed under the [Apache License, Version 2.0](LICENSE.txt).
