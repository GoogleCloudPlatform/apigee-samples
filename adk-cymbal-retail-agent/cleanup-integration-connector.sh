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

TOKEN=$(gcloud auth print-access-token)

remove_role_from_service_account() {
  local role=$1
  gcloud projects remove-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$PROJECT_NUMBER-compute@developer.gserviceaccount.com" \
    --role="$role"
}

echo "Installing integrationcli"
curl -L https://raw.githubusercontent.com/GoogleCloudPlatform/application-integration-management-toolkit/main/downloadLatest.sh | sh -
export PATH=$PATH:$HOME/.integrationcli/bin

echo "Deleting BQ Connector"
integrationcli connectors delete -n bq-products -p "$PROJECT_ID" -r "$VERTEXAI_REGION" -t "$TOKEN"

echo "Deleting the Secret"
SECRET_ID=cymbal-retail-agent-client-secret
gcloud secrets delete "$SECRET_ID" --project "$PROJECT_ID" --quiet

echo "Deleting roles from Default compute service account"
remove_role_from_service_account "roles/secretmanager.viewer"
remove_role_from_service_account "roles/secretmanager.secretAccessor"

