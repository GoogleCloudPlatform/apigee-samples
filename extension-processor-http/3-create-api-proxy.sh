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

# Source default values
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/defaults.sh"

echo "🔄 Installing apigeecli ..."
curl -s https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | bash
export PATH=$HOME/.apigeecli/bin:$PATH
echo "✅ apigeecli installed."

echo "🔄 Generating GCP access token..."
TOKEN=$(gcloud auth print-access-token)
export TOKEN
echo "✅ Token generated."


echo "Starting script to create API Proxy for httpbin.org ..."
echo "Using Project ID: $PROJECT_ID"

echo ""
echo "🔄 Step 1: Deploy API proxy '$PROXY_NAME' from to environment '$ENV_NAME'..."
apigeecli apis create bundle  \
   --name "$PROXY_NAME" \
   --proxy-folder "$PROXY_BUNDLE_DIR" \
   --org "$APIGEE_ORG" \
   --env "$ENV_NAME" \
   --token "$TOKEN" \
   --ovr \
   --wait
echo "✅ Successfully created API Proxy '$PROXY_NAME' "

echo "--------------------------------------------------------------------------"
echo "🎉 Apigee API Proxy '$PROXY_NAME' configured!"
echo "--------------------------------------------------------------------------"



