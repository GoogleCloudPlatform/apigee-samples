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

echo "Starting script to create Global External Load Balancer..."
echo "Using Project ID: $PROJECT_ID"

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
echo "🔄 2. Creating Internet NEG: $SERVICE_NEG_NAME..."
gcloud compute network-endpoint-groups create "$SERVICE_NEG_NAME" \
    --project="$PROJECT_ID" \
    --global \
    --network-endpoint-type="INTERNET_FQDN_PORT" \
    --default-port="443"

gcloud compute network-endpoint-groups update "$SERVICE_NEG_NAME" \
    --project="$PROJECT_ID" \
    --global \
    --add-endpoint="fqdn=httpbin.org,port=443"
echo "✅ Successfully created Internet NEG and added httpbin.org endpoint."

echo ""
echo "🔄 3. Creating Google-managed SSL certificate: $CERT_NAME for $EXTERNAL_IP.nip.io..."
gcloud compute ssl-certificates create "$CERT_NAME" \
    --project="$PROJECT_ID" \
    --domains="$EXTERNAL_IP.nip.io" \
    --global
echo "✅ SSL certificate creation initiated. Provisioning may take time."

echo ""
echo "🔄 4. Creating backend service: $SERVICE_BACKEND_SERVICE_NAME..."
gcloud compute backend-services create "$SERVICE_BACKEND_SERVICE_NAME" \
    --project="$PROJECT_ID" \
    --protocol="HTTPS" \
    --port-name="https" \
    --load-balancing-scheme="EXTERNAL_MANAGED" \
    --global

gcloud compute backend-services add-backend "$SERVICE_BACKEND_SERVICE_NAME" \
    --project="$PROJECT_ID" \
    --network-endpoint-group="$SERVICE_NEG_NAME" \
    --global-network-endpoint-group \
    --global
echo "✅ Successfully created backend service and added NEG."

echo ""
echo "🔄 5. Creating URL map: $URL_MAP_NAME..."
gcloud compute url-maps create "$URL_MAP_NAME" \
    --project="$PROJECT_ID" \
    --default-service="$SERVICE_BACKEND_SERVICE_NAME" \
    --global
echo "✅ Successfully created URL map."

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

echo "--------------------------------------------------"
echo " 🎉Load Balancer configured!"
echo " Access your service at: "
echo "   export LB_HOSTNAME=$EXTERNAL_IP.nip.io"
echo "--------------------------------------------------"
echo "⚠️ IMPORTANT NOTES: ⚠️"
echo "1. SSL Certificate Provisioning: Google-managed certificates can take 10-15 minutes or longer to provision. Until the certificate status is ACTIVE, you might see SSL errors."
echo "   You can check the certificate status with: gcloud compute ssl-certificates describe $CERT_NAME --global --project $PROJECT_ID --format='get(managed.status)'"