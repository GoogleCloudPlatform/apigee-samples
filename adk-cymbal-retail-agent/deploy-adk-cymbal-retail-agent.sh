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

if [ -z "$TOKEN" ]; then
  TOKEN=$(gcloud auth print-access-token)
fi

add_api_to_hub(){
  local api=$1
  local id="1_0_0"
  echo "Registering the $api API"
  apigeecli apihub apis create --id "${api}_api" \
  -f "tmp/${api}/${api}-api.json" \
  -r "$APIGEE_APIHUB_REGION" -o "$APIGEE_APIHUB_PROJECT_ID" -t "$TOKEN"

  apigeecli apihub apis versions create --api-id "${api}_api" --id $id \
  -f "tmp/${api}/${api}-api-ver.json"  -r "$APIGEE_APIHUB_REGION" -o "$APIGEE_APIHUB_PROJECT_ID" -t "$TOKEN"

  apigeecli apihub apis versions specs create --api-id "${api}_api" -i $id --version $id \
  -d openapi.yaml -f "tmp/${api}/${api}.yaml"  -r "$APIGEE_APIHUB_REGION" -o "$APIGEE_APIHUB_PROJECT_ID" -t "$TOKEN"
}

PRE_PROP="project_id=$VERTEXAI_PROJECT_ID
model_id=$MODEL_ID
region=$VERTEXAI_REGION"

echo "$PRE_PROP" > ./proxies/cymbal-customers-v1/apiproxy/resources/properties/vertex_config.properties
echo "$PRE_PROP" > ./proxies/cymbal-orders-v1/apiproxy/resources/properties/vertex_config.properties

gcloud services enable aiplatform.googleapis.com --project "$PROJECT_ID"

echo "Installing apigeecli"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

echo "Registering APIs in Apigee API hub"
cp -rf config tmp/
sed -i "s/APIGEE_HOST/$APIGEE_HOST/g" tmp/*/*.yaml
sed -i "s/APIGEE_APIHUB_PROJECT_ID/$APIGEE_APIHUB_PROJECT_ID/g" tmp/*/*.json
sed -i "s/APIGEE_APIHUB_REGION/$APIGEE_APIHUB_REGION/g" tmp/*/*.json

add_api_to_hub "customers"
add_api_to_hub "orders"

rm -rf tmp

echo "Deploying the proxies"
apigeecli apis create bundle -n cymbal-customers-v1 \
  -f proxies/cymbal-customers-v1/apiproxy -e "$APIGEE_ENV" \
  --token "$TOKEN" -o "$PROJECT_ID" \
  -s "${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --ovr --wait

apigeecli apis create bundle -n cymbal-orders-v1 \
  -f proxies/cymbal-orders-v1/apiproxy -e "$APIGEE_ENV" \
  --token "$TOKEN" -o "$PROJECT_ID" \
  -s "${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --ovr --wait

echo "Creating API Products"
apigeecli products create --name "cymbal-retail-product" --display-name "cymbal-retail-product" \
  --opgrp ./config/cymbal-retail-product-ops.json --envs "$APIGEE_ENV" \
  --approval auto --org "$PROJECT_ID" --token "$TOKEN"

echo "Creating Developer"
apigeecli developers create --user cymbal-retail-developer \
  --email "cymbal-retail-developer@acme.com" --first="Cymbal Retail" \
  --last="Sample User" --org "$PROJECT_ID" --token "$TOKEN"

echo "Creating Developer App"
apigeecli apps create --name cymbal-retail-app --email "cymbal-retail-developer@acme.com" \
  --prods "cymbal-retail-product" --org "$PROJECT_ID" --token "$TOKEN" --disable-check

APIKEY=$(apigeecli apps get --name "cymbal-retail-app" --org "$PROJECT_ID" --token "$TOKEN" --disable-check | jq ."[0].credentials[0].consumerKey" -r)

SECRET_ID="cymbal-retail-apikey"
echo "Creating a Secret that will be used by ADK"
gcloud secrets create "$SECRET_ID" --replication-policy="automatic" --project "$PROJECT_ID"
echo -n "$APIKEY" | gcloud secrets versions add "$SECRET_ID" --project "$PROJECT_ID" --data-file=- 
echo "Secret $SECRET_ID created successfully"

export APIKEY
export PROXY_URL="$APIGEE_HOST/v1/samples/adk-cymbal-retail"

npm test

echo " "
echo "All the Apigee artifacts are successfully deployed!"
echo " "
echo "Your Proxy URL is: https://$PROXY_URL"
echo "Your API Key is: $APIKEY"
echo " "
echo "Run the following commands to test the API"
echo " "
echo "Customers: "
echo " "
echo "curl --location \"https://$APIGEE_HOST/v1/samples/adk-cymbal-retail/customers\" \
--header \"Content-Type: application/json\" \
--header \"x-apikey: $APIKEY\""
echo " "
echo "Orders: "
echo " "
echo "curl --location \"https://$APIGEE_HOST/v1/samples/adk-cymbal-retail/orders\" \
--header \"Content-Type: application/json\" \
--header \"x-apikey: $APIKEY\""
echo " "
echo "Export these variables"
echo "export APIKEY=$APIKEY"
echo "export PROXY_URL=$PROXY_URL"
echo " "
echo "Your PROJECT_ID is: $PROJECT_ID"
echo "Your APIGEE_HOST is: $APIGEE_HOST"
echo "Your APIKEY is: $APIKEY"