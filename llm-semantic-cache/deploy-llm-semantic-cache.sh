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
gcloud config set project $PROJECT

PROJECT_NUMBER==$(gcloud projects list --filter="$(gcloud config get-value project)" --format="value(PROJECT_NUMBER)")
INDEX_ID=$(gcloud ai indexes list --project=$PROJECT --region=$REGION --format="json" | jq -c -r '.[] | select(.displayName="semantic-cache") | .name | split("/") | .[5]')
INDEX_ENDPOINT_ID=$(gcloud ai index-endpoints list --project=$PROJECT --region=$REGION --format="json" | jq -c -r '.[] | select(.displayName="semantic-cache") | .name | split("/") | .[5]')
PUBLIC_ENDPOINT_SUBDOMAIN=$(gcloud ai index-endpoints list --project=$PROJECT --region=$REGION --format="json" | jq -c -r '.[] | select(.displayName="semantic-cache") | .publicEndpointDomainName | split(".") | .[0]')

PRE_PROP="project_id=$PROJECT\nproject_number=$PROJECT_NUMBER\nmodel_id=$MODEL_ID\nembeddings_model_id=$EMBEDDINGS_MODEL_ID\nregion=$REGION\nindex_id=$INDEX_ID\nindex_id_name=semantic_cache\nindex_endpoint_id=$INDEX_ENDPOINT_ID\nindex_endpoint_subdomain=387635837\nindex_endpoint_subdomain=$PUBLIC_ENDPOINT_SUBDOMAIN\nnearest_neighbor_min_distance=$NEAREST_NEIGHBOR_DISTANCE\ncache_entry_ttl_sec=$CACHE_ENTRY_TTL_SEC"

touch ./apiproxy/resources/properties/vertex_config.properties && echo "$PRE_PROP" > ./apiproxy/resources/properties/vertex_config.properties

echo "Deploying Apigee artifacts..."

echo "Importing and Deploying Apigee semantic-cache-request-v1 sharedflow..."
REV_SF=$(apigeecli sharedflows create bundle -f ./semantic-cache-request-v1/sharedflowbundle -n semantic-cache-request-v1 --org "$PROJECT" --token "$TOKEN" --disable-check | jq ."revision" -r)
apigeecli sharedflows deploy --name semantic-cache-request-v1 --ovr --rev "$REV_SF" --org "$PROJECT" --env "$APIGEE_ENV" --token "$TOKEN"

echo "Importing and Deploying Apigee semantic-cache-response-v1 sharedflow..."
REV_SF=$(apigeecli sharedflows create bundle -f ./semantic-cache-response-v1/sharedflowbundle -n semantic-cache-response-v1 --org "$PROJECT" --token "$TOKEN" --disable-check | jq ."revision" -r)
apigeecli sharedflows deploy --name semantic-cache-response-v1 --ovr --rev "$REV_SF" --org "$PROJECT" --env "$APIGEE_ENV" --token "$TOKEN"

echo "Importing and Deploying Apigee llm-semantic-cache-v1 proxy..."
REV=$(apigeecli apis create bundle -f ./apiproxy -n llm-semantic-cache-v1 --org "$PROJECT" --token "$TOKEN" --disable-check | jq ."revision" -r)
apigeecli apis deploy --wait --name llm-semantic-cache-v1 --ovr --rev "$REV" --org "$PROJECT" --env "$APIGEE_ENV" --token "$TOKEN"

FIND_NEIGHBORS_URL="https://$PUBLIC_ENDPOINT_SUBDOMAIN.$REGION-$PROJECT_NUMBER.vdb.vertexai.goog/v1/projects/$PROJECT_NUMBER/locations/$REGION/indexEndpoints/$INDEX_ENDPOINT_ID:findNeighbors"
REMOVE_DATAPOINTS_URL="https://$REGION-aiplatform.googleapis.com/v1/projects/$PROJECT_NUMBER/locations/$REGION/indexes/$INDEX_ID:removeDatapoints"
SERVICE_ACCOUNT_ID="ai-client@$PROJECT.iam.gserviceaccount.com"

sed -i "s/FIND_NEIGHBORS_URL/$FIND_NEIGHBORS_URL/g" ./cleanup-semantic-cache-v1/dev/overrides/overrides.json
sed -i "s/REMOVE_DATAPOINTS_URL/$REMOVE_DATAPOINTS_URL/g" ./cleanup-semantic-cache-v1/dev/overrides/overrides.json
sed -i "s/SERVICE_ACCOUNT_ID/$SERVICE_ACCOUNT_ID/g" ./cleanup-semantic-cache-v1/dev/authconfigs/ai-cllient.json

echo "Installing integrationcli"
curl -L https://raw.githubusercontent.com/GoogleCloudPlatform/application-integration-management-toolkit/main/downloadLatest.sh | sh -
export PATH=$PATH:$HOME/.integrationcli/bin

integrationcli prefs set --reg=$REGION --proj=$PROJECT
integrationcli token cache -t $TOKEN

echo "Deploying Semantic Cache Cleanup utility ..."

integrationcli integrations apply -e dev -f ./cleanup-semantic-cache-v1/
