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
 set +e

if [ -z "$PROJECT_ID" ]; then
  echo "No PROJECT_ID variable set"
  exit 1
fi

if [ -z "$APIGEE_ENV" ]; then
  echo "No APIGEE_ENV variable set"
  exit 1
fi

if [ -z "$SERVICE_ACCOUNT_NAME" ]; then
  echo "No SERVICE_ACCOUNT_NAME variable set"
  exit 1
fi

if [ -z "$APIGEE_APIHUB_PROJECT_ID" ]; then
  echo "No APIGEE_APIHUB_PROJECT_ID variable set"
  exit 1
fi

if [ -z "$APIGEE_APIHUB_REGION" ]; then
  echo "No APIGEE_APIHUB_REGION variable set"
  exit 1
fi

if [ -z "$MODEL_ARMOR_REGION" ]; then
  echo "No MODEL_ARMOR_REGION variable set"
  exit 1
fi

if [ -z "$MODEL_ARMOR_TEMPLATE_ID" ]; then
  echo "No MODEL_ARMOR_TEMPLATE_ID variable set"
  exit 1
fi


TOKEN=$(gcloud auth application-default print-access-token)
export DEPLOY_DISCOVERY_PROXY="${DEPLOY_DISCOVERY_PROXY:-true}"

delete_api() {
  local api_name=$1
  echo "Undeploying $api_name"
  REV=$(apigeecli envs deployments get --env "$APIGEE_ENV" --org "$PROJECT_ID" --token "$TOKEN" --disable-check | jq .'deployments[]| select(.apiProxy=="'"$api_name"'").revision' -r 2>/dev/null || true)
  if [ -n "$REV" ] && [ "$REV" != "null" ]; then
    apigeecli apis undeploy --name "$api_name" --env "$APIGEE_ENV" --rev "$REV" --org "$PROJECT_ID" --token "$TOKEN" || true
  fi

  echo "Deleting proxy $api_name"
  apigeecli apis delete --name "$api_name" --org "$PROJECT_ID" --token "$TOKEN" || true
}

delete_sharedflow(){
  local sharedflow_name=$1
  echo "Undeploying $sharedflow_name sharedflow"
  REV=$(apigeecli envs deployments get --env "$APIGEE_ENV" --org "$PROJECT_ID" --token "$TOKEN" --sharedflows true --disable-check | jq .'deployments[]| select(.apiProxy=="'"$sharedflow_name"'").revision' -r 2>/dev/null || true)
  if [ -n "$REV" ] && [ "$REV" != "null" ]; then
    apigeecli sharedflows undeploy --name "$sharedflow_name" --env "$APIGEE_ENV" --rev "$REV" --org "$PROJECT_ID" --token "$TOKEN" || true
  fi

  echo "Deleting sharedflow $sharedflow_name sharedflow"
  apigeecli sharedflows delete --name "$sharedflow_name" --org "$PROJECT_ID" --token "$TOKEN" || true
}

delete_api_from_hub() {
  local api=$1
  apigeecli apihub apis delete --id "${api}_api" \
  --force true \
  -r "$APIGEE_APIHUB_REGION" -o "$APIGEE_APIHUB_PROJECT_ID" -t "$TOKEN" || true
}

remove_role_from_service_account() {
  local role=$1
  gcloud projects remove-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="$role" || true
}

echo "Installing apigeecli"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

echo "Deleting Developer App"
DEVELOPER_ID=$(apigeecli developers get --email cymbal-retail-developer@acme.com --org "$PROJECT_ID" --token "$TOKEN" --disable-check | jq .'developerId' -r 2>/dev/null || true)
if [ -n "$DEVELOPER_ID" ] && [ "$DEVELOPER_ID" != "null" ]; then
  apigeecli apps delete --id "$DEVELOPER_ID" --name cymbal-retail-app --org "$PROJECT_ID" --token "$TOKEN" || true
fi

echo "Deleting Developer"
apigeecli developers delete --email cymbal-retail-developer@acme.com --org "$PROJECT_ID" --token "$TOKEN" || true

echo "Deleting API Products"
apigeecli products delete --name cymbal-retail-product-rest --org "$PROJECT_ID" --token "$TOKEN" || true
apigeecli products delete --name cymbal-retail-product-mcp --org "$PROJECT_ID" --token "$TOKEN" || true

delete_api "cymbal-customers-v2"
delete_api "cymbal-orders-v2"
delete_api "cymbal-returns-v2"
delete_api "cymbal-shipping-v2"
delete_api "adk-retail-agent-llm-governance-v1"
delete_api "oauth-server"
if [ "$DEPLOY_DISCOVERY_PROXY" = "true" ]; then
  delete_api "cymbal-discovery-v1"
fi

echo "Undeploying GEAP Agent from Agent Runtime"
pushd python/agents/cymbal-retail-agent-geap >/dev/null
source .venv/bin/activate
python3 deployment/undeploy.py \
  --project "$PROJECT_ID" \
  --location "${MODEL_ARMOR_REGION:-us-central1}"
deactivate
popd >/dev/null

echo "Detaching PostProxyFlowHook"
apigeecli flowhooks detach --name "PostProxyFlowHook" --env "$APIGEE_ENV" --org "$PROJECT_ID" --token "$TOKEN" || true

delete_sharedflow "llm-extract-candidates-v1"
delete_sharedflow "llm-extract-prompts-v1"
delete_sharedflow "llm-logger-v1"
delete_sharedflow "cloud-logger-v1"

delete_api_from_hub "accounts"
delete_api_from_hub "communications"
delete_api_from_hub "customers"
delete_api_from_hub "employees"
delete_api_from_hub "orders"
delete_api_from_hub "payments"
delete_api_from_hub "products"
delete_api_from_hub "returns"
delete_api_from_hub "shipments"
delete_api_from_hub "stocks"
delete_api_from_hub "shipping"

echo "Deleting Token Consumption Report"

REPORT_NAME=$(curl "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/reports?expand=true" --header "Authorization: Bearer $TOKEN" --header 'Accept: application/json' --compressed | jq .'qualifier[]| select(.displayName=="Tokens Consumption Report").name' -r 2>/dev/null || true)
if [ -n "$REPORT_NAME" ] && [ "$REPORT_NAME" != "null" ]; then
  curl --request DELETE \
    "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/reports/$REPORT_NAME" \
    --header "Authorization: Bearer $TOKEN" \
    --header 'Accept: application/json' \
    --compressed || true
fi

echo "Deleting Responsible AI Report"

REPORT_NAME=$(curl "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/reports?expand=true" --header "Authorization: Bearer $TOKEN" --header 'Accept: application/json' --compressed | jq .'qualifier[]| select(.displayName=="Responsible AI Report").name' -r 2>/dev/null || true)
if [ -n "$REPORT_NAME" ] && [ "$REPORT_NAME" != "null" ]; then
  curl --request DELETE \
    "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/reports/$REPORT_NAME" \
    --header "Authorization: Bearer $TOKEN" \
    --header 'Accept: application/json' \
    --compressed || true
fi

echo "Deleting Data Collectors"
apigeecli datacollectors delete -n dc_ma_pi_jailbreak --org "$PROJECT_ID" --token "$TOKEN" || true
apigeecli datacollectors delete -n dc_ma_malicious_uri --org "$PROJECT_ID" --token "$TOKEN" || true
apigeecli datacollectors delete -n dc_ma_rai --org "$PROJECT_ID" --token "$TOKEN" || true
apigeecli datacollectors delete -n dc_ma_csam --org "$PROJECT_ID" --token "$TOKEN" || true

apigeecli datacollectors delete -n dc_candidates_token_count --org "$PROJECT_ID" --token "$TOKEN" || true
apigeecli datacollectors delete -n dc_prompt_token_count --org "$PROJECT_ID" --token "$TOKEN" || true
apigeecli datacollectors delete -n dc_total_token_count --org "$PROJECT_ID" --token "$TOKEN" || true

echo "Deleting DLP template"
curl --location --request DELETE "https://dlp.googleapis.com/v2/projects/$PROJECT_ID/deidentifyTemplates/Basic_PII" \
--header "X-Goog-User-Project: $PROJECT_NUMBER" \
--header "Content-Type: application/json" \
--header "Authorization: Bearer $TOKEN" || true

echo "Deleting Model Armor template"
gcloud config set api_endpoint_overrides/modelarmor "https://modelarmor.$MODEL_ARMOR_REGION.rep.mtls.googleapis.com/" || true
gcloud model-armor templates delete "$MODEL_ARMOR_TEMPLATE_ID" -q --location "$MODEL_ARMOR_REGION" --project="$PROJECT_ID" || true

echo "Deleting the secrets"
SECRET_ID_1="cymbal-retail-client-id"
gcloud secrets delete "$SECRET_ID_1" --project "$PROJECT_ID" --quiet || true
SECRET_ID_2="cymbal-retail-client-secret"
gcloud secrets delete "$SECRET_ID_2" --project "$PROJECT_ID" --quiet || true

echo "Removing assigned roles from Service Account"
remove_role_from_service_account "roles/logging.logWriter"
remove_role_from_service_account "roles/aiplatform.user"
remove_role_from_service_account "roles/modelarmor.admin"
remove_role_from_service_account "roles/iam.serviceAccountUser"
remove_role_from_service_account "roles/dlp.reader"
remove_role_from_service_account "roles/dlp.user"
remove_role_from_service_account "roles/apigee.analyticsEditor"
remove_role_from_service_account "roles/secretmanager.secretAccessor"
remove_role_from_service_account "roles/apigee.apiReaderV2"
