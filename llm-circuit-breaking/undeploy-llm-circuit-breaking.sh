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

if [ -z "$APIGEE_PROJECT" ]; then
  echo "No APIGEE_PROJECT variable set"
  exit
fi

if [ -z "$PROJECT_P1" ]; then
  echo "No PROJECT_P1 variable set"
  exit
fi

if [ -z "$PROJECT_P2" ]; then
  echo "No PROJECT_P2 variable set"
  exit
fi

if [ -z "$REGION_P1" ]; then
  echo "No REGION_P1 variable set"
  exit
fi

if [ -z "$REGION_P2" ]; then
  echo "No REGION_P2 variable set"
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
gcloud config set project "$APIGEE_PROJECT"

echo "Undeploying llm-circuit-breaking-v1 proxy"
REV=$(apigeecli envs deployments get --env "$APIGEE_ENV" --org "$APIGEE_PROJECT" --token "$TOKEN" --disable-check | jq .'deployments[]| select(.apiProxy=="llm-circuit-breaking-v1").revision' -r)
apigeecli apis undeploy --name llm-circuit-breaking-v1 --env "$APIGEE_ENV" --rev "$REV" --org "$APIGEE_PROJECT" --token "$TOKEN"

echo "Deleting proxy llm-circuit-breaking-v1 proxy"
apigeecli apis delete --name llm-circuit-breaking-v1 --org "$APIGEE_PROJECT" --token "$TOKEN"

echo "Deleting LLM Target Report"

REPORT_NAME=$(curl "https://apigee.googleapis.com/v1/organizations/$APIGEE_PROJECT/reports?expand=true" --header "Authorization: Bearer $TOKEN" --header 'Accept: application/json' --compressed | jq .'qualifier[]| select(.displayName=="LLM Target Report").name' -r)

curl --request DELETE \
  "https://apigee.googleapis.com/v1/organizations/$APIGEE_PROJECT/reports/$REPORT_NAME" \
  --header "Authorization: Bearer $TOKEN" \
  --header 'Accept: application/json' \
  --compressed

echo "Deleting Data Collectors"

apigeecli datacollectors delete -n dc_target_pool --org "$APIGEE_PROJECT" --token "$TOKEN"
apigeecli datacollectors delete -n dc_balanced_target_project --org "$APIGEE_PROJECT" --token "$TOKEN"
apigeecli datacollectors delete -n dc_balanced_target_region --org "$APIGEE_PROJECT" --token "$TOKEN"

echo "Deleting Task Queue"

gcloud tasks queues delete ai-queue --location="$REGION_P1" -q