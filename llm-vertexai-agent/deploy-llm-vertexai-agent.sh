#!/bin/bash

# Copyright 2024 Google LLC
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
  echo "No PROJECT_ID variable set"
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

if [ -z "$TOKEN" ]; then
  TOKEN=$(gcloud auth print-access-token)
fi

gcloud services enable aiplatform.googleapis.com --project "$PROJECT_ID"

echo "Installing apigeecli"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

echo "Deploying the Proxy"
sed -i "s/HOST/$APIGEE_HOST/g" apiproxy/resources/oas/spec.yaml

apigeecli apis create bundle -n llm-vertexai-agent-v1 \
  -f apiproxy -e "$APIGEE_ENV" \
  --token "$TOKEN" -o "$PROJECT_ID" \
  --ovr --wait

sed -i "s/$APIGEE_HOST/HOST/g" apiproxy/resources/oas/spec.yaml

echo "Creating API Products"
apigeecli products create --name "llm-vertexai-agent-product" --display-name "llm-vertexai-agent-product" \
  --opgrp ./config/llm-vertexai-agent-product.ops.json --envs "$APIGEE_ENV" \
  --approval auto --org "$PROJECT_ID" --token "$TOKEN"

echo "Creating Developer"
apigeecli developers create --user llm-vertexai-agent-developer \
  --email "llm-vertexai-agent-developer@acme.com" --first="LLM VerteAI Agent" \
  --last="Sample User" --org "$PROJECT_ID" --token "$TOKEN"

echo "Creating Developer App"
apigeecli apps create --name llm-vertexai-agent-app --email "llm-vertexai-agent-developer@acme.com" \
  --prods "llm-vertexai-agent-product" --org "$PROJECT_ID" --token "$TOKEN" --disable-check

APIKEY=$(apigeecli apps get --name "llm-vertexai-agent-app" --org "$PROJECT_ID" --token "$TOKEN" --disable-check | jq ."[0].credentials[0].consumerKey" -r)

export APIKEY
export PROXY_URL="$APIGEE_HOST/v1/samples/llm-vertexai-agent"

echo " "
echo "All the Apigee artifacts are successfully deployed!"
echo " "
echo "Your Proxy URL is: https://$PROXY_URL"
echo " "
echo "Run the following commands to test the API"
echo " "
echo "curl --location \"https://$APIGEE_HOST/v1/samples/llm-vertexai-agent/products\" \
--header \"Content-Type: application/json\" \
--header \"x-apikey: $APIKEY\" "
echo " "
echo "Export these variables"
echo "export APIKEY=$APIKEY"
echo " "
echo "You can now go back to the Colab notebook to test the sample. You will need the following variables during your test."
echo "Your PROJECT_ID is: $PROJECT_ID"
echo "Your APIGEE_HOST is: $APIGEE_HOST"
echo "Your APIKEY is: $APIKEY"