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
  echo "❌ Error: No PROJECT_ID variable set. Please set it and re-run."
  exit 1
fi

# Source default values
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/defaults.sh"


# Apigee
export APIGEE_ORG="${PROJECT_ID}"


echo "🔄 Installing apigeecli ..."
curl -s https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | bash
export PATH=$HOME/.apigeecli/bin:$PATH
echo "✅ apigeecli installed."

echo "🔄 Generating GCP access token..."
TOKEN=$(gcloud auth print-access-token)
export TOKEN
echo "✅ Token generated."


INSTANCE_LOCATION=$(apigeecli instances get --name "$APIGEE_INSTANCE_NAME" --org "$APIGEE_ORG" --token "$TOKEN" 2> /dev/null | jq -e -r '.location' || echo "null")
if [ "$INSTANCE_LOCATION" == "null" ] || [ -z "$INSTANCE_LOCATION" ]; then
     echo "❌ Error: could get not location for Apigee runtime instance"
     exit 1
fi
export INSTANCE_LOCATION

echo "🧹 Starting cleanup script for Service Extension  resources..."

echo ""
echo "🗑️ Deleting Service Extension ..."
gcloud service-extensions lb-traffic-extensions delete "$SERVICE_EXTENSION_NAME" \
  --location=global \
  --quiet && \
  echo "✅ Service Extension '$SERVICE_EXTENSION_NAME' deleted successfully."
echo ""

rm -f service-extension.yaml


echo ""
echo "🗑️ Removing PSC NEG '$RUNTIME_NEG_NAME' from the '$RUNTIME_BACKEND_SERVICE_NAME' backend service ..."
gcloud compute backend-services remove-backend "$RUNTIME_BACKEND_SERVICE_NAME" \
    --network-endpoint-group="$RUNTIME_NEG_NAME" \
    --network-endpoint-group-region="$INSTANCE_LOCATION" \
    --global \
    --quiet && \
    echo "✅ PSC NEG '$RUNTIME_NEG_NAME' removed from backend service"
echo ""


echo ""
echo "🗑️ Deleting '$RUNTIME_BACKEND_SERVICE_NAME' backend service ..."
gcloud compute backend-services delete "$RUNTIME_BACKEND_SERVICE_NAME" \
    --global \
    --quiet && \
    echo "✅  Backend Service '$RUNTIME_BACKEND_SERVICE_NAME' deleted."
echo ""

echo ""
echo "🗑️ Deleting PSC NEG '$RUNTIME_NEG_NAME' ..."
gcloud compute network-endpoint-groups delete "$RUNTIME_NEG_NAME" \
    --region "$INSTANCE_LOCATION" \
    --quiet && \
    echo "✅  PSC NEG '$RUNTIME_NEG_NAME' deleted."


echo ""
echo "🎉 Service Extension cleanup completed!"
