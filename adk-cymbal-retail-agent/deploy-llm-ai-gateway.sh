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
if [ -z "$PROJECT_ID" ]; then
  echo "ERROR: Mandatory environment variable PROJECT_ID is not set."
  echo "Usage: export PROJECT_ID=\"<your-gcp-project-id>\""
  exit 1
fi

if [ -z "$APIGEE_ENV" ]; then
  echo "ERROR: Mandatory environment variable APIGEE_ENV is not set."
  echo "Usage: export APIGEE_ENV=\"<your-apigee-environment>\""
  exit 1
fi

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
  if [ -f "$prop_file" ]; then
    sed_i "s/project=.*/project=$PROJECT_ID/g" "$prop_file"
    sed_i "s/project_number=.*/project_number=$PROJECT_NUMBER/g" "$prop_file"
    sed_i "s/region=.*/region=$REGION/g" "$prop_file"
  fi
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

# Update project ID and region in vertex_config.properties if present
PROP_FILE="$TMP_PROXY_DIR/apiproxy/resources/properties/vertex_config.properties"
if [ -f "$PROP_FILE" ]; then
  sed_i "s/project=.*/project=$PROJECT_ID/g" "$PROP_FILE"
  sed_i "s/project_number=.*/project_number=$PROJECT_NUMBER/g" "$PROP_FILE"
  sed_i "s/region=.*/region=$REGION/g" "$PROP_FILE"
fi

apigeecli apis create bundle -n "$PROXY_NAME" \
  -f "$TMP_PROXY_DIR/apiproxy" \
  -e "$APIGEE_ENV" --token "$TOKEN" -o "$PROJECT_ID" \
  -s "$SA_EMAIL" \
  --ovr --wait

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
if [ -n "$CONSUMER_KEY" ] && [ "$CONSUMER_KEY" != "null" ]; then
  echo ""
  echo "===================================================================="
  echo "SUCCESS: LLM AI Gateway Deployment Completed Successfully!"
  echo "===================================================================="
  echo "Application Name: $APP_NAME"
  echo "Developer Email : $DEV_EMAIL"
  echo "API Product     : $PRODUCT_NAME"
  echo "Consumer Key    : $CONSUMER_KEY"
  echo "===================================================================="
else
  echo ""
  echo "SUCCESS: LLM AI Gateway Deployment Completed Successfully!"
  echo "INFO: Use apigeecli or Google Cloud Console to retrieve the consumerKey for $APP_NAME."
fi
