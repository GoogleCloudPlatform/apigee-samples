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


# Source default values
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
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

APIGEE_ORG="${PROJECT_ID}"

# Use the same region as the Apigee runtime instance
INSTANCE_LOCATION=$(apigeecli instances get --name "$APIGEE_INSTANCE_NAME" --org "${PROJECT_ID}" --token "$TOKEN" 2> /dev/null | jq -e -r '.location')
if [ "$INSTANCE_LOCATION" == "null" ] || [ -z "$INSTANCE_LOCATION" ]; then
     echo "❌ Error: could not get location for Apigee runtime instance"
     exit 1
fi
export INSTANCE_LOCATION


echo ""
echo "🧹 Starting cleanup script for API Proxy"

echo ""
echo "🗑️ Delete IAM Binding  ..."
gcloud run services remove-iam-policy-binding "$CLOUD_RUN_NAME"  \
  --region "$INSTANCE_LOCATION"  \
  --member "serviceAccount:${CLOUD_RUN_SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role roles/run.invoker \
  --quiet \
  --project "$PROJECT_ID" && \
  echo "✅ Successfully removed IAM policy binding."

echo ""
echo "🗑️ Delete Service Account for Cloud Run  ..."
gcloud iam service-accounts delete "$CLOUD_RUN_SERVICE_ACCOUNT_NAME@${PROJECT_ID}.iam.gserviceaccount.com" \
    --quiet \
    --project "$PROJECT_ID" && \
    echo "✅ Successfully deleted Service Account."

echo ""
echo "🗑️ Undeploying and deleting API proxy '$PROXY_NAME' from environment '$ENV_NAME'..."
apigeecli apis undeploy \
  --name "$PROXY_NAME" \
  --env "$ENV_NAME" \
  --org "$APIGEE_ORG" \
  --token "$TOKEN" && \
  echo "✅ API Proxy '$PROXY_NAME' undeployed and from environment '$ENV_NAME' "

apigeecli apis delete \
  --name "$PROXY_NAME" \
  --org "$APIGEE_ORG" \
  --token "$TOKEN" && \
  echo "✅ API Proxy '$PROXY_NAME' deleted from organization '$APIGEE_ORG'"

echo ""
echo "🎉 Apigee API Proxy cleanup completed."
