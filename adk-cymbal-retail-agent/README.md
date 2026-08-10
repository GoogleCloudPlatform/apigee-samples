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
    User([👤 User Prompt]) -->|HTTPS POST| ApigeeGov[🛡️ Apigee LLM Governance Proxy<br>/v1/adk-retail-agent-llm-governance]
    
    subgraph "Apigee Enterprise AI Governance Layer"
        ApigeeGov -->|1. Threat Scan| ModelArmor[🤖 Google Cloud Model Armor]
        ApigeeGov -->|2. Data Masking| DLP[🔍 Cloud SDP PII Redaction]
        ApigeeGov -->|3. Observability| Analytics[📊 Apigee Token Data Collectors]
    end
    
    ApigeeGov -->|Sanitized Prompt| Supervisor[👔 Root Supervisor Agent<br>customerserviceagent]
    
    subgraph "Vertex AI Agent Engine (A2A Handoff Network)"
        Supervisor -->|A2A: transfer_to_agent| Orders[📦 Orders Sub-Agent]
        Supervisor -->|A2A: transfer_to_agent| Returns[🔄 Returns Sub-Agent]
        Supervisor -->|A2A: transfer_to_agent| Customers[👤 Customers Sub-Agent]
        Supervisor -->|A2A: transfer_to_agent| Shipping[🚚 Shipping Sub-Agent]
    end
    
    Orders -->|MCP JSON-RPC 2.0| MCPGate[🌐 Apigee MCP Target Gateway<br>/mcp/v2/samples/adk-cymbal-retail/*]
    Returns -->|MCP JSON-RPC 2.0| MCPGate
    Customers -->|MCP JSON-RPC 2.0| MCPGate
    Shipping -->|MCP JSON-RPC 2.0| MCPGate
    
    MCPGate -->|OAuth 2.0 Auth & REST Mapping| Services[(📦 Internal Cymbal Microservices)]
```

---

## ✨ Key Enterprise Capabilities

### 1. Autonomous Multi-Agent Orchestration
Instead of forcing a single LLM prompt to navigate complex enterprise APIs, the architecture implements a **Supervisor / Worker network**:
* **`customerserviceagent` (Supervisor):** Clarifies customer intent and delegates execution context cleanly to domain workers.
* **Specialized Sub-Agents:** `ordersagent`, `returnsagent`, `customersagent`, and `shippingagent` operate with isolated system instructions and restricted tool permissions.

### 2. Unified MCP Tool Architecture
All backend microservices are resolved via Apigee as a standardized **Model Context Protocol (MCP)** server layout. Agents negotiate tool lists and tool calls using JSON-RPC 2.0 over HTTP, secured using dynamic OAuth 2.0 Bearer access tokens generated at runtime.

### 3. Apigee Enterprise AI Governance
Every LLM generation request is proxied through Apigee (`adk-retail-agent-llm-governance-v1`), enforcing:
* **Pre-Generation Threat Filtering (Model Armor):** Intercepts Prompt Injections, Jailbreaks, Hate Speech, and Malicious URIs before they reach Gemini.
* **On-the-Fly PII Redaction (Cloud DLP):** Executes transformation templates to mask Social Security Numbers, Credit Cards, and sensitive entries with `#`.
* **Token Cost Attribution & RAI Analytics:** XML Data Collectors record exact prompt, candidate, and thought token counts, compiling custom enterprise visual reports directly in Apigee Analytics.

---

## 🛠️ Architectural Upgrades & Recent Changes

### OAuth 2.0 Access Token Protection
- **OAuth 2.0 Token Verification:** Upgraded all domain REST API proxies (`cymbal-customers-v2`, `cymbal-returns-v2`, and `cymbal-shipping-v2`) from API Key validation (`VA-VerifyKey`) to OAuth 2.0 Access Token verification (`OA-VerifyAccessToken`) for compliance with MCP, enforcing scopes like `customer` and `manager`.
- **Tool filtering:** The MCP proxy (`cymbal-discovery-v1`) filters available tools based on the MCP payload operations allowed in the API product.
- **Mock Identity Provider (`oauth-server`):** Deployed a dedicated mock OIDC provider proxy to support programmatic authorization code flow and access token issuance for tests and agents.

---

## 📁 Repository Layout

```text
├── config/                  # Backend microservice OpenAPI specs & target YAMLs
├── oauth_client/            # Web chat client app for testing the remote agent on Agent Runtime
├── proxies/                 # Apigee API Management proxy deployment bundles
│   ├── adk-retail-agent-llm-governance-v1/   # AI safety & token logging proxy
│   ├── cymbal-customers-v2/                  # Domain backend REST proxy (Customers)
│   ├── cymbal-orders-v2/                     # Domain backend REST proxy (Orders)
│   ├── cymbal-returns-v2/                    # Domain backend REST proxy (Returns)
│   ├── cymbal-shipping-v2/                   # Domain backend REST proxy (Shipping)
│   ├── cymbal-discovery-v1/                  # MCP discovery proxy (exposes the cymbal-*-v2 APIs over MCP)
│   └── oauth-server/                         # Mock OAuth 2.0 Authorization Server
├── python/agents/           # ADK Python agent definitions & toolsets
│   ├── cymbal-retail-agent/                  # Standard retail agent (Local ADK dev)
│   ├── cymbal-retail-agent-apigeellm/        # Governed agent w/Apigee LLM gateway (Local ADK dev)
│   └── cymbal-retail-agent-geap/             # Version for GEAP Agent Runtime
├── sharedflowbundles/       # Reusable Apigee flows (LLM extraction & cloud logging)
├── test/integration/        # Apickli BDD Cucumber automated integration suites
├── deploy-adk-cymbal-retail-agent.sh     # Automated GCP/Apigee deployer script
├── setup.sh                 # Main entrypoint provisioning script
└── run_integration_tests.sh                  # Automated BDD verification runner
```

---

## 🚀 Getting Started & Setup

### Prerequisites
* Google Cloud CLI (`gcloud`) authenticated with Project Admin permissions.
* Python `>=3.12` with `virtualenv` / `poetry` / `uv`.
* Node.js `>=18` (for BDD test execution).

### 1. Production Deployment & GCP Provisioning
To provision and deploy the entire enterprise infrastructure from scratch, set the values in `env.sh`, then run:

```bash
source env.sh 
./setup.sh
```

The script may take some time to complete. Upon successful deployment, the script will output the credentials needed for testing.

---

## 🧪 Testing and Verification

### 1. Testing Agents Locally with ADK Web UI
To interact with the agents locally using the ADK development server:
```bash
cd python/agents/cymbal-retail-agent # or cd python/agents/cymbal-retail-agent-apigeellm
uv sync
uv run adk web --reload_agents
```

### 2. Testing Remote Agent on GEAP via Client Web App
The project includes a web application client to test the live deployed GEAP agent, complete with OAuth 2.0 user authorization prompts.

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
   * Go to `http://localhost:9000` in your web browser.
   * Send a query requiring authentication (e.g. *"list all orders"* or *"check status of order 123"*).
   * Click **Login** on the consent card. A popup should briefly appear and a token will be generated.
   * Verify that subsequent order queries execute directly without prompting for login again.
   * Click **New Chat Session** and verify that login credentials are persisted correctly across sessions.

### Running Automated BDD Integration Suites
To execute live Apickli Cucumber validation against the Apigee Gateway proxies:
```bash
./run_integration_tests.sh
```


---

## 📄 License
Copyright 2026 Google LLC. Licensed under the [Apache License, Version 2.0](LICENSE.txt).
