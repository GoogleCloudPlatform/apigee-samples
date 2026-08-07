# Cymbal Retail Agent

An autonomous retail customer service agent built with Google's **Agent Development Kit (ADK)** and powered by **Gemini Enterprise Agent Platform**. This agent coordinates specialized domain sub-agents (`ordersagent`, `customersagent`, `returnsagent`, and `shippingagent`) to handle customer inquiries via a standardized **Model Context Protocol (MCP)** toolset routed through Apigee. 

---

## 🏛️ Architecture & Tool Integration

The agent connects to backend domain services via the native Apigee MCP Gateway (`cymbal-discovery-v1`). All tools are defined via an `MCPToolset` instance that communicate using JSON-RPC 2.0 over HTTP/HTTPS.

---

## 🚀 Local Setup & Development

### 1. Environment Configuration
Ensure your local `.env` file is populated with your Google Cloud and Apigee configuration:
```ini
GOOGLE_CLOUD_PROJECT="apigee-ai"
GOOGLE_CLOUD_LOCATION="us-central1"
APIGEE_HOSTNAME="34.54.87.114.nip.io"
GOOGLE_GENAI_USE_VERTEXAI="TRUE"
GOOGLE_CLOUD_STORAGE_BUCKET="apigee-ai_cymbal_retail_agent"
MODEL_NAME="gemini-2.5-flash"
AGENT_SERVICE_ACCOUNT="llm-cymbal-retail-agent@apigee-ai.iam.gserviceaccount.com"
APIGEE_LLM="/v1/adk-retail-agent-llm-governance"
```

### 2. Virtual Environment Synchronization
We recommend using **Python 3.13** to ensure full compatibility with asynchronous Server-Sent Events (SSE) in Uvicorn/Starlette during interactive testing:
```bash
uv sync --python 3.13
```

### 3. Running ADK Web UI Locally
To launch the interactive web playground UI:
```bash
source .env
uv run adk web --reload_agents . --port 8000
```
Open your web browser and navigate to **http://127.0.0.1:8000**.
