#!/bin/bash

# Copyright 2025 Google LLC
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
 set -e

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


TOKEN=$(gcloud auth print-access-token)

delete_api() {
  local api_name=$1
  echo "Undeploying $api_name"
  REV=$(apigeecli envs deployments get --env "$APIGEE_ENV" --org "$PROJECT_ID" --token "$TOKEN" --disable-check | jq .'deployments[]| select(.apiProxy=="'"$api_name"'").revision' -r)
  apigeecli apis undeploy --name "$api_name" --env "$APIGEE_ENV" --rev "$REV" --org "$PROJECT_ID" --token "$TOKEN"

  echo "Deleting proxy $api_name"
  apigeecli apis delete --name "$api_name" --org "$PROJECT_ID" --token "$TOKEN"

}

delete_sharedflow(){
  local sharedflow_name=$1
  echo "Undeploying $sharedflow_name sharedflow"
  REV=$(apigeecli envs deployments get --env "$APIGEE_ENV" --org "$PROJECT_ID" --token "$TOKEN" --sharedflows true --disable-check | jq .'deployments[]| select(.apiProxy=="'"$sharedflow_name"'").revision' -r)
  apigeecli sharedflows undeploy --name "$sharedflow_name" --env "$APIGEE_ENV" --rev "$REV" --org "$PROJECT_ID" --token "$TOKEN"

  echo "Deleting sharedflow $sharedflow_name sharedflow"
  apigeecli sharedflows delete --name "$sharedflow_name" --org "$PROJECT_ID" --token "$TOKEN"
}

delete_api_from_hub() {
  local api=$1
  apigeecli apihub apis delete --id "${api}_api" \
  --force true \
  -r "$APIGEE_APIHUB_REGION" -o "$APIGEE_APIHUB_PROJECT_ID" -t "$TOKEN"
}

remove_role_from_service_account() {
  local role=$1
  gcloud projects remove-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="$role"
}

echo "Installing apigeecli"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

echo "Deleting Developer App"
DEVELOPER_ID=$(apigeecli developers get --email cymbal-retail-developer@acme.com --org "$PROJECT_ID" --token "$TOKEN" --disable-check | jq .'developerId' -r)
apigeecli apps delete --id "$DEVELOPER_ID" --name cymbal-retail-app --org "$PROJECT_ID" --token "$TOKEN"

echo "Deleting Developer"
apigeecli developers delete --email cymbal-retail-developer@acme.com --org "$PROJECT_ID" --token "$TOKEN"

echo "Deleting API Products"
apigeecli products delete --name cymbal-retail-product --org "$PROJECT_ID" --token "$TOKEN"

delete_api "cymbal-customers-v1"
delete_api "cymbal-orders-v1"
delete_api "cymbal-returns-v1"
delete_api "mcp-cymbal-customers-v1"
delete_api "adk-retail-agent-llm-governance-v1"

delete_sharedflow "llm-extract-candidates-v1"
delete_sharedflow "llm-extract-prompts-v1"
delete_sharedflow "llm-logger-v1"

delete_api_from_hub "customers"
delete_api_from_hub "orders"
delete_api_from_hub "returns"
delete_api_from_hub "accounts"
delete_api_from_hub "communications"
delete_api_from_hub "employees"
delete_api_from_hub "products"
delete_api_from_hub "stocks"
delete_api_from_hub "payments"
delete_api_from_hub "shipments"

echo "Deleting Token Consumption Report"

REPORT_NAME=$(curl "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/reports?expand=true" --header "Authorization: Bearer $TOKEN" --header 'Accept: application/json' --compressed | jq .'qualifier[]| select(.displayName=="Tokens Consumption Report").name' -r)

curl --request DELETE \
  "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/reports/$REPORT_NAME" \
  --header "Authorization: Bearer $TOKEN" \
  --header 'Accept: application/json' \
  --compressed

echo "Deleting Responsible AI Report"

REPORT_NAME=$(curl "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/reports?expand=true" --header "Authorization: Bearer $TOKEN" --header 'Accept: application/json' --compressed | jq .'qualifier[]| select(.displayName=="Responsible AI Report").name' -r)

curl --request DELETE \
  "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/reports/$REPORT_NAME" \
  --header "Authorization: Bearer $TOKEN" \
  --header 'Accept: application/json' \
  --compressed

echo "Deleting Data Collectors"
apigeecli datacollectors delete -n dc_ma_pi_jailbreak --org "$PROJECT_ID" --token "$TOKEN"
apigeecli datacollectors delete -n dc_ma_malicious_uri --org "$PROJECT_ID" --token "$TOKEN"
apigeecli datacollectors delete -n dc_ma_rai --org "$PROJECT_ID" --token "$TOKEN"
apigeecli datacollectors delete -n dc_ma_csam --org "$PROJECT_ID" --token "$TOKEN"

apigeecli datacollectors delete -n dc_candidates_token_count --org "$PROJECT_ID" --token "$TOKEN"
apigeecli datacollectors delete -n dc_prompt_token_count --org "$PROJECT_ID" --token "$TOKEN"
apigeecli datacollectors delete -n dc_total_token_count --org "$PROJECT_ID" --token "$TOKEN"

echo "Deleting DLP template"
curl --location --request DELETE "https://dlp.googleapis.com/v2/projects/$PROJECT_ID/deidentifyTemplates/Basic_PII" \
--header "X-Goog-User-Project: $PROJECT_NUMBER" \
--header "Content-Type: application/json" \
--header "Authorization: Bearer $TOKEN"

echo "Deleting Model Armor template"
gcloud config set api_endpoint_overrides/modelarmor "https://modelarmor.$MODEL_ARMOR_REGION.rep.googleapis.com/"
gcloud model-armor templates delete "$MODEL_ARMOR_TEMPLATE_ID" -q --location "$MODEL_ARMOR_REGION" --project="$PROJECT_ID"

echo "Deleting the Secret"
SECRET_ID="cymbal-retail-apikey"
gcloud secrets delete "$SECRET_ID" --project "$PROJECT_ID" --quiet

echo "Removing assigned roles from Service Account"
remove_role_from_service_account "roles/logging.logWriter"
remove_role_from_service_account "roles/aiplatform.user"
remove_role_from_service_account "roles/modelarmor.admin"
remove_role_from_service_account "roles/iam.serviceAccountUser"
remove_role_from_service_account "roles/dlp.reader"
remove_role_from_service_account "roles/dlp.user"
remove_role_from_service_account "roles/apigee.analyticsEditor"