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

export APIGEE_INSTANCE_NAME="eval-instance"
export VPC_PSC_SUBNET_NAME="default-psc-only"
export VPC_NETWORK_NAME="default"


echo "🔄 Installing pre-requisites ..."
apt-get install -y unzip jq curl
echo "✅ Successfully installed pre-requisites"

echo "🔄 Updating gcloud ..."
gcloud components update --version "523.0.1" --quiet
echo "✅ Successfully updated gcloud"

echo "🔄 Installing apigeecli ..."
curl -s https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | bash
export PATH=$HOME/.apigeecli/bin:$PATH
echo "✅ apigeecli installed."

echo "🔄 Generating GCP access token..."
TOKEN=$(gcloud auth print-access-token --project "${PROJECT_ID}")
export TOKEN
echo "✅ Token generated."

# Use the same region as the Apigee runtime instance
INSTANCE_LOCATION=$(apigeecli instances get --name "$APIGEE_INSTANCE_NAME" --org "${PROJECT_ID}" --token "$TOKEN" 2> /dev/null | jq -e -r '.location')
if [ "$INSTANCE_LOCATION" == "null" ] || [ -z "$INSTANCE_LOCATION" ]; then
     echo "❌ Error: could not get location for Apigee runtime instance"
     exit 1
fi
export INSTANCE_LOCATION

echo "⚙️ Starting script to deploy Qwiklabs resources ..."



echo "🔄 Creating PSC-Only subnet \"$VPC_PSC_SUBNET_NAME\" in \"$VPC_NETWORK_NAME\" VPC..."
gcloud compute networks subnets create "$VPC_PSC_SUBNET_NAME" \
  --network="${VPC_NETWORK_NAME}" \
  --region="${INSTANCE_LOCATION}" \
  --range="192.168.1.0/24" \
  --purpose=PRIVATE_SERVICE_CONNECT \
  --project "${PROJECT_ID}"
echo "✅ Successfully created PSC-Only subnet"

./1-create-grpc-service.sh
./2-create-load-balancer.sh

echo "---------------------------------------------"
echo "🎉 Qwiklabs setup complete!"
echo "---------------------------------------------"



