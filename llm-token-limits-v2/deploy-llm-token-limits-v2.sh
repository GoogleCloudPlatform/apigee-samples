#!/bin/bash

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

if [ -z "$TOKEN" ]; then
  TOKEN=$(gcloud auth print-access-token)
fi

echo "Installing apigeecli"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

gcloud config set project "$PROJECT"

PRE_PROP="region=$REGION"

echo "$PRE_PROP" > ./apiproxy/resources/properties/vertex_config.properties

echo "Deploying Apigee artifacts..."

echo "Creating Data collectors..."

apigeecli datacollectors create -d "Candidates token count v2" -n dc_candidates_token_count_v2 -p INTEGER --org "$PROJECT" --token "$TOKEN"
apigeecli datacollectors create -d "Prompt token count v2" -n dc_prompt_token_count_v2 -p INTEGER --org "$PROJECT" --token "$TOKEN"
apigeecli datacollectors create -d "Total token count v2" -n dc_total_token_count_v2 -p INTEGER --org "$PROJECT" --token "$TOKEN"

echo "Creating Token Consumption Report...."

curl --request POST \
  "https://apigee.googleapis.com/v1/organizations/$PROJECT/reports" \
  --header "Authorization: Bearer $TOKEN" \
  --header 'Accept: application/json' \
  --header 'Content-Type: application/json' \
  --data '{"name":"tokens-consumption-report-v2","displayName":"Tokens Consumption Report v2","metrics":[{"name":"dc_prompt_token_count_v2","function":"sum"},{"name":"dc_candidates_token_count_v2","function":"sum"},{"name":"dc_total_token_count_v2","function":"sum"}],"dimensions":["api_product","developer_app"],"properties":[{"value":[{}]}],"chartType":"line"}' \
  --compressed

echo "Importing and Deploying Apigee llm-token-limits-v2 proxy..."
REV=$(apigeecli apis create bundle -f ./apiproxy -n llm-token-limits-v2 --org "$PROJECT" --token "$TOKEN" --disable-check | jq ."revision" -r)
apigeecli apis deploy --wait --name llm-token-limits-v2 --ovr --rev "$REV" --org "$PROJECT" --env "$APIGEE_ENV" --token "$TOKEN"

echo "Creating AI Products"
apigeecli products create --name ai-product-bronze-v2 --display-name "AI Product Bronze v2" --envs "$APIGEE_ENV" --scopes "READ" --scopes "WRITE" --scopes "ACTION" --approval auto --llmopgrp ./aiproduct-bronze.json --org "$PROJECT" --token "$TOKEN"
apigeecli products create --name ai-product-silver-v2 --display-name "AI Product Silver v2" --envs "$APIGEE_ENV" --scopes "READ" --scopes "WRITE" --scopes "ACTION" --approval auto --llmopgrp ./aiproduct-silver.json --org "$PROJECT" --token "$TOKEN"

echo "Creating Developer"
apigeecli developers create --user testuser-v2 --email aidev-v2@cymbal.com --first Test --last Userv2 --org "$PROJECT" --token "$TOKEN"

echo "Creating Developer App"
apigeecli apps create --name ai-consumer-app-v2 --email aidev-v2@cymbal.com --prods ai-product-bronze-v2 --callback https://developers.google.com/oauthplayground/ --org "$PROJECT" --token "$TOKEN" --disable-check
apigeecli apps genkey --name ai-consumer-app-v2 -d aidev-v2@cymbal.com  --prods ai-product-silver-v2 --org "$PROJECT" --token "$TOKEN" --disable-check
BRONZE_KEY=$(apigeecli apps get --name ai-consumer-app-v2 --org "$PROJECT" --token "$TOKEN" --disable-check | jq .'[0].credentials[]| select(.apiProducts[0].apiproduct=="ai-product-bronze-v2").consumerKey' -r)
SILVER_KEY=$(apigeecli apps get --name ai-consumer-app-v2 --org "$PROJECT" --token "$TOKEN" --disable-check | jq .'[0].credentials[]| select(.apiProducts[0].apiproduct=="ai-product-silver-v2").consumerKey' -r)
echo " "
echo "All the Apigee artifacts are successfully deployed!"
echo "You can now go back to the Colab notebook to test the sample. You will need the following Keys and variables during your test."
echo "Your BRONZE API Key is: $BRONZE_KEY"
echo "Your SILVER API Key is: $SILVER_KEY"
echo " "
echo "Your PROJECT_ID is: $PROJECT"
echo "Your LOCATION is: $REGION"
echo "Your API_ENDPOINT is: https://$APIGEE_HOST/v2/samples/llm-token-limits"