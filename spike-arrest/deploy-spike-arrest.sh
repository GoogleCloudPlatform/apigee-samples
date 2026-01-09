#!/bin/bash
set -euo pipefail

# Copyright 2026 Google LLC
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

if [ -z "$PROJECT" ]; then
  echo "No PROJECT variable set"
  exit
fi

if [ -z "$APIGEE_ENV" ]; then
  echo "No APIGEE_ENV variable set"
  exit
fi

if [ -z "$APIGEE_HOST" ]; then
  echo "No APIGEE_HOST variable set"
  exit
fi

TOKEN=$(gcloud auth print-access-token)

echo "Installing dependencies"
npm install

echo "Installing apigeecli"
if ! command -v apigeecli &> /dev/null; then
    echo "Installing apigeecli"
    curl -L https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | sh -
fi
export PATH=$PATH:$HOME/.apigeecli/bin

echo "Deploying Apigee artifacts..."

echo "Importing and Deploying Apigee spike-arrest proxy..."
REV=$(apigeecli apis create bundle -f apiproxy -n spike-arrest --org "$PROJECT" --token "$TOKEN" --disable-check | jq ."revision" -r)
apigeecli apis deploy --wait --name spike-arrest --ovr --rev "$REV" --org "$PROJECT" --env "$APIGEE_ENV" --token "$TOKEN"


export PROXY_URL="$APIGEE_HOST/v1/samples/spike-arrest"

echo " "
echo "All the Apigee artifacts are successfully deployed!"
echo " "
echo "Your Proxy URL is: https://$PROXY_URL"
echo " "
echo "-----------------------------"
echo " "
echo "To test the spike arrest, make multiple rapid requests:"
echo " "
echo "for i in {1..15}; do curl -v https://$PROXY_URL; sleep 0.5; done"
echo " "
