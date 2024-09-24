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

INDEX_ID=$(gcloud ai indexes list --project="$PROJECT" --region="$REGION" --format="json" | jq -c -r '.[] | select(.displayName="semantic-cache") | .name | split("/") | .[5]')
INDEX_ENDPOINT_ID=$(gcloud ai index-endpoints list --project="$PROJECT" --region="$REGION" --format="json" | jq -c -r '.[] | select(.displayName="semantic-cache") | .name | split("/") | .[5]')

echo "Undeploying llm-semantic-cache-v1 proxy"
REV=$(apigeecli envs deployments get --env "$APIGEE_ENV" --org "$PROJECT" --token "$TOKEN" --disable-check | jq .'deployments[]| select(.apiProxy=="llm-semantic-cache-v1").revision' -r)
apigeecli apis undeploy --name llm-semantic-cache-v1 --env "$APIGEE_ENV" --rev "$REV" --org "$PROJECT" --token "$TOKEN"

echo "Deleting proxy llm-semantic-cache-v1 proxy"
apigeecli apis delete --name llm-semantic-cache-v1 --org "$PROJECT" --token "$TOKEN"

echo "Undeploying semantic-cache-request-v1 sharedflow"
REV=$(apigeecli envs deployments get --env "$APIGEE_ENV" --org "$PROJECT" --token "$TOKEN" --sharedflows true --disable-check | jq .'deployments[]| select(.apiProxy=="semantic-cache-request-v1").revision' -r)
apigeecli sharedflows undeploy --name semantic-cache-request-v1 --env "$APIGEE_ENV" --rev "$REV" --org "$PROJECT" --token "$TOKEN"

echo "Deleting proxy semantic-cache-request-v1 sharedflow"
apigeecli sharedflows delete --name semantic-cache-request-v1 --org "$PROJECT" --token "$TOKEN"

echo "Undeploying semantic-cache-response-v1 sharedflow"
REV=$(apigeecli envs deployments get --env "$APIGEE_ENV" --org "$PROJECT" --token "$TOKEN" --sharedflows true --disable-check | jq .'deployments[]| select(.apiProxy=="semantic-cache-response-v1").revision' -r)
apigeecli sharedflows undeploy --name semantic-cache-response-v1 --env "$APIGEE_ENV" --rev "$REV" --org "$PROJECT" --token "$TOKEN"

echo "Deleting proxy semantic-cache-response-v1 sharedflow"
apigeecli sharedflows delete --name semantic-cache-response-v1 --org "$PROJECT" --token "$TOKEN"

curl -L https://raw.githubusercontent.com/GoogleCloudPlatform/application-integration-management-toolkit/main/downloadLatest.sh | sh -
export PATH=$PATH:$HOME/.integrationcli/bin

echo "Deleting Semantic Cache Cleanup utility ..."
integrationcli integrations delete -n cleanup-semantic-cache-v1

echo "Undeploy Index Endpoint ..."
gcloud ai index-endpoints undeploy-index "$INDEX_ENDPOINT_ID" --deployed-index-id=semantic_cache --region="$REGION" --project="$PROJECT"

echo "Delete Index Endpoint ..."
gcloud ai index-endpoints delete "$INDEX_ENDPOINT_ID" --region="$REGION" --project="$PROJECT"

echo "Delete Index ..."
gcloud ai indexes delete "$INDEX_ID" --region="$REGION" --project="$PROJECT"