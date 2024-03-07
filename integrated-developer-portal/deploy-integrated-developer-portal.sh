#!/bin/bash

# Copyright 2023 Google LLC
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

echo "Passed variable tests"

TOKEN=$(gcloud auth print-access-token)

echo "Installing apigeecli"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

echo "Deploying Apigee artifacts..."

echo "Creating and Deploying Apigee sample-integrated-developer-portal proxy..."
REV=$(apigeecli apis create bundle -f apiproxy -n sample-integrated-developer-portal --org "$PROJECT" --token "$TOKEN" --disable-check | jq ."revision" -r)
apigeecli apis deploy --wait --name sample-integrated-developer-portal --ovr --rev "$REV" --org "$PROJECT" --env "$APIGEE_ENV" --token "$TOKEN"

echo "Creating API Product"
apigeecli products create --name sample-integrated-developer-portal-product --display-name "sample-integrated-developer-portal-product" --opgrp ./integrated-developer-portal-product-ops.json --envs "$APIGEE_ENV" --approval auto --quota 10 --interval 1 --unit minute --org "$PROJECT" --token "$TOKEN"

echo "Updating OpenAPI YAML"
sed -i "s/\[APIGEE_HOST\]/$APIGEE_HOST/" integrated-developer-portal.yaml

# var is expected by integration test (apickli)
export PROXY_URL="$APIGEE_HOST/v1/samples/integrated-developer-portal"

echo " "
echo "All the Apigee artifacts are successfully deployed!"

echo " "
echo "Your Proxy URL is: https://$PROXY_URL"
echo "You will be unable to call the proxy url until you create an API key from the developer portal"
echo "Please folow on with the instructions to create an API Key"
echo " "
