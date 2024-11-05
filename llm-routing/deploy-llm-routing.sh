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

if [ -z "$SERVICE_ACCOUNT_NAME" ]; then
  echo "No SERVICE_ACCOUNT_NAME variable set"
  exit
fi

if [ -z "$VERTEX_AI_REGION" ]; then
  echo "No VERTEX_AI_REGION variable set"
  exit
fi

if [ -z "$VERTEX_AI_PROJECT_ID" ]; then
  echo "No VERTEX_AI_PROJECT_ID variable set"
  exit
fi

if [ -z "$ANTHROPIC_AI_REGION" ]; then
  echo "No ANTHROPIC_AI_REGION variable set"
  exit
fi

if [ -z "$ANTHROPIC_PROJECT_ID" ]; then
  echo "No ANTHROPIC_PROJECT_ID variable set"
  exit
fi

add_role_to_service_account() {
  local role=$1
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="$role"
}

TOKEN=$(gcloud auth print-access-token)

echo "Creating Service Account and assigning permissions"
gcloud iam service-accounts create "$SERVICE_ACCOUNT_NAME" --project "$PROJECT_ID"

add_role_to_service_account "roles/apigee.analyticsEditor"
add_role_to_service_account "roles/logging.logWriter"
add_role_to_service_account "roles/aiplatform.user"
add_role_to_service_account "roles/iam.serviceAccountUser"

gcloud services enable aiplatform.googleapis.com --project "$PROJECT_ID"

echo "Updating KVM configurations"

cp config/env__envname__llm-routing-config__kvmfile__0.json config/env__"${APIGEE_ENV}"__llm-routing-config__kvmfile__0.json
sed -i "s/VERTEX_AI_REGION/$VERTEX_AI_REGION/g" config/env__"${APIGEE_ENV}"__llm-routing-config__kvmfile__0.json
sed -i "s/VERTEX_AI_PROJECT_ID/$VERTEX_AI_PROJECT_ID/g" config/env__"${APIGEE_ENV}"__llm-routing-config__kvmfile__0.json
sed -i "s/ANTHROPIC_PROJECT_ID/$ANTHROPIC_PROJECT_ID/g" config/env__"${APIGEE_ENV}"__llm-routing-config__kvmfile__0.json
sed -i "s/ANTHROPIC_AI_REGION/$ANTHROPIC_AI_REGION/g" config/env__"${APIGEE_ENV}"__llm-routing-config__kvmfile__0.json


echo "Installing apigeecli"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

echo "Importing KVMs to Apigee environment"
apigeecli kvms import -f config/env__"${APIGEE_ENV}"__llm-routing-config__kvmfile__0.json --org "$PROJECT_ID" --token "$TOKEN"
rm config/env__"${APIGEE_ENV}"__llm-routing-config__kvmfile__0.json

echo "Deploying the Proxy"
sed -i "s/HOST/$APIGEE_HOST/g" apiproxy/resources/oas/spec.yaml

apigeecli apis create bundle -n llm-routing \
  -f apiproxy -e "$APIGEE_ENV" \
  --token "$TOKEN" -o "$PROJECT_ID" \
  -s "${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --ovr --wait

sed -i "s/$APIGEE_HOST/HOST/g" apiproxy/resources/oas/spec.yaml

echo "Creating API Products"
apigeecli products create --name "llm-routing-product" --display-name "llm-routing-product" \
  --opgrp ./config/llm-routing-product-ops.json --envs "$APIGEE_ENV" \
  --approval auto --org "$PROJECT_ID" --token "$TOKEN"

echo "Creating Developer"
apigeecli developers create --user llm-routing-developer \
  --email "llm-routing-developer@acme.com" --first="LLM Routing" \
  --last="Sample User" --org "$PROJECT_ID" --token "$TOKEN"

echo "Creating Developer App"
apigeecli apps create --name llm-routing-app --email "llm-routing-developer@acme.com" \
  --prods "llm-routing-product" --org "$PROJECT_ID" --token "$TOKEN" --disable-check

APP_CLIENT_ID=$(apigeecli apps get --name "llm-routing-app" --org "$PROJECT_ID" --token "$TOKEN" --disable-check | jq ."[0].credentials[0].consumerKey" -r)

export APP_CLIENT_ID
export PROXY_URL="$APIGEE_HOST/v1/samples/llm-routing"

echo " "
echo "All the Apigee artifacts are successfully deployed!"
echo " "
echo "Your Proxy URL is: https://$PROXY_URL"
echo "Your API Key is: $APP_CLIENT_ID"
echo " "
echo "Export these variables"
echo "export APP_CLIENT_ID=$APP_CLIENT_ID"
echo " "
echo "Run the following commands to test the API"
echo " "
echo "curl --location \"https://$APIGEE_HOST/v1/samples/llm-routing/providers/google/models/gemini-1.5-flash-001:generateText\" \
--header \"Content-Type: application/json\" \
--header \"x-log-payload: false\" \
--header \"x-apikey: $APP_CLIENT_ID\" \
--data '{
      \"contents\":{
         \"role\":\"user\",
         \"parts\":[
            {
               \"text\":\"Suggest name for a flower shop\"
            }
         ]
      }
}'"
echo " "
echo "curl --location \"https://$APIGEE_HOST/v1/samples/llm-routing/providers/anthropic/models/claude-3-5-sonnet-v2@20241022:generateText\" \
--header \"Content-Type: application/json\" \
--header \"x-log-payload: false\" \
--header \"x-apikey: $APP_CLIENT_ID\" \
--data '{
    \"anthropic_version\": \"vertex-2023-10-16\",
    \"messages\": [
        {
            \"role\": \"user\",
            \"content\": [
                {
                    \"type\": \"text\",
                    \"text\": \"Suggest name for a flower shop\"
                }
            ]
        }
    ],
    \"max_tokens\": 256,
    \"stream\": false
}'"
echo " "
echo "You can now go back to the Colab notebook to test the sample. You will need the following Keys during your test."
echo "Your PROJECT_ID is: $PROJECT_ID"
echo "Your APIGEE_HOST is: $APIGEE_HOST"
echo "Your APIKEY is: $APP_CLIENT_ID"