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

if [ -z "$VERTEXAI_REGION" ]; then
  echo "No VERTEXAI_REGION variable set"
  exit 1
fi

# if [ -z "$OAUTH_CLIENT_ID" ]; then
#   echo "No OAUTH_CLIENT_ID variable set"
#   exit 1
# fi

# if [ -z "$OAUTH_CLIENT_SECRET" ]; then
#   echo "No OAUTH_CLIENT_SECRET variable set"
#   exit 1
# fi

TOKEN=$(gcloud auth print-access-token)

echo "================================================="
echo "Started create-integration-connector.sh"
echo "================================================="

echo "Assigning roles to Default compute service account"
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$PROJECT_NUMBER-compute@developer.gserviceaccount.com" \
    --role="roles/secretmanager.viewer"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$PROJECT_NUMBER-compute@developer.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"

# SECRET_ID=cymbal-retail-agent-client-secret
# echo "Creating Secret $SECRET_ID in Project $PROJECT_ID"
# gcloud secrets create "$SECRET_ID" --replication-policy="automatic" --project "$PROJECT_ID"
# echo -n "$OAUTH_CLIENT_SECRET" | gcloud secrets versions add "$SECRET_ID" --project "$PROJECT_ID" --data-file=- 
# echo "Secret $SECRET_ID created successfully"

echo "Installing integrationcli"
curl -L https://raw.githubusercontent.com/GoogleCloudPlatform/application-integration-management-toolkit/main/downloadLatest.sh | sh -
export PATH=$PATH:$HOME/.integrationcli/bin

#cp connectors/bq-products.json connectors/bq-products-tmp.json
#sed -i "s/OAUTH_CLIENT_ID/$OAUTH_CLIENT_ID/g" connectors/bq-products-tmp.json
#sed -i "s/PROJECT_ID/$PROJECT_ID/g" connectors/bq-products-tmp.json

#echo "Creating BigQuery Connector"
#integrationcli connectors create -n bq-products -f connectors/bq-products-tmp.json -p "$PROJECT_ID" -r "$VERTEXAI_REGION" -t "$TOKEN" -g --wait

#rm connectors/bq-products-tmp.json
#echo "BigQuery Connector created successfully"

echo "Publishing Integration"
# integrationcli integrations apply -f products-integration/. -p "$PROJECT_ID" -r "$VERTEXAI_REGION" -t "$TOKEN" -g --wait
integrationcli integrations apply -f shipping-integration/. -p "$PROJECT_ID" -r "$VERTEXAI_REGION" -t "$TOKEN" -g --wait


echo "================================================="
echo "Finished create-integration-connector.sh"
echo "================================================="