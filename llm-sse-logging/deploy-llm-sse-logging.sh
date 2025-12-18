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

if [ -z "$PROJECT_ID" ]; then
  echo "No PROJECT_ID variable set"
  exit
fi

if [ -z "$REGION" ]; then
  echo "No REGION variable set"
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

add_role_to_service_account() {
  local role=$1
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="$role"
}

gcloud services enable logging.googleapis.com --project="$PROJECT_ID"

TOKEN=$(gcloud auth print-access-token)

echo "Creating Service Account and assigning permissions"
gcloud iam service-accounts create "$SERVICE_ACCOUNT_NAME" --project "$PROJECT_ID"

add_role_to_service_account "roles/apigee.analyticsEditor"
add_role_to_service_account "roles/logging.logWriter"
add_role_to_service_account "roles/aiplatform.user"
add_role_to_service_account "roles/iam.serviceAccountUser"

gcloud services enable aiplatform.googleapis.com --project "$PROJECT_ID"

echo "Installing apigeecli"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

echo "Deploying the Proxy"
apigeecli apis create bundle -n llm-sse-logging \
  -f apiproxy -e "$APIGEE_ENV" \
  --token "$TOKEN" -o "$PROJECT_ID" \
  -s "${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --ovr --wait

export PROXY_URL="$APIGEE_HOST/v1/samples/llm-sse-logging"

echo " "
echo "All the Apigee artifacts are successfully deployed!"
echo " "
echo "Your Proxy URL is: https://$PROXY_URL"
echo " "
echo "Run the following commands to test the API"
echo " "
echo "curl --location \"https://$APIGEE_HOST/v1/samples/llm-sse-logging/v1/projects/$PROJECT_ID/locations/$REGION/publishers/google/models/gemini-2.5-flash:streamGenerateContent?alt=sse\" \
--header \"Content-Type: application/json\" \
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
echo "You can now go back to the Colab notebook to test the sample. You will need the following variables during your test."
echo "Your PROJECT_ID is: $PROJECT_ID"
echo "Your LOCATION is: $REGION"
echo "Your API_ENDPOINT is: https://$APIGEE_HOST/v1/samples/llm-sse-logging"