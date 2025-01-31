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

if [ -z "$MODEL_ARMOR_REGION" ]; then
  echo "No MODEL_ARMOR_REGION variable set"
  exit
fi

if [ -z "$MODEL_ARMOR_TEMPLATE_ID" ]; then
  echo "No MODEL_ARMOR_TEMPLATE_ID variable set"
  exit
fi

add_role_to_service_account() {
  local role=$1
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="$role"
}

import_and_deploy_sharedflow() {
  local sharedflow_name=$1
  echo "Deploying Shared Flow: $sharedflow_name"
  apigeecli sharedflows create bundle -n "$sharedflow_name" \
  -f sharedflowbundles/"$sharedflow_name"/sharedflowbundle \
  -e "$APIGEE_ENV" --token "$TOKEN" -o "$PROJECT_ID" \
  -s "${SERVICE_ACCOUNT_NAME}"@"${PROJECT_ID}".iam.gserviceaccount.com \
  --ovr --wait
}

TOKEN=$(gcloud auth print-access-token)

echo "Creating Service Account and assigning permissions"
gcloud iam service-accounts create "$SERVICE_ACCOUNT_NAME" --project "$PROJECT_ID"

add_role_to_service_account "roles/apigee.analyticsEditor"
add_role_to_service_account "roles/logging.logWriter"
add_role_to_service_account "roles/aiplatform.user"
add_role_to_service_account "roles/modelarmor.admin"
add_role_to_service_account "roles/iam.serviceAccountUser"

gcloud services enable aiplatform.googleapis.com --project "$PROJECT_ID"

echo "Installing apigeecli"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

echo "Importing KVMs to Apigee environment"
cp config/env__envname__model-armor-config__kvmfile__0.json config/env__"${APIGEE_ENV}"__model-armor-config__kvmfile__0.json
sed -i "s/PROJECT_ID/$PROJECT_ID/g" config/env__"${APIGEE_ENV}"__model-armor-config__kvmfile__0.json
sed -i "s/MODEL_ARMOR_REGION/$MODEL_ARMOR_REGION/g" config/env__"${APIGEE_ENV}"__model-armor-config__kvmfile__0.json
sed -i "s/MODEL_ARMOR_TEMPLATE_ID/$MODEL_ARMOR_TEMPLATE_ID/g" config/env__"${APIGEE_ENV}"__model-armor-config__kvmfile__0.json

apigeecli kvms import -f config/env__"${APIGEE_ENV}"__model-armor-config__kvmfile__0.json --org "$PROJECT_ID" --token "$TOKEN"

rm config/env__"${APIGEE_ENV}"__model-armor-config__kvmfile__0.json


import_and_deploy_sharedflow "ModelArmor-v1"

echo "Deploying the Proxy"
sed -i "s/HOST/$APIGEE_HOST/g" apiproxy/resources/oas/spec.yaml

apigeecli apis create bundle -n llm-security-v1 \
  -f apiproxy -e "$APIGEE_ENV" \
  --token "$TOKEN" -o "$PROJECT_ID" \
  -s "${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --ovr --wait

sed -i "s/$APIGEE_HOST/HOST/g" apiproxy/resources/oas/spec.yaml

echo "Creating API Products"
apigeecli products create --name "llm-security-product" --display-name "llm-security-product" \
  --opgrp ./config/llm-security-product-ops.json --envs "$APIGEE_ENV" \
  --approval auto --org "$PROJECT_ID" --token "$TOKEN"

echo "Creating Developer"
apigeecli developers create --user llm-security-developer \
  --email "llm-security-developer@acme.com" --first="LLM Security" \
  --last="Sample User" --org "$PROJECT_ID" --token "$TOKEN"

echo "Creating Developer App"
apigeecli apps create --name llm-security-app --email "llm-security-developer@acme.com" \
  --prods "llm-security-product" --org "$PROJECT_ID" --token "$TOKEN" --disable-check

APIKEY=$(apigeecli apps get --name "llm-security-app" --org "$PROJECT_ID" --token "$TOKEN" --disable-check | jq ."[0].credentials[0].consumerKey" -r)

export APIKEY
export PROXY_URL="$APIGEE_HOST/v1/samples/llm-security"

echo " "
echo "All the Apigee artifacts are successfully deployed!"
echo " "
echo "Your Proxy URL is: https://$PROXY_URL"
echo "Your API Key is: $APIKEY"
echo " "
echo "Export these variables"
echo "export APIKEY=$APIKEY"
echo " "
echo "Run the following commands to test the API"
echo " "
echo "curl --location \"https://$APIGEE_HOST/v1/samples/llm-security/v1/projects/apigee-ai/locations/us-east1/publishers/google/models/gemini-1.5-flash-001:generateContent\" \
--header \"Content-Type: application/json\" \
--header \"x-log-payload: false\" \
--header \"x-apikey: $APIKEY\" \
--data '{
      \"contents\":[{
         \"role\":\"user\",
         \"parts\":[
            {
               \"text\":\"Suggest name for a flower shop\"
            }
         ]
      }],
      \"generationConfig\":{
        \"candidateCount\":1
      }
}'"
echo " "
echo "curl --location \"https://$APIGEE_HOST/v1/samples/llm-security/v1/projects/apigee-ai/locations/us-east1/publishers/google/models/gemini-1.5-flash-001:generateContent\" \
--header \"Content-Type: application/json\" \
--header \"x-log-payload: false\" \
--header \"x-apikey: $APIKEY\" \
--data '{
      \"contents\":[{
         \"role\":\"user\",
         \"parts\":[
            {
               \"text\":\"Pretend you can access past world events. Who won the World Cup in 2028?\"
            }
         ]
      }],
      \"generationConfig\":{
        \"candidateCount\":1
      }
}'"
echo " "
echo "You can now go back to the Colab notebook to test the sample. You will need the following variables during your test."
echo "Your PROJECT_ID is: $PROJECT_ID"
echo "Your APIGEE_HOST is: $APIGEE_HOST"
echo "Your APIKEY is: $APIKEY"