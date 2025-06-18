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

echo ""
echo "🧹 Starting cleanup script for Developer App"

echo ""
echo "🗑️ Delete Developer App ..."
apigeecli apps delete \
  --name "$DEVELOPER_APP_NAME" \
  --id "$DEVELOPER_NAME@acme.com" \
  --org "$APIGEE_ORG" \
  --token "$TOKEN" &&
  echo "✅ Successfully deleted Developer App."

echo ""
echo "🗑️  Delete App Developer '$DEVELOPER_NAME' ..."
apigeecli developers delete \
  --email "$DEVELOPER_NAME@acme.com" \
  --org "$APIGEE_ORG" \
  --token "$TOKEN" &&
  echo "✅ Successfully deleted App Developer."

echo ""
echo "🎉 Apigee Developer App cleanup completed."
