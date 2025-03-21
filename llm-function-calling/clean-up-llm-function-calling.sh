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

if [ -z "$PROJECT_ID" ]; then
  echo "No PROJECT_ID variable set"
  exit
fi

if [ -z "$APIGEE_ENV" ]; then
  echo "No APIGEE_ENV variable set"
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

TOKEN=$(gcloud auth print-access-token)

echo "Installing apigeecli"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

echo "Deleting Developer App"
DEVELOPER_ID=$(apigeecli developers get --email llm-function-calling-developer@acme.com --org "$PROJECT_ID" --token "$TOKEN" --disable-check | jq .'developerId' -r)
apigeecli apps delete --id "$DEVELOPER_ID" --name llm-function-calling-app --org "$PROJECT_ID" --token "$TOKEN"

echo "Deleting Developer"
apigeecli developers delete --email llm-function-calling-developer@acme.com --org "$PROJECT_ID" --token "$TOKEN"

echo "Deleting API Products"
apigeecli products delete --name llm-function-calling-product --org "$PROJECT_ID" --token "$TOKEN"

delete_api "llm-function-calling-v1"