#!/bin/bash

# Copyright 2024 Google LLC
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

if [ -z "$PROJECT_ID" ]; then
  echo "No PROJECT_ID variable set"
  exit
fi

if [ -z "$APIGEE_ENV" ]; then
  echo "No APIGEE_ENV variable set"
  exit
fi

if [ -z "$SERVICE_ACCOUNT_NAME" ]; then
  echo "No SERVICE_ACCOUNT_NAME variable set"
  exit
fi

delete_api() {
  local api_name=$1
  echo "Undeploying $api_name"
  REV=$(apigeecli envs deployments get --env "$APIGEE_ENV" --org "$PROJECT_ID" --token "$TOKEN" --disable-check | jq .'deployments[]| select(.apiProxy=="'"$api_name"'").revision' -r)
  apigeecli apis undeploy --name "$api_name" --env "$APIGEE_ENV" --rev "$REV" --org "$PROJECT_ID" --token "$TOKEN"

  echo "Deleting proxy $api_name"
  apigeecli apis delete --name "$api_name" --org "$PROJECT_ID" --token "$TOKEN"

}

remove_role_from_service_account() {
  local role=$1
  gcloud projects remove-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="$role"
}

TOKEN=$(gcloud auth print-access-token)

echo "Installing apigeecli"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

echo "Deleting Developer App"
DEVELOPER_ID=$(apigeecli developers get --email llm-routing-developer@acme.com --org "$PROJECT_ID" --token "$TOKEN" --disable-check | jq .'developerId' -r)
apigeecli apps delete --id "$DEVELOPER_ID" --name llm-routing-app --org "$PROJECT_ID" --token "$TOKEN"

echo "Deleting Developer"
apigeecli developers delete --email llm-routing-developer@acme.com --org "$PROJECT_ID" --token "$TOKEN"

echo "Deleting API Products"
apigeecli products delete --name llm-routing-product --org "$PROJECT_ID" --token "$TOKEN"

delete_api "llm-routing-v1"

echo "Deleting KVMs"
apigeecli kvms delete --name llm-routing-v1-modelprovider-config --env "$APIGEE_ENV" --org "$PROJECT_ID" --token "$TOKEN"

echo "Removing assigned roles from Service Account"
remove_role_from_service_account "roles/apigee.analyticsEditor"
remove_role_from_service_account "roles/logging.logWriter"
remove_role_from_service_account "roles/aiplatform.user"
remove_role_from_service_account "roles/iam.serviceAccountUser"

echo "Deleting Service Account"
gcloud iam service-accounts delete "${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" --project "$PROJECT_ID" --quiet
