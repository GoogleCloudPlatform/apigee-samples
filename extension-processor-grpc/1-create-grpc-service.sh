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

# Source default values
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "$SCRIPT_DIR/defaults.sh"

echo "🔄 Installing apigeecli ..."
curl -s https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | bash
export PATH=$HOME/.apigeecli/bin:$PATH
echo "✅ apigeecli installed."

if [ -z "$PROJECT_ID" ]; then
  echo "❌ Error: No PROJECT_ID variable set. Please set it and re-run."
  exit 1
fi

echo "🔄 Generating GCP access token..."
TOKEN=$(gcloud auth print-access-token --project "${PROJECT_ID}")
export TOKEN
echo "✅ Token generated."

# Use the same region as the Apigee runtime instance
INSTANCE_LOCATION=$(apigeecli instances get --name "$APIGEE_INSTANCE_NAME" --org "${PROJECT_ID}" --token "$TOKEN" 2>/dev/null | jq -e -r '.location')
if [ "$INSTANCE_LOCATION" == "null" ] || [ -z "$INSTANCE_LOCATION" ]; then
  echo "❌ Error: could not get location for Apigee runtime instance"
  exit 1
fi
export INSTANCE_LOCATION

echo "⚙️ Starting script to create gRPC service in Cloud Run ..."

echo ""
echo "🔄 1. Enabling services for Cloud Run ..."
gcloud services enable \
  cloudbuild.googleapis.com \
  run.googleapis.com \
  artifactregistry.googleapis.com \
  --project "$PROJECT_ID"
echo "✅ Successfully enabled services"
sleep 10

CLOUD_RUN_ALREADY_DEPLOYED=$(gcloud run services list --format "json" --project "${PROJECT_ID}" | jq -e -r ".[].metadata.name" | grep -c "$CLOUD_RUN_NAME" || true)

if [[ "${CLOUD_RUN_ALREADY_DEPLOYED}" == "1" ]]; then
  echo "✅ gRPC service already deployed to Cloud Run ..."
else
  echo ""
  echo "🔄 2. Deploying gRPC Cloud Run  ..."
  gcloud run deploy "$CLOUD_RUN_NAME" \
    --timeout 3600 \
    --region="${INSTANCE_LOCATION}" \
    --set-custom-audiences "extproc-sample-audience" \
    --source=./backend \
    --quiet \
    --project "$PROJECT_ID"

  echo "✅ Successfully deployed gRPC Cloud Run"
fi

CLOUD_RUN_URL=$(gcloud run services describe "$CLOUD_RUN_NAME" --region "${INSTANCE_LOCATION}" --project "${PROJECT_ID}" --format json | jq -e -r ".status.url")

if [[ "$CLOUD_RUN_URL" == "null" || -z "${CLOUD_RUN_URL}" ]]; then
  echo "❌ Error: could not get URL for Cloud Run ${CLOUD_RUN_NAME}"
  exit 1
fi

CR_HOSTNAME=${CLOUD_RUN_URL#"https://"}

echo "--------------------------------------------------"
echo " 🎉gRPC Cloud Run configured!"
echo " Use the following hostname to test the gRPC service:"
echo ""
echo "   export CR_HOSTNAME='${CR_HOSTNAME}'"
echo ""
echo "--------------------------------------------------"
