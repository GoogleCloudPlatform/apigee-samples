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

echo "Installing apigeecli"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

TOKEN=$(gcloud auth print-access-token)
gcloud config set project $PROJECT

PRE_PROP="region=$REGION"

echo "$PRE_PROP" > ./apiproxy/resources/properties/vertex_config.properties

echo "Deploying Apigee artifacts..."

echo "Creating Data collectors..."

apigeecli datacollectors create -d "Candidates token count" -n dc_candidates_token_count -p INTEGER --org "$PROJECT" --token "$TOKEN"
apigeecli datacollectors create -d "Prompt token count" -n dc_prompt_token_count -p INTEGER --org "$PROJECT" --token "$TOKEN"
apigeecli datacollectors create -d "Total token count" -n dc_total_token_count -p INTEGER --org "$PROJECT" --token "$TOKEN"

echo "Creating Token Consumption Report...."

curl --request POST \
  "https://apigee.googleapis.com/v1/organizations/$PROJECT/reports" \
  --header "Authorization: Bearer $TOKEN" \
  --header 'Accept: application/json' \
  --header 'Content-Type: application/json' \
  --data '{"name":"tokens-consumption-report","displayName":"Tokens Consumption Report","metrics":[{"name":"dc_prompt_token_count","function":"sum"},{"name":"dc_candidates_token_count","function":"sum"},{"name":"dc_total_token_count","function":"sum"}],"dimensions":["api_product","developer_app"],"properties":[{"value":[{}]}],"chartType":"line"}' \
  --compressed

echo "Importing and Deploying Apigee llm-token-limits-v1 proxy..."
REV=$(apigeecli apis create bundle -f ./apiproxy -n llm-token-limits-v1 --org "$PROJECT" --token "$TOKEN" --disable-check | jq ."revision" -r)
apigeecli apis deploy --wait --name llm-token-limits-v1 --ovr --rev "$REV" --org "$PROJECT" --env "$APIGEE_ENV" --token "$TOKEN"

echo "Creating AI Products"
apigeecli products create --name ai-product-bronze --display-name "AI Product Bronze" --envs "$APIGEE_ENV" --scopes "READ" --scopes "WRITE" --scopes "ACTION" --approval auto --quota 50 --interval 1 --unit minute --opgrp ./aiproduct-bronze.json --org "$PROJECT" --token "$TOKEN"
apigeecli products create --name ai-product-silver --display-name "AI Product Silver" --envs "$APIGEE_ENV" --scopes "READ" --scopes "WRITE" --scopes "ACTION" --approval auto --quota 50 --interval 1 --unit minute --opgrp ./aiproduct-silver.json --org "$PROJECT" --token "$TOKEN"

echo "Creating Developer"
apigeecli developers create --user testuser --email aidev@cymbal.com --first Test --last User --org "$PROJECT" --token "$TOKEN"

echo "Creating Developer App"
apigeecli apps create --name ai-consumer-app --email aidev@cymbal.com --prods ai-product-bronze --callback https://developers.google.com/oauthplayground/ --org "$PROJECT" --token "$TOKEN" --disable-check
apigeecli apps genkey --name ai-consumer-app -d aidev@cymbal.com  --prods ai-product-silver --org "$PROJECT" --token "$TOKEN" --disable-check
BRONZE_KEY=$(apigeecli apps get --name ai-consumer-app --org "$PROJECT" --token "$TOKEN" --disable-check | jq .'[0].credentials[]| select(.apiProducts[0].apiproduct=="ai-product-bronze").consumerKey' -r)
SILVER_KEY=$(apigeecli apps get --name ai-consumer-app --org "$PROJECT" --token "$TOKEN" --disable-check | jq .'[0].credentials[]| select(.apiProducts[0].apiproduct=="ai-product-silver").consumerKey' -r)
echo " "
echo "All the Apigee artifacts are successfully deployed!"
echo "You can now go back to the Colab noteboo kto test the sample. You will need the following Keys during your test."
echo "Your BRONZE API Key is: $BRONZE_KEY"
echo "Your SILVER API Key is: $SILVER_KEY"