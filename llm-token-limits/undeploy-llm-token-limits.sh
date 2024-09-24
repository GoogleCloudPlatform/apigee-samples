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

if [ -z "$PROJECT" ]; then
  echo "No PROJECT variable set"
  exit
fi

if [ -z "$APIGEE_ENV" ]; then
  echo "No APIGEE_ENV variable set"
  exit
fi

if [ -z "$APIGEE_HOST" ]; then
  echo "No APIGEE_HOST variable set"
  exit
fi

echo "Installing apigeecli"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

TOKEN=$(gcloud auth print-access-token)
gcloud config set project "$PROJECT"

echo "Deleting Developer Apps"
DEVELOPER_ID=$(apigeecli developers get --email aidev@cymbal.com --org "$PROJECT" --token "$TOKEN" --disable-check | jq .'developerId' -r)
apigeecli apps delete --id "$DEVELOPER_ID" --name ai-consumer-app --org "$PROJECT" --token "$TOKEN"

echo "Deleting Developer"
apigeecli developers delete --email aidev@cymbal.com --org "$PROJECT" --token "$TOKEN"

echo "Deleting API Products"
apigeecli products delete --name ai-product-bronze --org "$PROJECT" --token "$TOKEN"
apigeecli products delete --name ai-product-silver --org "$PROJECT" --token "$TOKEN"

echo "Undeploying llm-token-limits-v1 proxy"
REV=$(apigeecli envs deployments get --env "$APIGEE_ENV" --org "$PROJECT" --token "$TOKEN" --disable-check | jq .'deployments[]| select(.apiProxy=="llm-token-limits-v1").revision' -r)
apigeecli apis undeploy --name llm-token-limits-v1 --env "$APIGEE_ENV" --rev "$REV" --org "$PROJECT" --token "$TOKEN"

echo "Deleting proxy llm-token-limits-v1 proxy"
apigeecli apis delete --name llm-token-limits-v1 --org "$PROJECT" --token "$TOKEN"

echo "Deleting Token Consumption Report"

REPORT_NAME=$(curl "https://apigee.googleapis.com/v1/organizations/$PROJECT/reports?expand=true" --header "Authorization: Bearer $TOKEN" --header 'Accept: application/json' --compressed | jq .'qualifier[]| select(.displayName=="Tokens Consumption Report").name' -r)

curl --request DELETE \
  "https://apigee.googleapis.com/v1/organizations/$PROJECT/reports/$REPORT_NAME" \
  --header "Authorization: Bearer $TOKEN" \
  --header 'Accept: application/json' \
  --compressed

echo "Deleting Data Collectors"

apigeecli datacollectors delete -n dc_candidates_token_count --org "$PROJECT" --token "$TOKEN"
apigeecli datacollectors delete -n dc_prompt_token_count --org "$PROJECT" --token "$TOKEN"
apigeecli datacollectors delete -n dc_total_token_count --org "$PROJECT" --token "$TOKEN"