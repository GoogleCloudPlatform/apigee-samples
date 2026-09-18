#!/bin/bash

# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# ==============================================================================
# Script: deploy-llm-ai-gateway.sh
# Purpose: Deploys the Apigee X LLM AI Gateway including service account,
#          data collectors, shared flows, API proxy, developer, product, and app.
# ==============================================================================

set -e

sed_i() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i "" "$@"
  else
    sed -i "$@"
  fi
}

echo "===================================================================="
echo "Starting Apigee X LLM AI Gateway Deployment (deploy-llm-ai-gateway.sh)"
echo "===================================================================="

# Check mandatory environment variables
PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"
if [ -z "$PROJECT_ID" ] || [ "$PROJECT_ID" = "PROJECT_ID_TO_SET" ] || [ "$PROJECT_ID" = "(unset)" ]; then
  echo "ERROR: Mandatory environment variable PROJECT_ID is not set."
  echo "Usage: export PROJECT_ID=\"<your-gcp-project-id>\""
  exit 1
fi

APIGEE_ENV="${APIGEE_ENV:-test-env}"

if [ -z "$MODEL_ARMOR_TEMPLATE" ]; then
  MODEL_ARMOR_REGION="${MODEL_ARMOR_REGION:-${VERTEXAI_REGION:-${GCP_PROJECT_REGION:-us-central1}}}"
  MODEL_ARMOR_TEMPLATE_ID="${MODEL_ARMOR_TEMPLATE_ID:-llm-governance-template}"
  MODEL_ARMOR_TEMPLATE="projects/${PROJECT_ID}/locations/${MODEL_ARMOR_REGION}/templates/${MODEL_ARMOR_TEMPLATE_ID}"
  echo "INFO: MODEL_ARMOR_TEMPLATE not explicitly set. Auto-configured as: $MODEL_ARMOR_TEMPLATE"
fi

REGION="${VERTEXAI_REGION:-${GCP_PROJECT_REGION:-us-central1}}"

# Ensure apigeecli CLI tool is installed or available in PATH
if ! command -v apigeecli &> /dev/null; then
  echo "INFO: apigeecli not found in PATH. Checking ~/.apigeecli/bin..."
  if [ -x "$HOME/.apigeecli/bin/apigeecli" ]; then
    export PATH="$PATH:$HOME/.apigeecli/bin"
  else
    echo "INFO: Installing apigeecli..."
    curl -s https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | bash
    export PATH="$PATH:$HOME/.apigeecli/bin"
  fi
fi

# Obtain access token if not already set
if [ -z "$TOKEN" ]; then
  echo "INFO: Obtaining Google Cloud authentication access token..."
  TOKEN=$(gcloud auth application-default print-access-token)
fi
export TOKEN

# Retrieve Project Number for Apigee Service Agent IAM bindings
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
echo "INFO: Project ID: $PROJECT_ID (Number: $PROJECT_NUMBER), Apigee Env: $APIGEE_ENV"

# ==============================================================================
# Step 1: Create Service Account (apigee-vertex-ai-caller) and assign IAM roles
# ==============================================================================
SERVICE_ACCOUNT_NAME="apigee-vertex-ai-caller"
SA_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo ""
echo "--- Step 1: Configuring Service Account ($SERVICE_ACCOUNT_NAME) ---"
if ! gcloud iam service-accounts describe "$SA_EMAIL" --project "$PROJECT_ID" &>/dev/null; then
  echo "INFO: Service Account $SERVICE_ACCOUNT_NAME does not exist. Creating..."
  gcloud iam service-accounts create "$SERVICE_ACCOUNT_NAME" \
    --display-name="Apigee Vertex AI Caller SA for LLM AI Gateway" \
    --project "$PROJECT_ID"
  echo "INFO: Waiting for service account creation to propagate..."
  sleep 10
else
  echo "INFO: Service Account $SERVICE_ACCOUNT_NAME already exists. Skipping creation."
fi

# Function to add IAM role binding to service account
assign_sa_role() {
  local role=$1
  echo "Assigning role $role to $SA_EMAIL..."
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$SA_EMAIL" \
    --role="$role" \
    --condition=None \
    >/dev/null 2>&1 || true
}

# Assign required roles:
# - Cloud run invoker: roles/run.invoker
# - Agent platform user: roles/aiplatform.user
# - DLP user and viewer: roles/dlp.user, roles/dlp.reader
# - Model Armor user and viewer: roles/modelarmor.user, roles/modelarmor.viewer
assign_sa_role "roles/run.invoker"
assign_sa_role "roles/aiplatform.user"
assign_sa_role "roles/dlp.user"
assign_sa_role "roles/dlp.reader"
assign_sa_role "roles/modelarmor.user"
assign_sa_role "roles/modelarmor.viewer"

# Grant Google Cloud Apigee Service Agent permissions to impersonate this Service Account
echo "INFO: Granting Apigee Service Agent permissions to use custom Service Account..."
APIGEE_SA="serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-apigee.iam.gserviceaccount.com"
gcloud iam service-accounts add-iam-policy-binding "$SA_EMAIL" \
  --member="$APIGEE_SA" \
  --role="roles/iam.serviceAccountUser" \
  --project="$PROJECT_ID" >/dev/null 2>&1 || true

gcloud iam service-accounts add-iam-policy-binding "$SA_EMAIL" \
  --member="$APIGEE_SA" \
  --role="roles/iam.serviceAccountTokenCreator" \
  --project="$PROJECT_ID" >/dev/null 2>&1 || true

# ==============================================================================
# Step 2: Create Data Collectors on Apigee X
# ==============================================================================
echo ""
echo "--- Step 2: Creating Apigee X Data Collectors ---"

create_data_collector() {
  local name=$1
  local dtype=$2
  local desc=$3
  echo "Creating Data Collector: $name (Type: $dtype)..."
  apigeecli datacollectors create -n "$name" -p "$dtype" -d "$desc" \
    --org "$PROJECT_ID" --token "$TOKEN" >/dev/null 2>&1 || \
    echo "INFO: Data Collector $name may already exist."
}

# Required Data Collectors:
# dc_candidates_token_count_v2 -> Integer
# dc_cost_center_v2            -> String
# dc_model_v2                  -> String
# dc_prompt_token_count_v2     -> Integer
# dc_response_type_v2          -> String
# dc_time_to_first_token_v2    -> Integer
# dc_total_token_count_v2      -> Integer
create_data_collector "dc_candidates_token_count_v2" "INTEGER" "LLM Candidates Token Count v2"
create_data_collector "dc_cost_center_v2"            "STRING"  "LLM Cost Center v2"
create_data_collector "dc_model_v2"                  "STRING"  "LLM Model Name v2"
create_data_collector "dc_prompt_token_count_v2"     "INTEGER" "LLM Prompt Token Count v2"
create_data_collector "dc_response_type_v2"          "STRING"  "LLM Response Type v2"
create_data_collector "dc_time_to_first_token_v2"    "INTEGER" "LLM Time to First Token v2 (ms)"
create_data_collector "dc_total_token_count_v2"      "INTEGER" "LLM Total Token Count v2"

# ==============================================================================
# Step 2.5: Create Custom Analytics Report (llm-ai-gateway-report)
# ==============================================================================
echo ""
echo "--- Step 2.5: Creating Custom Analytics Report (llm-ai-gateway-report) ---"
REPORT_NAME="llm-ai-gateway-report"

REPORT_PAYLOAD=$(jq -n \
  --arg name "$REPORT_NAME" \
  '{
    name: $name,
    displayName: $name,
    dimensions: [
      "api_product",
      "dc_model_v2",
      "developer_app"
    ],
    metrics: [
      {
        name: "dc_candidates_token_count_v2",
        function: "sum"
      },
      {
        name: "dc_prompt_token_count_v2",
        function: "sum"
      },
      {
        name: "dc_total_token_count_v2",
        function: "sum"
      },
      {
        name: "dc_time_to_first_token_v2",
        function: "avg"
      },
      {
        name: "dc_time_to_first_token_v2",
        function: "max"
      },
      {
        name: "dc_time_to_first_token_v2",
        function: "min"
      }
    ]
  }')

echo "Checking if Custom Report $REPORT_NAME exists..."
REPORT_HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer $TOKEN" \
  "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/reports/$REPORT_NAME")

REPORT_TMP=$(mktemp)
if [ "$REPORT_HTTP_STATUS" -eq 200 ]; then
  echo "INFO: Custom Report $REPORT_NAME exists. Updating..."
  REPORT_HTTP_RES=$(curl -s -X PUT \
    "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/reports/$REPORT_NAME" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "$REPORT_PAYLOAD" \
    -o "$REPORT_TMP" \
    -w "%{http_code}")
else
  echo "INFO: Custom Report $REPORT_NAME does not exist. Creating..."
  REPORT_HTTP_RES=$(curl -s -X POST \
    "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/reports" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "$REPORT_PAYLOAD" \
    -o "$REPORT_TMP" \
    -w "%{http_code}")
fi

if [ "$REPORT_HTTP_RES" -lt 200 ] || [ "$REPORT_HTTP_RES" -ge 300 ]; then
  echo "WARNING: Failed to configure Custom Report $REPORT_NAME (HTTP $REPORT_HTTP_RES)"
  cat "$REPORT_TMP"
  rm -f "$REPORT_TMP"
else
  rm -f "$REPORT_TMP"
  echo "INFO: Custom Report $REPORT_NAME configured successfully."
fi

# ==============================================================================
# Step 3: Create KeyValueMap (model-armor-config-v2) for Model Armor Template
# ==============================================================================
echo ""
echo "--- Step 3: Creating KeyValueMap (model-armor-config-v2) ---"
echo "Creating KVM: model-armor-config-v2 in environment $APIGEE_ENV..."
apigeecli kvms create --name "model-armor-config-v2" \
  --env "$APIGEE_ENV" --org "$PROJECT_ID" --token "$TOKEN" >/dev/null 2>&1 || \
  echo "INFO: KVM model-armor-config-v2 may already exist."

echo "Configuring KVM entry modelArmorTemplate..."
apigeecli kvms entries create --map "model-armor-config-v2" \
  --key "modelArmorTemplate" --value "$MODEL_ARMOR_TEMPLATE" \
  --env "$APIGEE_ENV" --org "$PROJECT_ID" --token "$TOKEN" >/dev/null 2>&1 || \
  apigeecli kvms entries update --map "model-armor-config-v2" \
  --key "modelArmorTemplate" --value "$MODEL_ARMOR_TEMPLATE" \
  --env "$APIGEE_ENV" --org "$PROJECT_ID" --token "$TOKEN"

# ==============================================================================
# Step 3.5: Resolve Vertex AI Vector Search & Gemma Target Configuration
# ==============================================================================
echo ""
echo "--- Step 3.5: Resolving Vertex AI Vector Search & Gemma Endpoints ---"

# Discover Vector Search Index Endpoint
echo "Discovering Vector Search Index Endpoint in project $PROJECT_ID ($REGION)..."
INDEX_ENDPOINT_JSON=$(gcloud ai index-endpoints list --project="$PROJECT_ID" --region="$REGION" --format="json" 2>/dev/null || echo "[]")
INDEX_ENDPOINT_ID=$(echo "$INDEX_ENDPOINT_JSON" | jq -r '.[] | select(.displayName=="workshop-index-endpoint") | .name' 2>/dev/null | head -n1 | awk -F'/' '{print $NF}')
if [ -z "$INDEX_ENDPOINT_ID" ]; then
  INDEX_ENDPOINT_ID=$(echo "$INDEX_ENDPOINT_JSON" | jq -r '.[0].name // empty' 2>/dev/null | awk -F'/' '{print $NF}')
fi

INDEX_ENDPOINT_DESC="{}"
INDEX_ENDPOINT_DNS=""
if [ -n "$INDEX_ENDPOINT_ID" ]; then
  echo "INFO: Found Vector Search Index Endpoint ID: $INDEX_ENDPOINT_ID"
  INDEX_ENDPOINT_DESC=$(gcloud ai index-endpoints describe "$INDEX_ENDPOINT_ID" --project="$PROJECT_ID" --region="$REGION" --format="json" 2>/dev/null || echo "{}")
  INDEX_ENDPOINT_DOMAIN=$(echo "$INDEX_ENDPOINT_DESC" | jq -r '.publicEndpointDomainName // empty' 2>/dev/null)
  if [ -n "$INDEX_ENDPOINT_DOMAIN" ]; then
    INDEX_ENDPOINT_DNS=$(echo "$INDEX_ENDPOINT_DOMAIN" | cut -d'.' -f1)
    echo "INFO: Resolved Vector Search Public DNS Prefix: $INDEX_ENDPOINT_DNS"
  fi
fi

# Discover Vector Search Indexes (Routing and Cache)
echo "Discovering Vector Search Indexes in project $PROJECT_ID ($REGION)..."
INDEXES_JSON=$(gcloud ai indexes list --project="$PROJECT_ID" --region="$REGION" --format="json" 2>/dev/null || echo "[]")
ROUTING_INDEX_ID=$(echo "$INDEXES_JSON" | jq -r 'sort_by(.createTime) | reverse | .[] | select(.displayName=="semantic-routing-index") | .name' 2>/dev/null | head -n1 | awk -F'/' '{print $NF}')
CACHE_INDEX_ID=$(echo "$INDEXES_JSON" | jq -r 'sort_by(.createTime) | reverse | .[] | select(.displayName=="semantic-cache-index") | .name' 2>/dev/null | head -n1 | awk -F'/' '{print $NF}')

[ -n "$ROUTING_INDEX_ID" ] && echo "INFO: Found Semantic Routing Index ID: $ROUTING_INDEX_ID" || echo "INFO: Semantic Routing Index not yet found in project."
[ -n "$CACHE_INDEX_ID" ] && echo "INFO: Found Semantic Cache Index ID: $CACHE_INDEX_ID" || echo "INFO: Semantic Cache Index not yet found in project."

# Discover Deployed Index IDs on Endpoint
ROUTING_DEPLOYED_INDEX_ID=""
CACHE_DEPLOYED_INDEX_ID=""
if [ -n "$INDEX_ENDPOINT_DESC" ] && [ "$INDEX_ENDPOINT_DESC" != "{}" ]; then
  if [ -n "$ROUTING_INDEX_ID" ]; then
    ROUTING_DEPLOYED_INDEX_ID=$(echo "$INDEX_ENDPOINT_DESC" | jq -r '.deployedIndexes[]? | select(.index | endswith("'"${ROUTING_INDEX_ID}"'")) | .id' 2>/dev/null | head -n1)
  fi
  if [ -n "$CACHE_INDEX_ID" ]; then
    CACHE_DEPLOYED_INDEX_ID=$(echo "$INDEX_ENDPOINT_DESC" | jq -r '.deployedIndexes[]? | select(.index | endswith("'"${CACHE_INDEX_ID}"'")) | .id' 2>/dev/null | head -n1)
  fi
fi

# Fallback defaults if not dynamically resolved
ROUTING_DEPLOYED_INDEX_ID="${ROUTING_DEPLOYED_INDEX_ID:-semantic_routing_index_endpoint_deployment}"
CACHE_DEPLOYED_INDEX_ID="${CACHE_DEPLOYED_INDEX_ID:-semantic_cache_index_endpoint_deployment}"
DEFAULT_LOCAL_MODEL="${DEFAULT_LOCAL_MODEL:-gemma3:4b}"
DEFAULT_MODEL="${DEFAULT_MODEL:-gemini-2.5-flash}"
DEFAULT_FALLBACK_MODEL="${DEFAULT_FALLBACK_MODEL:-gemini-2.5-flash}"

# Discover Gemma Cloud Run Service URL
echo "Discovering Gemma Cloud Run service..."
GEMMA_SERVICE_NAME="${GEMMA_SERVICE_NAME:-gemma-cpu-router}"
GEMMA_URL=$(gcloud run services describe "$GEMMA_SERVICE_NAME" --region="$REGION" --project="$PROJECT_ID" --format="value(status.url)" 2>/dev/null || true)
if [ -z "$GEMMA_URL" ]; then
  GEMMA_URL=$(gcloud run services list --project="$PROJECT_ID" --region="$REGION" --format="value(status.url)" 2>/dev/null | grep "gemma" | head -n1 || true)
fi

if [ -n "$GEMMA_URL" ]; then
  echo "INFO: Found active Gemma Cloud Run URL: $GEMMA_URL"
else
  echo "INFO: Gemma Cloud Run service not resolved from live services; using project-derived URL."
  GEMMA_URL="https://${GEMMA_SERVICE_NAME}-${PROJECT_NUMBER}.${REGION}.run.app"
fi

inject_vertex_config_properties() {
  local prop_file=$1
  if [ -f "$prop_file" ]; then
    echo "Injecting Vector Search & Gemma properties into $prop_file..."
    sed_i "s|^project=.*|project=$PROJECT_ID|g" "$prop_file"
    sed_i "s|^project_number=.*|project_number=$PROJECT_NUMBER|g" "$prop_file"
    sed_i "s|^region=.*|region=$REGION|g" "$prop_file"
    [ -n "$INDEX_ENDPOINT_DNS" ] && sed_i "s|^index_endpoint_dns=.*|index_endpoint_dns=$INDEX_ENDPOINT_DNS|g" "$prop_file"
    sed_i "s|^default_model=.*|default_model=$DEFAULT_MODEL|g" "$prop_file"
    sed_i "s|^default_fallback_model=.*|default_fallback_model=$DEFAULT_FALLBACK_MODEL|g" "$prop_file"
    sed_i "s|^default_local_model=.*|default_local_model=$DEFAULT_LOCAL_MODEL|g" "$prop_file"
    [ -n "$INDEX_ENDPOINT_ID" ] && sed_i "s|^routing_index_endpoint_id=.*|routing_index_endpoint_id=$INDEX_ENDPOINT_ID|g" "$prop_file"
    [ -n "$ROUTING_DEPLOYED_INDEX_ID" ] && sed_i "s|^routing_deployed_index_id=.*|routing_deployed_index_id=$ROUTING_DEPLOYED_INDEX_ID|g" "$prop_file"
    [ -n "$ROUTING_INDEX_ID" ] && sed_i "s|^routing_index_id=.*|routing_index_id=$ROUTING_INDEX_ID|g" "$prop_file"
    [ -n "$INDEX_ENDPOINT_ID" ] && sed_i "s|^cache_index_endpoint_id=.*|cache_index_endpoint_id=$INDEX_ENDPOINT_ID|g" "$prop_file"
    [ -n "$CACHE_DEPLOYED_INDEX_ID" ] && sed_i "s|^cache_deployed_index_id=.*|cache_deployed_index_id=$CACHE_DEPLOYED_INDEX_ID|g" "$prop_file"
    [ -n "$CACHE_INDEX_ID" ] && sed_i "s|^cache_index_id=.*|cache_index_id=$CACHE_INDEX_ID|g" "$prop_file"
  fi
}

# ==============================================================================
# Step 4: Deploy Shared Flows and API Proxy using the Service Account
# ==============================================================================
echo ""
echo "--- Step 4: Deploying Shared Flows and API Proxy ---"

deploy_shared_flow() {
  local sf_name=$1
  local sf_dir="sharedflowbundles/${sf_name}/sharedflowbundle"
  if [ ! -d "$sf_dir" ]; then
    echo "ERROR: Shared flow directory $sf_dir not found."
    exit 1
  fi
  echo "Deploying Shared Flow: $sf_name to environment $APIGEE_ENV..."
  local tmp_sf_dir
  tmp_sf_dir=$(mktemp -d)
  cp -r "$sf_dir" "$tmp_sf_dir/"
  local prop_file="$tmp_sf_dir/sharedflowbundle/resources/properties/vertex_config.properties"
  inject_vertex_config_properties "$prop_file"
  apigeecli sharedflows create bundle -n "$sf_name" \
    -f "$tmp_sf_dir/sharedflowbundle" \
    -e "$APIGEE_ENV" --token "$TOKEN" -o "$PROJECT_ID" \
    -s "$SA_EMAIL" \
    --ovr --wait
  rm -rf "$tmp_sf_dir"
}

# Deploy the 2 shared flows:
# - llm-modelarmor-dlp-v1
# - llm-routing-v2
deploy_shared_flow "llm-modelarmor-dlp-v1"
deploy_shared_flow "llm-routing-v2"

# Deploy API Proxy: llm-ai-gateway-v1
PROXY_NAME="llm-ai-gateway-v1"
PROXY_SRC_DIR="proxies/${PROXY_NAME}/apiproxy"
if [ ! -d "$PROXY_SRC_DIR" ]; then
  echo "ERROR: API Proxy directory $PROXY_SRC_DIR not found."
  exit 1
fi

echo "Deploying API Proxy: $PROXY_NAME to environment $APIGEE_ENV..."
TMP_PROXY_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_PROXY_DIR"' EXIT
cp -r "$PROXY_SRC_DIR" "$TMP_PROXY_DIR/"

# Update vertex_config.properties in API Proxy bundle
PROP_FILE="$TMP_PROXY_DIR/apiproxy/resources/properties/vertex_config.properties"
inject_vertex_config_properties "$PROP_FILE"

# Patch Gemma target endpoint with resolved Cloud Run URL and Audience
if [ -f "$TMP_PROXY_DIR/apiproxy/targets/gemma.xml" ]; then
  echo "Patching Gemma target endpoint in $PROXY_NAME with audience and URL: $GEMMA_URL..."
  sed_i "s|<Audience>.*</Audience>|<Audience>${GEMMA_URL}</Audience>|g" "$TMP_PROXY_DIR/apiproxy/targets/gemma.xml"
  sed_i "s|<URL>.*</URL>|<URL>${GEMMA_URL}/v1/chat/completions</URL>|g" "$TMP_PROXY_DIR/apiproxy/targets/gemma.xml"
fi

# Sync DeployedIndexID in Semantic Cache Lookup policy if resolved
if [ -f "$TMP_PROXY_DIR/apiproxy/policies/SCL-Semantic-Cache-Lookup.xml" ] && [ -n "$CACHE_DEPLOYED_INDEX_ID" ]; then
  echo "Syncing DeployedIndexID in SCL-Semantic-Cache-Lookup policy with $CACHE_DEPLOYED_INDEX_ID..."
  sed_i "s|<DeployedIndexID>.*</DeployedIndexID>|<DeployedIndexID>${CACHE_DEPLOYED_INDEX_ID}</DeployedIndexID>|g" "$TMP_PROXY_DIR/apiproxy/policies/SCL-Semantic-Cache-Lookup.xml"
fi

apigeecli apis create bundle -n "$PROXY_NAME" \
  -f "$TMP_PROXY_DIR/apiproxy" \
  -e "$APIGEE_ENV" --token "$TOKEN" -o "$PROJECT_ID" \
  -s "$SA_EMAIL" \
  --ovr --wait

# Upsert intent embeddings to routing index if index is available
if [ -n "$ROUTING_INDEX_ID" ] && [ -f "./upsert_routing_embeddings.py" ]; then
  echo "Upserting intent embeddings to Vertex AI Vector Search routing index ($ROUTING_INDEX_ID)..."
  python3 ./upsert_routing_embeddings.py --project "$PROJECT_ID" --region "$REGION" --index-id "$ROUTING_INDEX_ID" 2>&1 || echo "WARNING: Intent embeddings upsert encountered an error, continuing..."
fi

# ==============================================================================
# Step 5: Create Developer (cymbal-retail-dev@example.com)
# ==============================================================================
echo ""
echo "--- Step 5: Creating Developer ---"
DEV_EMAIL="cymbal-retail-dev@example.com"
DEV_USER="cymbal-retail-dev"

echo "Creating Developer: $DEV_EMAIL..."
apigeecli developers create \
  --user "$DEV_USER" \
  --email "$DEV_EMAIL" \
  --first "Cymbal Retail" \
  --last "Dev" \
  --org "$PROJECT_ID" \
  --token "$TOKEN" >/dev/null 2>&1 || \
  echo "INFO: Developer $DEV_EMAIL may already exist."

# ==============================================================================
# Step 6: Create API Product (llm-ai-gateway-product) with LLM Operations & Quotas
# ==============================================================================
echo ""
echo "--- Step 6: Creating API Product (llm-ai-gateway-product) ---"
PRODUCT_NAME="llm-ai-gateway-product"
PRODUCT_DISPLAY_NAME="LLM AI Gateway Product"

# Construct product JSON configuration supporting proxy and LLM operations
PRODUCT_PAYLOAD=$(jq -n \
  --arg name "$PRODUCT_NAME" \
  --arg displayName "$PRODUCT_DISPLAY_NAME" \
  --arg env "$APIGEE_ENV" \
  '{
    name: $name,
    displayName: $displayName,
    approvalType: "auto",
    environments: [$env],
    scopes: ["customer", "manager"],
    operationGroup: {
      operationConfigType: "proxy",
      operationConfigs: [
        {
          apiSource: "llm-ai-gateway-v1",
          operations: [
            {
              resource: "/**"
            }
          ],
          quota: {}
        }
      ]
    },
    llmOperationGroup: {
      operationConfigs: [
        {
          apiSource: "llm-ai-gateway-v1",
          llmOperations: [
            {
              resource: "/**",
              model: "gemini-2.5-pro"
            }
          ],
          llmTokenQuota: {
            limit: "10000",
            interval: "5",
            timeUnit: "minute"
          }
        },
        {
          apiSource: "llm-ai-gateway-v1",
          llmOperations: [
            {
              resource: "/**",
              model: "gemma3:1b"
            }
          ],
          llmTokenQuota: {
            limit: "50000",
            interval: "5",
            timeUnit: "minute"
          }
        },
        {
          apiSource: "llm-ai-gateway-v1",
          llmOperations: [
            {
              resource: "/**",
              model: "gemini-2.5-flash"
            }
          ],
          llmTokenQuota: {
            limit: "100000",
            interval: "5",
            timeUnit: "minute"
          }
        }
      ]
    },
    attributes: [
      {
        name: "access",
        value: "internal"
      }
    ]
  }')

echo "Checking if API Product $PRODUCT_NAME exists..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer $TOKEN" \
  "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/apiproducts/$PRODUCT_NAME")

RESPONSE_TMP=$(mktemp)
if [ "$HTTP_STATUS" -eq 200 ]; then
  echo "INFO: API Product $PRODUCT_NAME exists. Updating..."
  HTTP_RES=$(curl -s -X PUT \
    "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/apiproducts/$PRODUCT_NAME" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "$PRODUCT_PAYLOAD" \
    -o "$RESPONSE_TMP" \
    -w "%{http_code}")
else
  echo "INFO: API Product $PRODUCT_NAME does not exist. Creating..."
  HTTP_RES=$(curl -s -X POST \
    "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/apiproducts" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "$PRODUCT_PAYLOAD" \
    -o "$RESPONSE_TMP" \
    -w "%{http_code}")
fi

if [ "$HTTP_RES" -lt 200 ] || [ "$HTTP_RES" -ge 300 ]; then
  echo "ERROR: Failed to save API Product $PRODUCT_NAME (HTTP $HTTP_RES)"
  cat "$RESPONSE_TMP"
  rm -f "$RESPONSE_TMP"
  exit 1
fi
rm -f "$RESPONSE_TMP"
echo "INFO: API Product $PRODUCT_NAME configured successfully."

# ==============================================================================
# Step 7: Create Application (llm-ai-gateway-app) linked to Developer and Product
# ==============================================================================
echo ""
echo "--- Step 7: Creating Application (llm-ai-gateway-app) ---"
APP_NAME="llm-ai-gateway-app"

echo "Creating App: $APP_NAME linked to developer $DEV_EMAIL and product $PRODUCT_NAME..."
apigeecli apps create \
  --name "$APP_NAME" \
  --email "$DEV_EMAIL" \
  --prods "$PRODUCT_NAME" \
  --org "$PROJECT_ID" \
  --token "$TOKEN" \
  --disable-check >/dev/null 2>&1 || \
  echo "INFO: Application $APP_NAME may already exist."

# Retrieve and display the API Consumer Key
CONSUMER_KEY=$(apigeecli apps get --name "$APP_NAME" --org "$PROJECT_ID" --token "$TOKEN" --disable-check | jq -r '.[0].credentials[0].consumerKey')

# ==============================================================================
# Step 8: Store Application Client ID in Secret Manager for Downstream Agents
# ==============================================================================
echo ""
echo "--- Step 8: Storing llm-ai-gateway-app Client ID in Secret Manager ---"
SECRET_ID="llm-ai-gateway-client-id"
if [ -n "$CONSUMER_KEY" ] && [ "$CONSUMER_KEY" != "null" ]; then
  echo "Storing $SECRET_ID in Secret Manager..."
  gcloud services enable secretmanager.googleapis.com --project "$PROJECT_ID" 2>/dev/null || true
  gcloud secrets create "$SECRET_ID" --replication-policy="automatic" --project "$PROJECT_ID" 2>/dev/null || true
  echo -n "$CONSUMER_KEY" | gcloud secrets versions add "$SECRET_ID" --project "$PROJECT_ID" --data-file=- || true
  echo "INFO: Secret $SECRET_ID stored successfully in Secret Manager."
else
  echo "WARNING: Could not retrieve CONSUMER_KEY for $APP_NAME. Secret $SECRET_ID not stored."
fi

if [ -n "$CONSUMER_KEY" ] && [ "$CONSUMER_KEY" != "null" ]; then
  echo ""
  echo "===================================================================="
  echo "SUCCESS: LLM AI Gateway Deployment Completed Successfully!"
  echo "===================================================================="
  echo "Application Name: $APP_NAME"
  echo "Developer Email : $DEV_EMAIL"
  echo "API Product     : $PRODUCT_NAME"
  echo "Consumer Key    : $CONSUMER_KEY"
  echo "Secret Name     : $SECRET_ID"
  echo "===================================================================="
else
  echo ""
  echo "SUCCESS: LLM AI Gateway Deployment Completed Successfully!"
  echo "INFO: Use apigeecli or Google Cloud Console to retrieve the consumerKey for $APP_NAME."
fi
