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
  echo "❌ Error: No $PROJECT_ID variable set. Please set it and re-run."
  exit 1
fi

# Source default values
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "$SCRIPT_DIR/defaults.sh"

echo "🧹 Starting cleanup script for External Global Load Balancer resources..."

echo "🗑️ Deleting Global Forwarding Rule: $FORWARDING_RULE_NAME..."
gcloud compute forwarding-rules delete "$FORWARDING_RULE_NAME" \
  --project="$PROJECT_ID" \
  --global \
  --quiet &&
  echo "✅ Successfully deleted Global Forwarding Rule: $FORWARDING_RULE_NAME."

echo "🗑️ Deleting Target HTTPS Proxy: $TARGET_PROXY_NAME..."
gcloud compute target-https-proxies delete "$TARGET_PROXY_NAME" \
  --project="$PROJECT_ID" \
  --global \
  --quiet &&
  echo "✅ Successfully deleted Target HTTPS Proxy: $TARGET_PROXY_NAME."

echo "🗑️ Deleting URL Map: $URL_MAP_NAME..."
gcloud compute url-maps delete "$URL_MAP_NAME" \
  --project="$PROJECT_ID" \
  --global \
  --quiet &&
  echo "✅ Successfully deleted URL Map: $URL_MAP_NAME."

echo "🗑️ Deleting Backend Service: $SERVICE_BACKEND_SERVICE_NAME..."
gcloud compute backend-services delete "$SERVICE_BACKEND_SERVICE_NAME" \
  --project="$PROJECT_ID" \
  --global \
  --quiet &&
  echo "✅ Successfully deleted Backend Service: $SERVICE_BACKEND_SERVICE_NAME."

echo "🗑️ Deleting SSL Certificate: $CERT_NAME..."
gcloud compute ssl-certificates delete "$CERT_NAME" \
  --project="$PROJECT_ID" \
  --global \
  --quiet &&
  echo "✅ Successfully deleted SSL Certificate: $CERT_NAME."

echo "🗑️ Deleting Internet NEG: $SERVICE_NEG_NAME..."
gcloud compute network-endpoint-groups delete "$SERVICE_NEG_NAME" \
  --project="$PROJECT_ID" \
  --global \
  --quiet &&
  echo "✅ Successfully deleted Internet NEG: $SERVICE_NEG_NAME."

echo "🗑️ Deleting Static External IP Address: $IP_NAME..."
gcloud compute addresses delete "$IP_NAME" \
  --project="$PROJECT_ID" \
  --global \
  --quiet &&
  echo "✅ Successfully deleted Static External IP Address: $IP_NAME."

echo ""
echo "🎉 External Global Load Balancer cleanup completed."
