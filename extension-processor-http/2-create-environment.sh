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
  echo "❌ Error: No PROJECT_ID variable set. Please set it and re-run."
  exit 1
fi

if [ -z "$APIGEE_INSTANCE_NAME" ]; then
  echo "❌ Error: No APIGEE_INSTANCE_NAME variable set. Please set it and re-run."
  exit 1
fi

# Source default values
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "$SCRIPT_DIR/defaults.sh"

echo "🔄 Installing apigeecli ..."
curl -s https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | bash
export PATH=$HOME/.apigeecli/bin:$PATH
echo "✅ apigeecli installed."

echo "🔄 Generating GCP access token..."
TOKEN=$(gcloud auth print-access-token)
export TOKEN
echo "✅ Token generated."

echo "Starting script to create Apigee Extension Processor Environment and API Proxy ..."
echo "Using Project ID: $PROJECT_ID"

echo ""
echo "🔄 Step 1: Creating new environment '$ENV_NAME' in organization '$APIGEE_ORG'..."
apigeecli environments create \
  --deptype "PROXY" \
  --env "$ENV_NAME" \
  --org "$APIGEE_ORG" \
  --token "$TOKEN" \
  --wait

apigeecli environments set \
  --name "apigee-service-extension-enabled" \
  --value="true" \
  --env "$ENV_NAME" \
  --org "$APIGEE_ORG" \
  --token "$TOKEN"
echo "✅ Successfully created environment '$ENV_NAME'."

echo ""
echo "🔄 Step 2: Creating environment group '$GROUP_NAME'..."

FORWARDING_RULE_IP_ADDRESS=$(gcloud compute forwarding-rules describe "$FORWARDING_RULE_NAME" --global --format=json 2>/dev/null | jq -e -r ".IPAddress" || echo "null")
if [ "$FORWARDING_RULE_IP_ADDRESS" == "null" ] || [ -z "$FORWARDING_RULE_IP_ADDRESS" ]; then
  echo "❌ Error: could not get IPAddress for global forwarding rule named '$FORWARDING_RULE_NAME' "
  exit 1
fi
export FORWARDING_RULE_IP_ADDRESS

apigeecli envgroups create \
  --name "$GROUP_NAME" \
  --hosts "${FORWARDING_RULE_IP_ADDRESS}.nip.io" \
  --org "$APIGEE_ORG" \
  --token "$TOKEN" \
  --wait

apigeecli envgroups attach \
  --name "$GROUP_NAME" \
  --env "$ENV_NAME" \
  --org "$APIGEE_ORG" \
  --token "$TOKEN" \
  --wait

echo "✅ Successfully created environment group '$GROUP_NAME'."

echo ""
echo "🔄 Step 3: Attaching environment '$ENV_NAME' to instance '$APIGEE_INSTANCE_NAME'..."
apigeecli instances attachments attach \
  --name "$APIGEE_INSTANCE_NAME" \
  --env "$ENV_NAME" \
  --org "$APIGEE_ORG" \
  --token "$TOKEN" \
  --wait
echo "✅ Successfully attached environment '$ENV_NAME' to runtime instance"

echo "---------------------------------------------"
echo "🎉 Apigee environment '$ENV_NAME' configured!"
echo "---------------------------------------------"
