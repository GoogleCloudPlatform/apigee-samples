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

echo "⚙️ Starting script to create API Developer App ..."

echo ""
echo "🔄 Step 1: Create App Developer..."
apigeecli developers create \
  --user "$DEVELOPER_NAME" \
  --email "$DEVELOPER_NAME@acme.com" \
  --first="$DEVELOPER_NAME" \
  --last="Sample User" \
  --org "$APIGEE_ORG" \
  --token "$TOKEN"

echo "✅ Successfully created App Developer '$DEVELOPER_NAME' "

echo ""
echo "🔄 Step 2: Create Developer App ..."
apigeecli apps create \
  --name "$DEVELOPER_APP_NAME" \
  --email "$DEVELOPER_NAME@acme.com" \
  --prods "$PRODUCT_NAME" \
  --org "$APIGEE_ORG" \
  --token "$TOKEN" \
  --disable-check
echo "✅ Successfully created Developer App '$DEVELOPER_APP_NAME' "

DEVELOPER_APP_API_KEY=$(apigeecli apps get --name "$DEVELOPER_APP_NAME" --org "$APIGEE_ORG" --token "$TOKEN" 2>/dev/null | jq -e -r '.[0].credentials[0].consumerKey' || echo "null")

if [ "$DEVELOPER_APP_API_KEY" == "null" ] || [ -z "$DEVELOPER_APP_API_KEY" ]; then
  echo "❌ Error: could not get consumerKey for Developer App '$DEVELOPER_APP_NAME' "
  exit 1
fi
export DEVELOPER_APP_API_KEY

echo "--------------------------------------------------------------------------"
echo "🎉 Apigee Developer App '$DEVELOPER_APP_NAME' configured!"
echo " API Key:"
echo "   export DEVELOPER_APP_API_KEY=\"${DEVELOPER_APP_API_KEY}\""
echo "--------------------------------------------------------------------------"
