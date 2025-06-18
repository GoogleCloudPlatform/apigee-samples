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

if [ -z "$APIGEE_PROJECT" ]; then
  echo "No APIGEE_PROJECT variable set"
  exit
fi

if [ -z "$PROJECT_P1" ]; then
  echo "No PROJECT_P1 variable set"
  exit
fi

if [ -z "$REGION_P1" ]; then
  echo "No REGION_P1 variable set"
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

gcloud config set project "$APIGEE_PROJECT"

PRE_PROP="project_p1=$PROJECT_P1
region_p1=$REGION_P1"

echo "$PRE_PROP" >./apiproxy/resources/properties/vertex_config.properties

echo "Deploying Apigee artifacts..."

echo "Importing and Deploying Apigee llm-logger-v1 sharedflow..."
REV_SF=$(apigeecli sharedflows create bundle -f ./llm-logger-v1/sharedflowbundle -n llm-logger-v1 --org "$APIGEE_PROJECT" --token "$TOKEN" --disable-check | jq ."revision" -r)
apigeecli sharedflows deploy --name llm-logger-v1 --ovr --rev "$REV_SF" --org "$APIGEE_PROJECT" --env "$APIGEE_ENV" --token "$TOKEN" --sa "ai-logger@$APIGEE_PROJECT.iam.gserviceaccount.com"

echo "Importing and Deploying Apigee llm-extract-prompts-v1 sharedflow..."
REV_SF=$(apigeecli sharedflows create bundle -f ./llm-extract-prompts-v1/sharedflowbundle -n llm-extract-prompts-v1 --org "$APIGEE_PROJECT" --token "$TOKEN" --disable-check | jq ."revision" -r)
apigeecli sharedflows deploy --name llm-extract-prompts-v1 --ovr --rev "$REV_SF" --org "$APIGEE_PROJECT" --env "$APIGEE_ENV" --token "$TOKEN"

echo "Importing and Deploying Apigee llm-extract-candidates-v1 sharedflow..."
REV_SF=$(apigeecli sharedflows create bundle -f ./llm-extract-candidates-v1/sharedflowbundle -n llm-extract-candidates-v1 --org "$APIGEE_PROJECT" --token "$TOKEN" --disable-check | jq ."revision" -r)
apigeecli sharedflows deploy --name llm-extract-candidates-v1 --ovr --rev "$REV_SF" --org "$APIGEE_PROJECT" --env "$APIGEE_ENV" --token "$TOKEN"

echo "Importing and Deploying Apigee llm-logging-v1 proxy..."
REV=$(apigeecli apis create bundle -f ./apiproxy -n llm-logging-v1 --org "$APIGEE_PROJECT" --token "$TOKEN" --disable-check | jq ."revision" -r)
apigeecli apis deploy --wait --name llm-logging-v1 --ovr --rev "$REV" --org "$APIGEE_PROJECT" --env "$APIGEE_ENV" --token "$TOKEN"

echo " "
echo "All the Apigee artifacts are successfully deployed!"
echo "You can now go back to the Colab notebook to test the sample. You will need the following variables during your test."
echo " "
echo "Your PROJECT_ID is: $PROJECT_P1"
echo "Your LOCATION is: $REGION_P1"
echo "Your API_ENDPOINT is: https://$APIGEE_HOST/v1/samples/llm-logging"
