# Apigee X LLM AI Gateway Deployment & Analytics Guide

This document details the automated deployment and analytics visualization process for the **Apigee X LLM AI Gateway** (`llm-ai-gateway-v1`), along with its supporting shared flows, data collectors, security policies, and product configurations.

---

## 1. Overview, Features & Gateway Configuration

The **Apigee X LLM AI Gateway** (`llm-ai-gateway-v1`) acts as a centralized enterprise AI governance, routing, and protection layer for Generative AI workloads.

### Gateway Capabilities
The gateway provides the following core capabilities out of the box:
- **Token Rate Limiting (Prompt Rate Limiting)**: Prevents traffic spikes based on incoming token count volume.
- **Token Quota Enforcement**: Enforces token-based consumption limits configured at the API Product level.
- **LLM Observability**: Captures detailed GenAI telemetry across seven Apigee X Data Collectors.
- **Semantic Caching**: Avoids redundant LLM calls by looking up semantically similar requests via Vector Search embeddings.
- **Basic Jailbreaking Protection**: Filters malicious prompts and prompt injection attacks using Model Armor.
- **Routing to Different LLMs**: Supports dynamic routing between models (e.g., Gemini Pro vs. Flash).
- **Routing Based on Prompt Complexity**: Uses embeddings and Vector Search to route simple vs. complex prompts to the optimal model tier.
- **Locally Hosted Hybrid Routing (Gemma)**: Supports routing to local Gemma instances (*to be finalized*).
- **Model Failover**: Automatically switches to a fallback model if the primary model endpoint experiences downtime or faults.
- **Anonymization & Pseudonymization**: Sanitizes Sensitive Data Protection (DLP) patterns in user prompts and model responses.

### Policy Execution Pipeline & Flow Architecture

The diagram below details the exact policy execution chain across `PreFlow`, `Flow: chat`, `TargetEndpoint`, and `PostFlow` in `llm-ai-gateway-v1`:

```mermaid
flowchart TD
    %% ==========================================
    %% Palette & Styles Google Cloud
    %% ==========================================
    classDef client fill:#E8F0FE,stroke:#4285F4,stroke-width:2px,color:#1967D2,font-weight:bold;
    classDef process fill:#FFFFFF,stroke:#5F6368,stroke-width:1.2px,color:#202124;
    classDef decision fill:#FEF7E0,stroke:#F9AB00,stroke-width:1.5px,color:#B06000,font-weight:bold;
    classDef primary fill:#E6F4EA,stroke:#34A853,stroke-width:2px,color:#137333,font-weight:bold;
    classDef fallback fill:#FFF0F0,stroke:#EA4335,stroke-width:1.5px,color:#C5221F,font-weight:bold;
    classDef secondary fill:#F1F3F4,stroke:#5F6368,stroke-width:1.5px,color:#3C4043;
    classDef fault fill:#FCE8E6,stroke:#EA4335,stroke-width:2px,stroke-dasharray: 4 4,color:#C5221F,font-weight:bold;

    %% Point d'entrée
    ClientReq(["Incoming Request<br/><code>/chat/completions</code>"]):::client --> PF1

    %% ==========================================
    %% 1. PreFlow
    %% ==========================================
    subgraph PreFlow["1. PreFlow: Auth & Headers"]
        direction TB
        PF1["<b>CORS Setup</b><br/>Handle preflight & headers"]:::process --> PF2["<b>API Key Check</b><br/>Validate credentials"]:::process
        PF2 --> PF3["<b>Normalize Headers</b><br/>Strip accept-encoding"]:::process
        PF3 --> PF4["<b>Extract Context</b><br/>Flags & model tier"]:::process
    end

    %% Transition 1 -> 2
    PF4 --> CF1

    %% ==========================================
    %% 2. Main Flow: Chat Pipeline (Stack vertical)
    %% ==========================================
    subgraph ChatFlow["2. Main Pipeline: Chat Execution"]
        direction TB
        CF1["<b>1. Ingestion</b><br/>Extract prompt & body"]:::process --> CF2["<b>2. Rate Limit</b><br/>Spike arrest check"]:::process
        CF2 --> CF3["<b>3. Safety & DLP</b><br/>Model Armor sanitization"]:::process
        CF3 --> CF4["<b>4. Semantic Cache</b><br/>Vector lookup"]:::process
        CF4 --> CF5["<b>5. Model Routing</b><br/>Complexity & rules"]:::process
        CF5 --> CF6["<b>6. Payload Builder</b><br/>Gemini format"]:::process
        CF6 --> CF7["<b>7. Quota Check</b><br/>Token bucket enforce"]:::process
    end

    %% Transition 2 -> 3
    CF7 --> T_Select

    %% ==========================================
    %% 3. Targets & Failover
    %% ==========================================
    subgraph Targets["3. Targets & Failover Chain"]
        direction TB
        T_Select{"Route Selection"}:::decision
        
        %% Routes
        T_Select -->|Default| PrimaryTarget["🎯 Primary Target<br/>Gemini Enterprise Pro"]:::primary
        T_Select -->|Local tier| GemmaTarget["🏠 Private Target<br/>Cloud Run Gemma 3 4B"]:::secondary
        
        %% Failovers
        PrimaryTarget -.->|5xx / 429 / Timeout| FallbackTarget["🔀 Fallback Target<br/>Gemini Enterprise Flash"]:::fallback
        GemmaTarget -.->|Down / Capacity| FallbackTarget
        
        %% Fault handler
        FallbackTarget -.->|All Exhausted| FaultHandler["⚠️ Fault Handler<br/>Graceful Degradation"]:::fault
    end

    %% Transition 3 -> 4 (Succès)
    PrimaryTarget --> PO1
    FallbackTarget --> PO1
    GemmaTarget --> PO1

    %% Sortie Erreur
    FaultHandler --> ErrorResp(["Return 503 / Degraded"]):::fault

    %% ==========================================
    %% 4. PostFlow
    %% ==========================================
    subgraph PostFlow["4. PostFlow: Response & Analytics"]
        direction TB
        PO1["<b>Cache Status</b><br/>Set Hit / Miss headers"]:::process --> PO2["<b>Parse Response</b><br/>Extract output"]:::process
        PO2 --> PO3["<b>DLP Redaction</b><br/>Mask sensitive data"]:::process
        PO3 --> PO4["<b>Cache Populate</b><br/>Store in vector DB"]:::process
        PO4 --> PO5["<b>Usage Metrics</b><br/>Tokens & latency"]:::process
        PO5 --> PO6["<b>Observability</b><br/>Cloud Logging & audit"]:::process
    end

    %% Point de sortie nominal
    PO6 --> ClientResp(["Return 200 OK"]):::client
```

---


### Control Headers (Processing Flags)
Each treatment or feature can be enabled or disabled per request using HTTP headers. By default, all standard features are enabled (`true`), while `x-force-cache` defaults to `false`:

| Header Name | Default | Description |
| :--- | :---: | :--- |
| `x-llm-cache` | `true` | Enables Semantic Caching lookup and population |
| `x-force-cache` *(or `x-llm-force-cache`)* | `false` | Forces Semantic Caching even on multi-turn conversations or tool-call turns (requires `x-llm-cache` to be `true` or omitted) |
| `x-llm-sanitize-user-prompt` | `true` | Enables user prompt cleaning/anonymization via DLP & Model Armor |
| `x-llm-routing` | `true` | Enables dynamic model routing based on prompt complexity |
| `x-llm-token-quota-enforce` | `true` | Enforces API Product LLM token consumption quotas |
| `x-llm-sanitize-model-response` | `true` | Enables model response cleaning/anonymization via DLP |
| `x-llm-prompt-rate-limiting` | `true` | Enables token-based load spike detection and prompt rate limiting |

### Model Resolution & Priority Routing Hierarchy
The gateway determines the target LLM model and routing tier during `JS-ParseRequestBody` execution according to the following strict order of precedence:

#### 1. Gemma / Local Execution Priority Route (`route_to_gemma = true`)
Gemma routing takes precedence over Cloud/Agent Platform models if requested explicitly:
- **Header Tier Override**: `x-llm-tier` or `x-model-tier` set to `local` or `gemma`.
- **Header Model Name**: `x-llm-model` or `x-model-name` containing `"gemma"` (case-insensitive).
- **Body / URI Model**: Model path or JSON field containing `"gemma"` (only when no explicit model header `x-llm-model` or `x-model-name` is provided).

*Result*: Sets `route_to_gemma = "true"`, sets `llm_routing_enabled = "false"`, and assigns `model` to the requested Gemma variant (defaults to `default_local_model` configured in `vertex_config.properties`, e.g. `gemma3:1b`).

#### 2. Cloud / Agent Platform Model Resolution Hierarchy (`route_to_gemma = false`)
When Gemma is not explicitly targeted, the gateway resolves the Agent Platform target model in strict priority order:
1. **Consolidated HTTP Header**: Value specified in `x-llm-model` (primary header) or `x-model-name` (secondary header alias). Always takes precedence over URI and JSON body models, and sets `llm_routing_enabled = "false"` to preserve the explicit header selection.
2. **URI Path / Request Payload**: Model extracted from the request URI path (e.g. `/publishers/google/models/{model}`, which takes precedence over the JSON body) or fallback JSON body `model` field.
3. **Default Property**: Fallback to `default_model` configured in `vertex_config.properties` (e.g. `gemini-2.5-pro` or `gemini-2.5-flash`).

#### 3. Dynamic Semantic Routing (`FC-LLMRouting`)
If dynamic routing is enabled (`x-llm-routing: true` or omitted by default) and the model has not been explicitly overridden via header (`x-llm-model` / `x-model-name`) or routed to Gemma, the gateway invokes the `FC-LLMRouting` Flow Callout policy. This delegates execution to the **`llm-routing-v2`** Shared Flow to classify prompt complexity and assign the optimal model tier.

##### Execution Steps of `llm-routing-v2`:
1. **Execution Condition**:
   - Executes only when `llm_routing_enabled != "false"`.
2. **Step 1: Keyword Route Pre-Check (`KVM-GetKeywordRoute`)**:
   - Executes `JS-PrepareKVMKey` to normalize the prompt and queries an Apigee Key-Value Map (`KVM-GetKeywordRoute`).
   - If an exact keyword match is found (e.g. mapping simple intent keywords directly to `"simple"`), vector embedding calls are bypassed to minimize latency and API cost.
3. **Step 2: Text Embedding Generation (`SCO-GetEmbeddings`)**:
   - If no KVM match occurred, a Service Callout (`SCO-GetEmbeddings`) sends the `request_prompt` to the Agent Platform Embeddings API (`text-embedding-005`).
   - `JS-ExtractEmbeddingVector` parses the response and extracts the 768-dimensional dense vector representation of the prompt.
4. **Step 3: Vector Search Nearest Neighbor Query (`SCO-VectorSearch`)**:
   - A Service Callout (`SCO-VectorSearch`) queries the configured Vector Search Index Endpoint (`routing_index_endpoint_id`).
   - Finds the nearest neighbor datapoint cluster (`simple` vs `complex` query reference embeddings) and returns the similarity distance score.
5. **Step 4: Model Decision & Variable Assignment (`JS-DetermineModelRoute`)**:
   - Evaluates the nearest neighbor `datapointId` prefix and sets the model tier dynamically from `vertex_config.properties`:
     - **`gemma_*` (Retail FAQ Intents)**: Sets `model = localModel` (`default_local_model`, e.g. `gemma3:1b`) and `route_to_gemma = "true"` (routes to private Gemma 3 instance).
     - **`simple_*` (Greetings & General Tasks)**: Sets `model = fallbackModel` (`default_fallback_model`, e.g. `gemini-2.5-flash`).
     - **`complex_*` (Complex Reasoning & Code)**: Sets `model = defaultModel` (`default_model`, e.g. `gemini-2.5-pro`).
   - Populates observability variables: `semantic_match_id` (datapoint ID) and `semantic_match_distance` (cosine distance score).

##### Vector Search Intent Generation & Upsert Script (`upsert_routing_embeddings.py`)
To populate or update the Vector Search Index with reference intent embeddings, run the automated provisioning script [`upsert_routing_embeddings.py`](upsert_routing_embeddings.py):

```bash
# Execute embedding generation and upsert to Vector Search
./upsert_routing_embeddings.py --project $PROJECT_ID --region $REGION --index-id $ROUTING_INDEX_ID
```

**How Vector Search Intent Generation Works**:
1. **Dataset Intent Categorization**: Defines structured prompt datasets categorized into `simple_*` (general tasks), `gemma_*` (retail FAQs like store hours, shipping, return policy), and `complex_*` (coding, architecture analysis).
2. **Text Embedding Generation**: Sends each intent text prompt to Agent Platform `text-embedding-005:predict` endpoint to extract a 768-dimensional floating point feature vector.
3. **Index Upsert**: Formats feature vectors into Agent Platform datapoint JSON payloads (`datapointId` + `featureVector`) and calls `gcloud ai indexes upsert-datapoints` to publish them to the Vector Search index.

### Semantic Caching Eligibility & Execution Flow

Semantic caching saves latency and LLM token costs by returning cached responses for semantically similar questions. **By default, semantic caching is enabled (`cache_enabled = "true"`)**, but the gateway automatically disables it when a request involves multi-turn conversation history or active tool executions so that responses remain contextually accurate.

#### Conditions Required for Semantic Cache Execution
For the semantic cache policies (`SCL-Semantic-Cache-Lookup` on the request path and `SCP-Semantic-Cache-Populate` on the response path) to run:

1. **Condition 1 — Not Disabled by Header (`x-llm-cache`)**:
   - The `x-llm-cache` HTTP header must be either omitted (defaults to `true`) or explicitly set to `true` (evaluated in `JS-ProcessCustomLLMHeaders.js`).
   - Passing `x-llm-cache: false` (or any value other than `true`) always disables caching for the request.
2. **Condition 2 — No Active Tool / Function Call Turn (`hasToolCallTurn == false`)**:
   - The conversation does not contain any executed tool or function call history (`role: "tool"`, `role: "function"`, `tool_calls`, `functionCall`, or `functionResponse` evaluated in `JS-ParseRequestBody.js`).
   - *Note*: Declaring available `tools` or `functionDeclarations` on the initial user prompt does **not** disable caching—only actual tool call/response turns in the conversation history disable it.
3. **Condition 3 — Single-Turn / Short Conversation History**:
   - **Native Vertex AI Format (`contents`)**: Must contain **at most 1 turn** (`contents.length <= 1`, i.e., the initial user question).
   - **OpenAI Format (`messages`)**: Must contain **at most 4 messages** (`messages.length <= 4`).

#### Forcing Cache Execution for Testing (`x-force-cache: true`)
Because multi-agent frameworks (such as ADK) frequently include multi-turn history or tool turns, testing semantic cache hits in an interactive session can be challenging. To simplify testing:
- You can pass the header **`x-force-cache: true`** (or its alias **`x-llm-force-cache: true`**; default is `false`).
- When **`x-llm-cache` is `true` (or omitted)** AND **`x-force-cache` is `true`**, **Conditions 2 and 3 are bypassed**: semantic caching executes based on the latest extracted user prompt regardless of conversation length or tool-call history.

#### What Happens When Semantic Cache Executes (`cache_enabled != "false"`)
- **On Request (`SCL-Semantic-Cache-Lookup`)**: Apigee generates an embedding for the user prompt and searches the Vector Search cache index.
  - **Cache HIT**: Returns the cached response immediately (`X-Cache-Status: HIT`), bypassing LLM routing and backend model invocation.
  - **Cache MISS**: Proceeds to model routing and invokes the target LLM (`X-Cache-Status: MISS`).
- **On Response (`SCP-Semantic-Cache-Populate`)**: When the backend LLM returns a non-empty response (`response.content != null`), Apigee stores the response in the semantic cache for future similar requests.

```mermaid
flowchart TD
    classDef start fill:#E8F0FE,stroke:#4285F4,stroke-width:2px,color:#1967D2,font-weight:bold;
    classDef check fill:#FEF7E0,stroke:#F9AB00,stroke-width:1.5px,color:#B06000,font-weight:bold;
    classDef enabled fill:#E6F4EA,stroke:#34A853,stroke-width:2px,color:#137333,font-weight:bold;
    classDef bypassed fill:#FCE8E6,stroke:#EA4335,stroke-width:1.5px,color:#C5221F,font-weight:bold;
    classDef process fill:#FFFFFF,stroke:#5F6368,stroke-width:1.2px,color:#202124;

    Req(["Incoming Chat Request"]):::start --> C1{"1. Header Check<br/>Is <code>x-llm-cache</code> omitted or <code>true</code>?"}:::check

    C1 -- "No (false)" --> Bypass["<b>Cache Disabled</b><br/><code>cache_enabled = false</code>"]:::bypassed
    C1 -- "Yes" --> ForceCheck{"Force Cache Override?<br/>Is <code>x-force-cache: true</code>?"}:::check

    ForceCheck -- "Yes (Bypass Conditions 2 &amp; 3)" --> Active["<b>Cache Enabled</b><br/><code>cache_enabled = true</code>"]:::enabled
    ForceCheck -- "No (default: false)" --> C2{"2. Tool History Check<br/>Any <code>functionCall</code>, <code>functionResponse</code>,<br/><code>tool_calls</code>, or <code>tool/function</code> role?"}:::check

    C2 -- "Yes (hasToolCallTurn)" --> Bypass
    C2 -- "No" --> C3{"3. Turn Count Check<br/>Vertex: <code>contents.length &lt;= 1</code><br/>OpenAI: <code>messages.length &lt;= 4</code>"}:::check

    C3 -- "No (Multi-turn)" --> Bypass
    C3 -- "Yes (Initial turn)" --> Active

    Bypass --> CallLLM["Call Target LLM Directly<br/>(Skip Lookup &amp; Populate)"]:::process

    Active --> Lookup["<b>SCL-Semantic-Cache-Lookup</b><br/>Query Vector Search Cache"]:::process
    Lookup --> HitMiss{"Similar Prompt<br/>Found in Cache?"}:::check

    HitMiss -- "HIT" --> ReturnCached(["Return Cached Response Immediately<br/><code>X-Cache-Status: HIT</code>"]):::enabled
    HitMiss -- "MISS" --> CallLLMWithCache["Call Target LLM<br/><code>X-Cache-Status: MISS</code>"]:::process
    CallLLMWithCache --> Populate["<b>SCP-Semantic-Cache-Populate</b><br/>Store LLM Response in Cache"]:::enabled
```

### Mandatory Configuration: `vertex_config.properties` (Single Source of Truth)
Before deploying, you **must configure** the following property values in `vertex_config.properties` within both the **`llm-routing-v2` shared flow** (`sharedflowbundles/llm-routing-v2/sharedflowbundle/resources/properties/vertex_config.properties`) and the **`llm-ai-gateway-v1` API proxy** (`proxies/llm-ai-gateway-v1/apiproxy/resources/properties/vertex_config.properties`):

```properties
# Common
region=<your-gcp-region>
project=<your-project-id>
project_number=<your-project-number>
index_endpoint_dns=<retrieve-from-vector-search-dns>
default_model=gemini-2.5-pro
default_fallback_model=gemini-2.5-flash
default_local_model=gemma3:1b

# Routing (Dynamic routing based on prompt complexity)
routing_index_endpoint_id=<retrieve-from-vector-search-endpoint-id>
routing_deployed_index_id=semantic_routing_index_endpoint_deployment
routing_index_id=<retrieve-from-vector-search-index-id>

# Cache (Semantic Caching via Vector Search)
cache_index_endpoint_id=<retrieve-from-vector-search-endpoint-id>
cache_deployed_index_id=semantic_cache_index_endpoint_deployment
cache_index_id=<retrieve-from-vector-search-index-id>
```

#### Updating Default, Fallback, or Local Models (Zero Code Changes Required)
All model names across the gateway are **100% externalized** into `vertex_config.properties`—no model identifiers (`gemini-2.5-pro`, `gemini-2.5-flash`, `gemma3:1b`, etc.) are hardcoded in any JavaScript policy (`JS-ProcessCustomLLMHeaders.js`, `JS-ParseRequestBody.js`, `JS-DetermineModelRoute.js`, `JS-ChangeToFallbackModel.js`, `JS-PrepareFailoverPayload.js`, `JS-ProcessFailoverResponse.js`, `JS-SetFailover.js`), XML policy/target, or in `deploy-llm-ai-gateway.sh`:
- **Model-Agnostic Fallback & Downgrade**: `JS-ChangeToFallbackModel.js` switches directly to `default_fallback_model` (or `x-llm-fallback-model`) without relying on `-pro` or `-flash` naming conventions. This supports any future model combination (for example, `default_model=gemini-3.8-flash` and `default_fallback_model=gemini-3.6-flash`).
- **Dynamic API Product Quotas**: During deployment, `deploy-llm-ai-gateway.sh` reads `default_model`, `default_fallback_model`, and `default_local_model` directly from `vertex_config.properties` (unless overridden via environment variables `DEFAULT_MODEL`, `DEFAULT_FALLBACK_MODEL`, `DEFAULT_LOCAL_MODEL`) and dynamically injects them into the `llm-ai-gateway-product` LLM quota operations.

---

## 2. Automated Deployment Script (`deploy-llm-ai-gateway.sh`)

The deployment script [`deploy-llm-ai-gateway.sh`](deploy-llm-ai-gateway.sh) automates the provisioning of the gateway on Apigee X. It orchestrates:

1. **Service Account Provisioning (`apigee-vertex-ai-caller`)**:
   - Provisions the dedicated runtime Service Account (`apigee-vertex-ai-caller@${PROJECT_ID}.iam.gserviceaccount.com`).
   - Assigns minimal least-privilege IAM roles:
     - **`roles/run.invoker` (Cloud Run Invoker)**: **Mandatory** for `llm-ai-gateway-v1` and `llm-routing-v2` to authenticate and invoke private Gemma 3 microservices deployed on Cloud Run.
     - **`roles/aiplatform.user` (Agent Platform User)**: Required to call Agent Platform Gemini prediction models and Vector Search embedding endpoints.
     - **`roles/dlp.user` & `roles/dlp.reader`**: Required for Cloud DLP real-time PII de-identification.
     - **`roles/modelarmor.user` & `roles/modelarmor.viewer`**: Required for Model Armor responsible AI template execution.
   - Binds Google Cloud Apigee Service Agent (`service-${PROJECT_NUMBER}@gcp-sa-apigee.iam.gserviceaccount.com`) token creation and user permissions (`roles/iam.serviceAccountUser`, `roles/iam.serviceAccountTokenCreator`) so Apigee can impersonate this account at runtime.
2. **Apigee X Data Collectors & Custom Analytics Report**:
   - Creates seven structured data collectors for LLM observability and reporting:
     - `dc_candidates_token_count_v2` (`INTEGER`)
     - `dc_cost_center_v2` (`STRING`)
     - `dc_model_v2` (`STRING`)
     - `dc_prompt_token_count_v2` (`INTEGER`)
     - `dc_response_type_v2` (`STRING`)
     - `dc_time_to_first_token_v2` (`INTEGER`)
     - `dc_total_token_count_v2` (`INTEGER`)
   - Creates or updates the Apigee Custom Analytics Report **`llm-ai-gateway-report`** configured with dimensions (`api_product`, `dc_model_v2`, `developer_app`) and metrics (`sum(dc_candidates_token_count_v2)`, `sum(dc_prompt_token_count_v2)`, `sum(dc_total_token_count_v2)`, `avg(dc_time_to_first_token_v2)`, `max(dc_time_to_first_token_v2)`, `min(dc_time_to_first_token_v2)`).
3. **KeyValueMap (`model-armor-config-v2`)**:
   - Provisions an environment-scoped KVM `model-armor-config-v2` containing the `modelArmorTemplate` key configured via the `$MODEL_ARMOR_TEMPLATE` environment variable.
4. **Shared Flows Deployment**:
   - `llm-modelarmor-dlp-v1`: Enforces Model Armor responsible AI governance and Sensitive Data Protection (DLP) de-identification.
   - `llm-routing-v2`: Routes requests dynamically and handles model failovers.
5. **API Proxy Deployment (`llm-ai-gateway-v1`)**:
   - Deploys the GenAI proxy bundle with token count extraction, semantic caching, routing, and quota enforcement policies.
6. **Developer & Developer App Configuration**:
   - Provisions developer `cymbal-retail-dev@example.com` (`cymbal-retail-dev`).
   - Provisions the API Product `llm-ai-gateway-product` with both proxy operations and per-model **LLM Token Quotas** dynamically populated from `vertex_config.properties`:
     - **`default_model`** (e.g. `gemini-2.5-pro`): `POST` operations limited to **10,000 tokens every 5 minutes**.
     - **`default_local_model`** (e.g. `gemma3:1b`): `POST` operations limited to **50,000 tokens every 5 minutes**.
     - **`default_fallback_model`** (e.g. `gemini-2.5-flash`): `POST` operations limited to **100,000 tokens every 5 minutes**.
7. **Application Provisioning (`llm-ai-gateway-app`)**:
   - Connects the developer and API product to issue an API consumer key.
8. **Secret Manager Secret Storage (`llm-ai-gateway-client-id`)**:
   - Stores the generated `llm-ai-gateway-app` consumer key in Google Cloud Secret Manager for automated, secure authentication by downstream agents.

---

## 3. Prerequisites

Before running the deployment script, ensure you have authenticated with Google Cloud CLI and set the mandatory environment variables:

```bash
# Authenticate with Google Cloud
gcloud auth login
gcloud auth application-default login

# Export your target Google Cloud Project ID, Apigee Environment, and Model Armor Template
export PROJECT_ID="your-gcp-project-id"
export APIGEE_ENV="your-apigee-environment"
export MODEL_ARMOR_TEMPLATE="projects/your-gcp-project-id/locations/your-region/templates/your-model-armor-template"

# Optional: Set a custom access token (otherwise automatically fetched)
# export TOKEN=$(gcloud auth application-default print-access-token)
```

Ensure the script is executable:

```bash
chmod +x ./deploy-llm-ai-gateway.sh
```

---

## 4. Executing the Deployment Script

Run the deployment script from the root repository directory:

```bash
./deploy-llm-ai-gateway.sh
```

### Expected Output
- The script checks or creates the `apigee-vertex-ai-caller` service account and applies IAM policy bindings.
- It verifies and creates all seven LLM `dc_*_v2` Data Collectors.
- It provisions/updates the Custom Analytics Report `llm-ai-gateway-report`.
- It creates or updates the `model-armor-config-v2` KVM with the `modelArmorTemplate` entry.
- It deploys the `llm-modelarmor-dlp-v1` and `llm-routing-v2` shared flows.
- It deploys the `llm-ai-gateway-v1` proxy.
- It configures the API Product `llm-ai-gateway-product` via Apigee REST API v1.
- It creates the `llm-ai-gateway-app` developer application and prints out the generated **API Key (`consumerKey`)** at the console summary.
- It provisions/updates the Secret Manager secret `llm-ai-gateway-client-id` containing the consumer key for downstream agent authentication.

---

## 5. Visualizing LLM AI Gateway Analytics

Once requests are flowing through your deployed LLM AI Gateway, you can inspect real-time metrics and telemetry using either the Apigee UI Custom Report or the local Go analytics dashboard provided in `./llm-ai-gateway-analytics`.

### A. Apigee UI Custom Report (`llm-ai-gateway-report`)

The deployment script automatically provisions the `llm-ai-gateway-report` Custom Report. If you need to construct or update it manually via curl, use the following request:

```bash
export PROJECT_ID="your-gcp-project-id"
export TOKEN=$(gcloud auth print-access-token)

curl -X POST "https://apigee.googleapis.com/v1/organizations/${PROJECT_ID}/reports" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "llm-ai-gateway-report",
    "displayName": "llm-ai-gateway-report",
    "dimensions": [
      "api_product",
      "dc_model_v2",
      "developer_app"
    ],
    "metrics": [
      {
        "name": "dc_candidates_token_count_v2",
        "function": "sum"
      },
      {
        "name": "dc_prompt_token_count_v2",
        "function": "sum"
      },
      {
        "name": "dc_total_token_count_v2",
        "function": "sum"
      },
      {
        "name": "dc_time_to_first_token_v2",
        "function": "avg"
      },
      {
        "name": "dc_time_to_first_token_v2",
        "function": "max"
      },
      {
        "name": "dc_time_to_first_token_v2",
        "function": "min"
      }
    ]
  }'
```

### B. Local Go Analytics Web UI

1. Navigate to the analytics directory:
   ```bash
   cd ./llm-ai-gateway-analytics
   ```

2. Export your Apigee environment variable (and project ID if not already exported):
   ```bash
   export APIGEE_ENVIRONMENT="your-apigee-environment"
   export GOOGLE_CLOUD_PROJECT="$PROJECT_ID"
   ```

3. Run the Go web server:
   ```bash
   go run .
   ```

4. **Open the Web UI**:
   - **In Cloud Shell**: Click on the **Web Preview** icon (top right of the terminal console) and select **Preview on port 8080**.
   - **Locally**: Open your web browser and navigate to:
     ```
     http://localhost:8080
     ```

---

## 6. Testing the Gateway

Once your API proxy is deployed, you can test both OpenAI-compatible completions and native Agent Platform Gemini endpoints. Set the required variables first:

```bash
export APIGEE_HOSTNAME="your-apigee-hostname"
export API_KEY="your-consumer-key"
export PROJECT_ID="your-gcp-project-id"
export REGION="your-vertexai-region" # e.g., europe-west1
```

### Option A: OpenAI-Compatible Chat Completions Endpoint

```bash
curl -H "x-apikey: $API_KEY" -H "Content-Type: application/json; charset=utf-8" -d '{"model": "gemini-2.5-pro", "stream": false, "messages": [{"role": "user", "content": "when is the next eclispe in france?"}]}' https://$APIGEE_HOSTNAME/v1/llm-ai-gateway/chat/completions -vk
```

### Option B: Agent Platform Gemini generateContent Endpoint

```bash
curl -s -X POST "https://$APIGEE_HOSTNAME/v1/llm-ai-gateway/projects/$PROJECT_ID/locations/$REGION/publishers/google/models/gemini-2.5-pro:generateContent" \
  -H "x-apikey: $API_KEY" \
  -H "Content-Type: application/json; charset=utf-8" \
  -d '{"contents": [{"role": "USER", "parts": [{"text": "What does the Orion constellation look like?"}]}]}' -vk | jq
```

---

## 7. Automated BDD Regression Testing

The repository includes a dedicated Cucumber BDD regression test suite covering all LLM AI Gateway features and security behaviors in [`test/integration/features/llm-ai-gateway.feature`](test/integration/features/llm-ai-gateway.feature):

* **Unauthorized Requests (401)**: Missing and invalid API key rejection via `VA-VerifyAPIKey`.
* **OpenAI-Compatible Payload**: `POST /v1/llm-ai-gateway/chat/completions` validation.
* **Native Chat Payload**: `POST /v1/llm-ai-gateway/chat` validation.
* **Dynamic Hybrid Model Routing**: `x-model-tier: frontier` and `x-llm-routing: false`.
* **Model Overrides**: `x-llm-model: gemini-2.5-pro` explicit header override.
* **Prompt Rate Limiting & Token Quotas**: `x-llm-prompt-rate-limiting` and `x-llm-token-quota-enforce`.
* **Responsible AI & PII Sanitization**: `x-llm-sanitize-user-prompt` and `x-llm-sanitize-model-response`.
* **Native Agent Platform Endpoint**: `POST /v1/llm-ai-gateway/projects/{PROJECT_ID}/locations/us-central1/publishers/google/models/gemini-2.5-flash:generateContent`.
* **Invalid Route Handling (404)**: Unknown route error response.

To execute the LLM AI Gateway regression tests as part of the unified test suite:
```bash
./run_integration_tests.sh
```


