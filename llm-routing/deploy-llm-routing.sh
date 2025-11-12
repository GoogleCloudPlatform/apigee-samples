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

if [ -z "$VERTEXAI_REGION" ]; then
  echo "No VERTEXAI_REGION variable set"
  exit
fi

if [ -z "$VERTEXAI_PROJECT_ID" ]; then
  echo "No VERTEXAI_PROJECT_ID variable set"
  exit
fi

if [ -z "$HUGGINGFACE_TOKEN" ]; then
  echo "No HUGGINGFACE_TOKEN variable set"
  exit
fi

if [ -z "$MISTRAL_TOKEN" ]; then
  echo "No MISTRAL_TOKEN variable set"
  exit
fi

if [ -z "$TOKEN" ]; then
  TOKEN=$(gcloud auth print-access-token)
fi

add_role_to_service_account() {
  local role=$1
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="$role"
}

# Determine sed in-place arguments for portability (macOS vs Linux)
sedi_args=("-i")
if [[ "$(uname)" == "Darwin" ]]; then
  sedi_args=("-i" "") # For macOS, sed -i requires an extension argument. "" means no backup.
fi

echo "Creating Service Account and assigning permissions"
gcloud iam service-accounts create "$SERVICE_ACCOUNT_NAME" --project "$PROJECT_ID"

add_role_to_service_account "roles/apigee.analyticsEditor"
add_role_to_service_account "roles/logging.logWriter"
add_role_to_service_account "roles/aiplatform.user"
add_role_to_service_account "roles/iam.serviceAccountUser"

gcloud services enable aiplatform.googleapis.com --project "$PROJECT_ID"

echo "Updating KVM configurations"
cp config/env__envname__llm-routing-v1-modelprovider-config__kvmfile__0.json config/env__"${APIGEE_ENV}"__llm-routing-v1-modelprovider-config__kvmfile__0.json
sed "${sedi_args[@]}" "s/MISTRAL_TOKEN/$MISTRAL_TOKEN/g" config/env__"${APIGEE_ENV}"__llm-routing-v1-modelprovider-config__kvmfile__0.json
sed "${sedi_args[@]}" "s/HUGGINGFACE_TOKEN/$HUGGINGFACE_TOKEN/g" config/env__"${APIGEE_ENV}"__llm-routing-v1-modelprovider-config__kvmfile__0.json
sed "${sedi_args[@]}" "s/VERTEXAI_REGION/$VERTEXAI_REGION/g" config/env__"${APIGEE_ENV}"__llm-routing-v1-modelprovider-config__kvmfile__0.json
sed "${sedi_args[@]}" "s/VERTEXAI_PROJECT_ID/$VERTEXAI_PROJECT_ID/g" config/env__"${APIGEE_ENV}"__llm-routing-v1-modelprovider-config__kvmfile__0.json


echo "Installing apigeecli"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

echo "Importing KVMs to Apigee environment"
apigeecli kvms import -f config/env__"${APIGEE_ENV}"__llm-routing-v1-modelprovider-config__kvmfile__0.json --org "$PROJECT_ID" --token "$TOKEN"
rm config/env__"${APIGEE_ENV}"__llm-routing-v1-modelprovider-config__kvmfile__0.json

echo "Deploying the Proxy"
sed "${sedi_args[@]}" "s/HOST/$APIGEE_HOST/g" apiproxy/resources/oas/spec.yaml

apigeecli apis create bundle -n llm-routing-v1 \
  -f apiproxy -e "$APIGEE_ENV" \
  --token "$TOKEN" -o "$PROJECT_ID" \
  -s "${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --ovr --wait

sed "${sedi_args[@]}" "s/$APIGEE_HOST/HOST/g" apiproxy/resources/oas/spec.yaml

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

APIKEY=$(apigeecli apps get --name "llm-routing-app" --org "$PROJECT_ID" --token "$TOKEN" --disable-check | jq ."[0].credentials[0].consumerKey" -r)

export APIKEY
export PROXY_URL="$APIGEE_HOST/v1/samples/llm-routing"

echo " "
echo "All the Apigee artifacts are successfully deployed!"
echo " "
echo "Your Proxy URL is: https://$PROXY_URL"
echo "Your API Key is: $APIKEY"
echo " "
echo "Run the following commands to test the API"
echo " "
echo "Gemini: "
echo " "
echo "curl --location \"https://$APIGEE_HOST/v1/samples/llm-routing/chat/completions\" \
--header \"Content-Type: application/json\" \
--header \"x-llm-provider: google\" \
--header \"x-logpayload: false\" \
--header \"x-apikey: $APIKEY\" \
--data '{
  \"model\": \"google/gemini-2.0-flash\",
  \"messages\": [
    {
      \"role\": \"user\",
      \"content\": [
        {
          \"type\": \"image_url\",
          \"image_url\": {
            \"url\": \"gs://generativeai-downloads/images/character.jpg\"
          }
        },
        {
          \"type\": \"text\",
          \"text\": \"Describe this image in one sentence.\"
        }
      ]
    }
  ],
  \"max_tokens\": 250,
  \"stream\": false
}'"
echo " "
echo "Mistral: "
echo " "
echo "curl --location \"https://$APIGEE_HOST/v1/samples/llm-routing/chat/completions\" \
--header \"Content-Type: application/json\" \
--header \"x-llm-provider: mistral\" \
--header \"x-logpayload: false\" \
--header \"x-apikey: $APIKEY\" \
--data '{
  \"model\": \"open-mistral-nemo\",
  \"messages\": [
    {
      \"role\": \"user\",
      \"content\": [
        {
          \"type\": \"text\",
          \"text\": \"Suggest few names for a flower shop\"
        }
      ]
    }
  ],
  \"max_tokens\": 250,
  \"stream\": false
}'"
echo " "
echo "HuggingFace: "
echo " "
echo "curl --location \"https://$APIGEE_HOST/v1/samples/llm-routing/chat/completions\" \
--header \"Content-Type: application/json\" \
--header \"x-llm-provider: huggingface\" \
--header \"x-logpayload: false\" \
--header \"x-apikey: $APIKEY\" \
--data '{
  \"model\": \"Meta-Llama-3.1-8B-Instruct\",
  \"messages\": [
    {
      \"role\": \"user\",
      \"content\": [
        {
          \"type\": \"text\",
          \"text\": \"Suggest few names for a flower shop\"
        }
      ]
    }
  ],
  \"max_tokens\": 250,
  \"stream\": false
}'"
echo " "
echo "Export these variables"
echo "export APIKEY=$APIKEY"
echo " "
echo "You can now go back to the Colab notebook to test the sample. You will need the following variables during your test."
echo "Your PROJECT_ID is: $PROJECT_ID"
echo "Your APIGEE_HOST is: $APIGEE_HOST"
echo "Your APIKEY is: $APIKEY"