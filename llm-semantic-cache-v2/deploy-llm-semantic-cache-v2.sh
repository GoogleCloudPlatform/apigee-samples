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

if [ -z "$TOKEN" ]; then
  TOKEN=$(gcloud auth print-access-token)
fi

# Determine sed in-place arguments for portability (macOS vs Linux)
sedi_args=("-i")
if [[ "$(uname)" == "Darwin" ]]; then
  sedi_args=("-i" "") # For macOS, sed -i requires an extension argument. "" means no backup.
fi

echo "Installing apigeecli"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

gcloud config set project "$PROJECT"

PROJECT_NUMBER="$(gcloud projects describe "$PROJECT" --format="value(projectNumber)")"
INDEX_ID=$(gcloud ai indexes list --project="$PROJECT" --region="$REGION" --format="json" | jq -c -r '.[] | select(.displayName="semantic-cache-index") | .name | split("/") | .[5]')
INDEX_ENDPOINT_ID=$(gcloud ai index-endpoints list --project="$PROJECT" --region="$REGION" --format="json" | jq -c -r '.[] | select(.displayName="semantic-cache-index-endpoint") | .name | split("/") | .[5]')
PUBLIC_ENDPOINT_SUBDOMAIN=$(gcloud ai index-endpoints list --project="$PROJECT" --region="$REGION" --format="json" | jq -c -r '.[] | select(.displayName="semantic-cache-index-endpoint") | .publicEndpointDomainName | split(".") | .[0]')
INDEX_ID_NAME=semantic_cache_index_endpoint_deployment

mkdir ./tmp
cp -r apiproxy ./tmp/.

sed "${sedi_args[@]}" "s/REGION/$REGION/g" ./tmp/apiproxy/targets/default.xml

sed "${sedi_args[@]}" "s/PROJECT_ID/$PROJECT/g" ./tmp/apiproxy/policies/SCL-Semantic-Cache-Lookup.xml
sed "${sedi_args[@]}" "s/PROJECT_NUMBER/$PROJECT_NUMBER/g" ./tmp/apiproxy/policies/SCL-Semantic-Cache-Lookup.xml
sed "${sedi_args[@]}" "s/REGION/$REGION/g" ./tmp/apiproxy/policies/SCL-Semantic-Cache-Lookup.xml
sed "${sedi_args[@]}" "s/EMBEDDINGS_MODEL_ID/$EMBEDDINGS_MODEL_ID/g" ./tmp/apiproxy/policies/SCL-Semantic-Cache-Lookup.xml
sed "${sedi_args[@]}" "s/PUBLIC_ENDPOINT_SUBDOMAIN/$PUBLIC_ENDPOINT_SUBDOMAIN/g" ./tmp/apiproxy/policies/SCL-Semantic-Cache-Lookup.xml
sed "${sedi_args[@]}" "s/INDEX_ENDPOINT_ID/$INDEX_ENDPOINT_ID/g" ./tmp/apiproxy/policies/SCL-Semantic-Cache-Lookup.xml
sed "${sedi_args[@]}" "s/INDEX_ID_NAME/$INDEX_ID_NAME/g" ./tmp/apiproxy/policies/SCL-Semantic-Cache-Lookup.xml
sed "${sedi_args[@]}" "s/NEAREST_NEIGHBOR_DISTANCE/$NEAREST_NEIGHBOR_DISTANCE/g" ./tmp/apiproxy/policies/SCL-Semantic-Cache-Lookup.xml

sed "${sedi_args[@]}" "s/REGION/$REGION/g" ./tmp/apiproxy/policies/SCP-Semantic-Cache-Populate.xml
sed "${sedi_args[@]}" "s/PROJECT_NUMBER/$PROJECT_NUMBER/g" ./tmp/apiproxy/policies/SCP-Semantic-Cache-Populate.xml
sed "${sedi_args[@]}" "s/INDEX_ID/$INDEX_ID/g" ./tmp/apiproxy/policies/SCP-Semantic-Cache-Populate.xml
sed "${sedi_args[@]}" "s/CACHE_ENTRY_TTL_SEC/$CACHE_ENTRY_TTL_SEC/g" ./tmp/apiproxy/policies/SCP-Semantic-Cache-Populate.xml

echo "Deploying Apigee artifacts..."

echo "Importing and Deploying Apigee llm-semantic-cache-v2 proxy..."
REV=$(apigeecli apis create bundle -f ./tmp/apiproxy -n llm-semantic-cache-v2 --org "$PROJECT" --token "$TOKEN" --disable-check | jq ."revision" -r)
apigeecli apis deploy --wait --name llm-semantic-cache-v2 --ovr --rev "$REV" --org "$PROJECT" --env "$APIGEE_ENV" --token "$TOKEN" --sa "ai-client@$PROJECT.iam.gserviceaccount.com"

FIND_NEIGHBORS_URL="https:\/\/$PUBLIC_ENDPOINT_SUBDOMAIN.$REGION-$PROJECT_NUMBER.vdb.vertexai.goog\/v1\/projects\/$PROJECT_NUMBER\/locations\/$REGION\/indexEndpoints\/$INDEX_ENDPOINT_ID:findNeighbors"
REMOVE_DATAPOINTS_URL="https:\/\/$REGION-aiplatform.googleapis.com\/v1\/projects\/$PROJECT_NUMBER\/locations\/$REGION\/indexes\/$INDEX_ID:removeDatapoints"
SERVICE_ACCOUNT_ID="ai-client@$PROJECT.iam.gserviceaccount.com"

sed "${sedi_args[@]}" "s/FIND_NEIGHBORS_URL/$FIND_NEIGHBORS_URL/g" ./cleanup-semantic-cache-v1/dev/overrides/overrides.json
sed "${sedi_args[@]}" "s/REMOVE_DATAPOINTS_URL/$REMOVE_DATAPOINTS_URL/g" ./cleanup-semantic-cache-v1/dev/overrides/overrides.json
sed "${sedi_args[@]}" "s/SERVICE_ACCOUNT_ID/$SERVICE_ACCOUNT_ID/g" ./cleanup-semantic-cache-v1/dev/authconfigs/ai-client.json

echo "Provisioning Application Integration ..."
curl --request POST \
  "https://integrations.googleapis.com/v1/projects/$PROJECT/locations/$REGION/clients:provision" \
  --header "Authorization: Bearer $TOKEN" \
  --header 'Accept: application/json' \
  --header 'Content-Type: application/json' \
  --data '{"provisionGmek":false,"createSampleWorkflows":false}' \
  --compressed

echo "Installing integrationcli ..."
curl -L https://raw.githubusercontent.com/GoogleCloudPlatform/application-integration-management-toolkit/main/downloadLatest.sh | sh -
export PATH=$PATH:$HOME/.integrationcli/bin

integrationcli prefs set --reg="$REGION" --proj="$PROJECT" -t "$TOKEN"

echo "Deploying Semantic Cache Cleanup utility ..."

integrationcli integrations apply -e dev -f ./cleanup-semantic-cache-v1/

rm -rf ./tmp

echo "You can review the deployed semantic cache cleanup utility here: https://console.cloud.google.com/integrations/edit/cleanup-semantic-cache-v1/locations/$REGION?project=$PROJECT"
echo " "
echo "You can now go back to the Colab notebook to test the sample. You will need the following variables during your test."
echo "Your PROJECT_ID is: $PROJECT"
echo "Your REGION is: $REGION"
echo "Your API_ENDPOINT is: https://$APIGEE_HOST/v2/samples/llm-semantic-cache"
