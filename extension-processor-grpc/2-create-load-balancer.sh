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

echo "⚙️ Starting script to create Global External Load Balancer..."

LB_ALREADY_CREATED=$(gcloud compute forwarding-rules list --format "json" --project "${PROJECT_ID}" | jq -e -r ".[].name" | grep -c "$FORWARDING_RULE_NAME" || true)

if [[ "${LB_ALREADY_CREATED}" == "1" ]]; then
  echo "✅ Load Balancer already created ..."
  EXTERNAL_IP=$(gcloud compute forwarding-rules describe "$FORWARDING_RULE_NAME" --global --format "json" --project "${PROJECT_ID}" | jq -e -r ".IPAddress")
  echo "--------------------------------------------------"
  echo " 🎉Load Balancer configured!"
  echo " Use the following hostname to test the gRPC service:"
  echo ""
  echo "   export LB_HOSTNAME='$EXTERNAL_IP.nip.io'"
  echo ""
  echo "--------------------------------------------------"
  exit 0
fi

echo ""
echo "🔄 1. Creating static external IP address: $IP_NAME..."
gcloud compute addresses create "$IP_NAME" \
  --project="$PROJECT_ID" \
  --global

# Get the allocated IP address
EXTERNAL_IP=$(gcloud compute addresses describe "$IP_NAME" \
  --project="$PROJECT_ID" \
  --global \
  --format="value(address)")

if [ -z "$EXTERNAL_IP" ]; then
  echo "❌ Error: Failed to create or retrieve IP address. Exiting."
  exit 1
fi
echo "✅ Successfully created static IP: $EXTERNAL_IP"
echo "Hostname for certificate will be: $EXTERNAL_IP.nip.io"

echo ""
echo "🔄 2. Creating Serverless NEG: $SERVICE_NEG_NAME..."

# Use the same region as the Apigee runtime instance
INSTANCE_LOCATION=$(apigeecli instances get --name "$APIGEE_INSTANCE_NAME" --org "${PROJECT_ID}" --token "$TOKEN" 2>/dev/null | jq -e -r '.location')
if [ "$INSTANCE_LOCATION" == "null" ] || [ -z "$INSTANCE_LOCATION" ]; then
  echo "❌ Error: could not get location for Apigee runtime instance"
  exit 1
fi
export INSTANCE_LOCATION

gcloud compute network-endpoint-groups create "$SERVICE_NEG_NAME" \
  --project="$PROJECT_ID" \
  --region "$INSTANCE_LOCATION" \
  --network-endpoint-type "SERVERLESS" \
  --cloud-run-service "$CLOUD_RUN_NAME"

echo "✅ Successfully created Serverless NEG for gRPC service."

echo ""
echo "🔄 3. Creating backend service: $SERVICE_BACKEND_SERVICE_NAME..."
gcloud compute backend-services create "$SERVICE_BACKEND_SERVICE_NAME" \
  --project="$PROJECT_ID" \
  --load-balancing-scheme="EXTERNAL_MANAGED" \
  --global

gcloud compute backend-services add-backend "$SERVICE_BACKEND_SERVICE_NAME" \
  --project="$PROJECT_ID" \
  --network-endpoint-group="$SERVICE_NEG_NAME" \
  --network-endpoint-group-region="$INSTANCE_LOCATION" \
  --global
echo "✅ Successfully created backend service and added NEG."

echo ""
echo "🔄 4. Creating URL map: $URL_MAP_NAME..."
gcloud compute url-maps create "$URL_MAP_NAME" \
  --project="$PROJECT_ID" \
  --default-service="$SERVICE_BACKEND_SERVICE_NAME" \
  --global
echo "✅ Successfully created URL map."

echo ""
echo "🔄 5. Creating Google-managed SSL certificate: $CERT_NAME for $EXTERNAL_IP.nip.io..."
gcloud compute ssl-certificates create "$CERT_NAME" \
  --project="$PROJECT_ID" \
  --domains="$EXTERNAL_IP.nip.io" \
  --global
echo "✅ SSL certificate creation initiated. Provisioning may take time."

echo ""
echo "🔄 6. Creating target HTTPS proxy: $TARGET_PROXY_NAME..."
gcloud compute target-https-proxies create "$TARGET_PROXY_NAME" \
  --project="$PROJECT_ID" \
  --url-map="$URL_MAP_NAME" \
  --ssl-certificates="$CERT_NAME" \
  --global
echo "✅ Successfully created target HTTPS proxy."

echo ""
echo "🔄 7. Creating global forwarding rule: $FORWARDING_RULE_NAME..."
gcloud compute forwarding-rules create "$FORWARDING_RULE_NAME" \
  --project="$PROJECT_ID" \
  --address="$IP_NAME" \
  --target-https-proxy="$TARGET_PROXY_NAME" \
  --load-balancing-scheme="EXTERNAL_MANAGED" \
  --ports="443" \
  --global
echo "✅ Successfully created global forwarding rule."

# Wait for certificate to be ACTIVE
SLEEP_TIME=30
while true; do
  STATUS=$(gcloud compute ssl-certificates describe "$CERT_NAME" \
    --global \
    --project "$PROJECT_ID" \
    --format='get(managed.status)' 2>/dev/null)

  STATUS=$(echo "$STATUS" | tr -d '[:space:]')
  if [ -z "$STATUS" ]; then
    echo "Could not retrieve certificate status. Aborting ..."
    break
  elif [[ "$STATUS" == *"FAILED"* ]]; then
    echo "❌ Error: Certificate '$CERT_NAME' status is '$STATUS'. Aborting ..."
    exit 1
  elif [ "$STATUS" == "ACTIVE" ]; then
    echo "Certificate '$CERT_NAME' is now ACTIVE!"
    break
  else
    echo "Certificate is in $STATUS status. Waiting for ACTIVE... "
  fi

  sleep "${SLEEP_TIME}"
done

echo "--------------------------------------------------"
echo " 🎉Load Balancer configured!"
echo " Use the following hostname to test the gRPC service:"
echo ""
echo "   export LB_HOSTNAME='$EXTERNAL_IP.nip.io'"
echo ""
echo "--------------------------------------------------"
