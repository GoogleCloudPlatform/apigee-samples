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
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/defaults.sh"

if [ -z "$PROJECT_ID" ]; then
  echo "❌ Error: No PROJECT_ID variable set. Please set it and re-run."
  exit 1
fi

echo "🔄 Installing apigeecli ..."
curl -s https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | bash
export PATH=$HOME/.apigeecli/bin:$PATH
echo "✅ apigeecli installed."

echo "🔄 Generating GCP access token..."
TOKEN=$(gcloud auth print-access-token --project "${PROJECT_ID}")
export TOKEN
echo "✅ Token generated."

echo "⚙️ Starting script to create API Proxy for httpbin.org ..."

echo ""
echo "🔄 Step 1: Create API Product '$PRODUCT_NAME' ..."

OPS_GROUP_FILE=$(mktemp)
export OPP_SGROUP_FILE

cat << EOF > "$OPS_GROUP_FILE"
{
  "operationConfigs": [
    {
      "apiSource": "extproc-proxy",
      "methods": [
        "SayHello",
        "CountTo"
      ],
      "quota": {},
      "service": "helloworld.Greeter"
    },
    {
      "apiSource": "extproc-proxy",
      "methods": [
        "ServerReflectionInfo"
      ],
      "quota": {},
      "service": "grpc.reflection.v1alpha.ServerReflection"
    },
     {
      "apiSource": "extproc-proxy",
      "methods": [
        "ServerReflectionInfo"
      ],
      "quota": {},
      "service": "grpc.reflection.v1.ServerReflection"
    }
  ]
}
EOF

apigeecli products create   \
   --name "$PRODUCT_NAME" \
   --display-name "$PRODUCT_NAME" \
   --approval "auto" \
   --grpcopgrp "$OPS_GROUP_FILE" \
   --org "$APIGEE_ORG" \
   --envs "$ENV_NAME" \
   --token "$TOKEN"
echo "✅ Successfully created API Product '$PRODUCT_NAME' "

echo "--------------------------------------------------------------------------"
echo "🎉 Apigee API Product '$PRODUCT_NAME' configured!"
echo "--------------------------------------------------------------------------"



