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

INSTANCE_SERVICE_ATTACHMENT=$(apigeecli instances get --name "$APIGEE_INSTANCE_NAME" --org "$APIGEE_ORG" --token "$TOKEN" 2>/dev/null | jq -e -r '.serviceAttachment' || echo "null")
if [ "$INSTANCE_SERVICE_ATTACHMENT" == "null" ] || [ -z "$INSTANCE_SERVICE_ATTACHMENT" ]; then
  echo "❌ Error: could not get serviceAttachment for Apigee runtime instance"
  exit 1
fi
export INSTANCE_SERVICE_ATTACHMENT

INSTANCE_LOCATION=$(apigeecli instances get --name "$APIGEE_INSTANCE_NAME" --org "$APIGEE_ORG" --token "$TOKEN" 2>/dev/null | jq -e -r '.location' || echo "null")
if [ "$INSTANCE_LOCATION" == "null" ] || [ -z "$INSTANCE_LOCATION" ]; then
  echo "❌ Error: could not get location for Apigee runtime instance"
  exit 1
fi
export INSTANCE_LOCATION

echo "Starting script to create Service Extension for GLobal External Load Balancer ..."
echo "Using Project ID: $PROJECT_ID"

echo ""
echo "🔄 1. Creating PSC Network Endpoint Group (NEG) for Apigee runtime ..."
gcloud compute network-endpoint-groups create "$RUNTIME_NEG_NAME" \
  --psc-target-service="$INSTANCE_SERVICE_ATTACHMENT" \
  --region="$INSTANCE_LOCATION" \
  --network="$VPC_NETWORK_NAME" \
  --subnet="$VPC_PSC_SUBNET_NAME" \
  --network-endpoint-type="PRIVATE_SERVICE_CONNECT" \
  --producer-port=443

echo "✅ PSC NEG '$RUNTIME_NEG_NAME' created successfully."

echo ""
echo "🔄 2. Creating Global Backend Service pointing to the PSC NEG ..."
gcloud compute backend-services create "$RUNTIME_BACKEND_SERVICE_NAME" \
  --load-balancing-scheme="EXTERNAL_MANAGED" \
  --protocol=HTTP2 \
  --global
echo "✅ Global Backend Service '$RUNTIME_BACKEND_SERVICE_NAME' created successfully."

echo ""
echo "🔄 3. Adding PSC NEG to the Global Backend Service ..."
gcloud compute backend-services add-backend "$RUNTIME_BACKEND_SERVICE_NAME" \
  --network-endpoint-group="$RUNTIME_NEG_NAME" \
  --network-endpoint-group-region="$INSTANCE_LOCATION" \
  --global

gcloud compute backend-services update "$RUNTIME_BACKEND_SERVICE_NAME" \
  --global \
  --enable-logging \
  --logging-sample-rate=1.0

echo "✅ PSC NEG '$RUNTIME_NEG_NAME' added to '$RUNTIME_BACKEND_SERVICE_NAME' successfully."
echo ""

echo ""
echo "🔄 4. Creating Service Extension ..."

gcloud services enable networkservices.googleapis.com

FORWARDING_RULE_SELF_LINK=$(gcloud compute forwarding-rules describe "$FORWARDING_RULE_NAME" --global --format=json 2>/dev/null | jq -e -r ".selfLink" || echo "null")
if [ "$FORWARDING_RULE_SELF_LINK" == "null" ] || [ -z "$FORWARDING_RULE_SELF_LINK" ]; then
  echo "❌ Error: could not get selfLink for global forwarding rule named '$FORWARDING_RULE_NAME' "
  exit 1
fi
export FORWARDING_RULE_SELF_LINK

FORWARDING_RULE_IP_ADDRESS=$(gcloud compute forwarding-rules describe "$FORWARDING_RULE_NAME" --global --format=json 2>/dev/null | jq -e -r ".IPAddress" || echo "null")
if [ "$FORWARDING_RULE_IP_ADDRESS" == "null" ] || [ -z "$FORWARDING_RULE_IP_ADDRESS" ]; then
  echo "❌ Error: could not get IPAddress for global forwarding rule named '$FORWARDING_RULE_NAME' "
  exit 1
fi
export FORWARDING_RULE_IP_ADDRESS

BACKEND_SERVICE_SELF_LINK=$(gcloud compute backend-services describe "$RUNTIME_BACKEND_SERVICE_NAME" --format=json --global 2>/dev/null | jq -e -r ".selfLink" || echo "null")
if [ "$BACKEND_SERVICE_SELF_LINK" == "null" ] || [ -z "$BACKEND_SERVICE_SELF_LINK" ]; then
  echo "❌ Error: could not get selfLink for global backend service named '$BACKEND_SERVICE_SELF_LINK' "
  exit 1
fi
export BACKEND_SERVICE_SELF_LINK

cat <<EOF >service-extension.yaml
name: $SERVICE_EXTENSION_NAME
metadata:
    apigee-extension-processor: $PROXY_NAME
forwardingRules:
- $FORWARDING_RULE_SELF_LINK
loadBalancingScheme: EXTERNAL_MANAGED
extensionChains:
- name: "$SERVICE_EXTENSION_NAME-chain"
  matchCondition:
    celExpression: 'true'
  extensions:
  - name: '$SERVICE_EXTENSION_NAME'
    authority: $FORWARDING_RULE_IP_ADDRESS.nip.io
    service: $BACKEND_SERVICE_SELF_LINK
    failOpen: false
    timeout: 1s
    supportedEvents:
    - REQUEST_HEADERS
    - RESPONSE_HEADERS
EOF

gcloud service-extensions lb-traffic-extensions import "$SERVICE_EXTENSION_NAME" \
  --source=service-extension.yaml \
  --location=global

echo "✅ Service Extension '$SERVICE_EXTENSION_NAME' created successfully."
echo ""

echo "--------------------------------------------------"
echo "🎉 Service Extension configured!"
echo " Access your service at: "
echo "   export LB_HOSTNAME=$FORWARDING_RULE_IP_ADDRESS.nip.io"
echo "--------------------------------------------------"
