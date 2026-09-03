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
# Script: cleanup-llm-ai-gateway.sh
# Purpose: Cleans up all resources created by deploy-llm-ai-gateway.sh, including
#          application, product, developer, API proxy, shared flows,
#          data collectors, and the service account.
# ==============================================================================

set -e

echo "===================================================================="
echo "Starting Apigee X LLM AI Gateway Cleanup (cleanup-llm-ai-gateway.sh)"
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

# Ensure apigeecli CLI tool is installed or available in PATH
if ! command -v apigeecli &> /dev/null; then
  if [ -x "$HOME/.apigeecli/bin/apigeecli" ]; then
    export PATH="$PATH:$HOME/.apigeecli/bin"
  else
    echo "ERROR: apigeecli not found in PATH."
    exit 1
  fi
fi

# Obtain access token if not already set
if [ -z "$TOKEN" ]; then
  echo "INFO: Obtaining Google Cloud authentication access token..."
  TOKEN=$(gcloud auth application-default print-access-token)
fi
export TOKEN

echo "INFO: Project ID: $PROJECT_ID, Apigee Env: $APIGEE_ENV"

# ==============================================================================
# Step 1: Delete Application
# ==============================================================================
echo ""
echo "--- Step 1: Deleting Application ---"
APP_NAME="llm-ai-gateway-app"
DEV_EMAIL="cymbal-retail-dev@example.com"
echo "Deleting App: $APP_NAME..."
apigeecli apps delete --name "$APP_NAME" --email "$DEV_EMAIL" --org "$PROJECT_ID" --token "$TOKEN" >/dev/null 2>&1 || \
  echo "INFO: App $APP_NAME deleted or does not exist."

# ==============================================================================
# Step 2: Delete API Product
# ==============================================================================
echo ""
echo "--- Step 2: Deleting API Product ---"
PRODUCT_NAME="llm-ai-gateway-product"
echo "Deleting API Product: $PRODUCT_NAME..."
apigeecli apiproducts delete -n "$PRODUCT_NAME" --org "$PROJECT_ID" --token "$TOKEN" >/dev/null 2>&1 || \
  echo "INFO: API Product $PRODUCT_NAME deleted or does not exist."

# ==============================================================================
# Step 3: Delete Developer
# ==============================================================================
echo ""
echo "--- Step 3: Deleting Developer ---"
echo "Deleting Developer: $DEV_EMAIL..."
apigeecli developers delete --email "$DEV_EMAIL" --org "$PROJECT_ID" --token "$TOKEN" >/dev/null 2>&1 || \
  echo "INFO: Developer $DEV_EMAIL deleted or does not exist."

# ==============================================================================
# Step 4: Undeploy & Delete API Proxy
# ==============================================================================
echo ""
echo "--- Step 4: Undeploying and Deleting API Proxy ---"
PROXY_NAME="llm-ai-gateway-v1"
echo "Undeploying API Proxy: $PROXY_NAME from $APIGEE_ENV..."
apigeecli apis undeploy -n "$PROXY_NAME" -e "$APIGEE_ENV" --org "$PROJECT_ID" --token "$TOKEN" >/dev/null 2>&1 || \
  echo "INFO: API Proxy $PROXY_NAME not deployed or undeploy failed."

echo "Deleting API Proxy: $PROXY_NAME..."
apigeecli apis delete -n "$PROXY_NAME" --org "$PROJECT_ID" --token "$TOKEN" >/dev/null 2>&1 || \
  echo "INFO: API Proxy $PROXY_NAME deleted or does not exist."

# ==============================================================================
# Step 5: Undeploy & Delete Shared Flows
# ==============================================================================
echo ""
echo "--- Step 5: Undeploying and Deleting Shared Flows ---"
for sf_name in "llm-modelarmor-dlp-v1" "llm-routing-v2"; do
  echo "Undeploying Shared Flow: $sf_name from $APIGEE_ENV..."
  apigeecli sharedflows undeploy -n "$sf_name" -e "$APIGEE_ENV" --org "$PROJECT_ID" --token "$TOKEN" >/dev/null 2>&1 || \
    echo "INFO: Shared Flow $sf_name not deployed."

  echo "Deleting Shared Flow: $sf_name..."
  apigeecli sharedflows delete -n "$sf_name" --org "$PROJECT_ID" --token "$TOKEN" >/dev/null 2>&1 || \
    echo "INFO: Shared Flow $sf_name deleted or does not exist."
done

# ==============================================================================
# Step 6: Delete Data Collectors
# ==============================================================================
echo ""
echo "--- Step 6: Deleting Apigee X Data Collectors ---"
DATA_COLLECTORS=(
  "dc_candidates_token_count_v2"
  "dc_cost_center_v2"
  "dc_model_v2"
  "dc_prompt_token_count_v2"
  "dc_response_type_v2"
  "dc_time_to_first_token_v2"
  "dc_total_token_count_v2"
)

for dc in "${DATA_COLLECTORS[@]}"; do
  echo "Deleting Data Collector: $dc..."
  apigeecli datacollectors delete -n "$dc" --org "$PROJECT_ID" --token "$TOKEN" >/dev/null 2>&1 || \
    echo "INFO: Data Collector $dc deleted or does not exist."
done

# ==============================================================================
# Step 6.1: Delete Custom Analytics Report
# ==============================================================================
echo ""
echo "--- Step 6.1: Deleting Custom Analytics Report (llm-ai-gateway-report) ---"
REPORT_NAME="llm-ai-gateway-report"
echo "Deleting Custom Report: $REPORT_NAME..."
curl -s -X DELETE \
  -H "Authorization: Bearer $TOKEN" \
  "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/reports/$REPORT_NAME" >/dev/null 2>&1 || \
  echo "INFO: Custom Report $REPORT_NAME deleted or does not exist."

# ==============================================================================
# Step 6.5: Delete KeyValueMap
# ==============================================================================
echo ""
echo "--- Step 6.5: Deleting KeyValueMap (model-armor-config-v2) ---"
apigeecli kvms delete --name "model-armor-config-v2" --env "$APIGEE_ENV" --org "$PROJECT_ID" --token "$TOKEN" >/dev/null 2>&1 || \
  echo "INFO: KVM model-armor-config-v2 deleted or does not exist."

# ==============================================================================
# Step 7: Delete Service Account & Remove IAM Bindings
# ==============================================================================
echo ""
echo "--- Step 7: Deleting Service Account and IAM Bindings ---"
SERVICE_ACCOUNT_NAME="apigee-vertex-ai-caller"
SA_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "Removing IAM bindings on Project $PROJECT_ID for $SA_EMAIL..."
IAM_ROLES=(
  "roles/run.invoker"
  "roles/aiplatform.user"
  "roles/dlp.user"
  "roles/dlp.reader"
  "roles/modelarmor.user"
  "roles/modelarmor.viewer"
)

for role in "${IAM_ROLES[@]}"; do
  gcloud projects remove-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$SA_EMAIL" \
    --role="$role" \
    --condition=None \
    >/dev/null 2>&1 || true
done

echo "Deleting Service Account: $SERVICE_ACCOUNT_NAME..."
gcloud iam service-accounts delete "$SA_EMAIL" --project "$PROJECT_ID" --quiet >/dev/null 2>&1 || \
  echo "INFO: Service Account $SERVICE_ACCOUNT_NAME deleted or does not exist."

echo ""
echo "===================================================================="
echo "SUCCESS: LLM AI Gateway Cleanup Completed!"
echo "===================================================================="
