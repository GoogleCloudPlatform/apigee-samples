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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "$SCRIPT_DIR/defaults.sh"

if [ -z "$PROJECT_ID" ]; then
  echo "❌ Error: No PROJECT_ID variable set. Please set it and re-run."
  exit 1
fi

if [ -z "$APIGEE_INSTANCE_NAME" ]; then
  echo "❌ Error: No APIGEE_INSTANCE_NAME variable set. Please set it and re-run."
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

echo ""
echo "🧹 Starting cleanup script for Apigee Environment"

echo ""
echo "🗑️ Detaching environment '$ENV_NAME' from its runtime instance..."
apigeecli instances attachments detach \
  --name "$APIGEE_INSTANCE_NAME" \
  --env "$ENV_NAME" \
  --org "$APIGEE_ORG" \
  --token "$TOKEN" \
  --wait &&
  echo "✅ Environment '$ENV_NAME' detached from instance '$APIGEE_INSTANCE_NAME' "

echo ""
echo "🗑️ Deleting environment group '$GROUP_NAME'..."
apigeecli envgroups delete \
  --name "$GROUP_NAME" \
  --org "$APIGEE_ORG" \
  --token "$TOKEN" &&
  echo "✅ Environment '$ENV_NAME' deleted from from organization '$APIGEE_ORG' "

echo ""
echo "🗑️ Deleting environment '$ENV_NAME'..."
apigeecli environments delete \
  --env "$ENV_NAME" \
  --org "$APIGEE_ORG" \
  --token "$TOKEN" \
  --wait &&
  echo "✅ Environment '$ENV_NAME' deleted from from organization '$APIGEE_ORG' "

echo ""
echo "🎉 Apigee Environment cleanup completed."
