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

set -e

if [ -z "$PROJECT_ID" ]; then
  echo "No PROJECT_ID variable set"
  exit 1
fi

if [ -z "$APIGEE_ENV" ]; then
  echo "No APIGEE_ENV variable set"
  exit 1
fi

if [ -z "$APIGEE_HOST" ]; then
  echo "No APIGEE_HOST variable set"
  exit 1
fi

if [ -z "$SERVICE_ACCOUNT_NAME" ]; then
  echo "No SERVICE_ACCOUNT_NAME variable set"
  exit 1
fi

if [ -z "$APIGEE_APIHUB_PROJECT_ID" ]; then
  echo "No APIGEE_APIHUB_PROJECT_ID variable set"
  exit 1
fi

if [ -z "$APIGEE_APIHUB_REGION" ]; then
  echo "No APIGEE_APIHUB_REGION variable set"
  exit 1
fi

if [ -z "$VERTEXAI_REGION" ]; then
  echo "No VERTEXAI_REGION variable set"
  exit 1
fi

if [ -z "$VERTEXAI_PROJECT_ID" ]; then
  echo "No VERTEXAI_PROJECT_ID variable set"
  exit 1
fi

if [ -z "$MODEL_ARMOR_REGION" ]; then
  echo "No MODEL_ARMOR_REGION variable set"
  exit 1
fi

if [ -z "$MODEL_ARMOR_TEMPLATE_ID" ]; then
  echo "No MODEL_ARMOR_TEMPLATE_ID variable set"
  exit 1
fi

if [ -z "$TOKEN" ]; then
  TOKEN=$(gcloud auth print-access-token)
fi

add_role_to_serviceaccount(){
  local role=$1
  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="${role}"
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

import_and_deploy_proxy() {
  local proxy=$1
  echo "Deploying Proxy: $proxy"
  apigeecli apis create bundle -n "$proxy" \
  -f "proxies/${proxy}/apiproxy" \
  -e "$APIGEE_ENV" --token "$TOKEN" -o "$PROJECT_ID" \
  -s "${SERVICE_ACCOUNT_NAME}"@"${PROJECT_ID}".iam.gserviceaccount.com \
  --ovr --wait
}

add_rest_api_to_hub(){
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

add_soap_api_to_hub(){
  local api=$1
  local id="1_0_0"
  echo "Registering the $api API"
  apigeecli apihub apis create --id "${api}_api" \
  -f "tmp/${api}/${api}-api.json" \
  -r "$APIGEE_APIHUB_REGION" -o "$APIGEE_APIHUB_PROJECT_ID" -t "$TOKEN"

  apigeecli apihub apis versions create --api-id "${api}_api" --id $id \
  -f "tmp/${api}/${api}-api-ver.json"  -r "$APIGEE_APIHUB_REGION" -o "$APIGEE_APIHUB_PROJECT_ID" -t "$TOKEN"

  apigeecli apihub apis versions specs create --api-id "${api}_api" -i $id --version $id \
  -d ${api}.wsdl -f "tmp/${api}/${api}.wsdl"  -r "$APIGEE_APIHUB_REGION" -o "$APIGEE_APIHUB_PROJECT_ID" -t "$TOKEN"
}

add_grpc_api_to_hub(){
  local api=$1
  local id="1_0_0"
  echo "Registering the $api API"
  apigeecli apihub apis create --id "${api}_api" \
  -f "tmp/${api}/${api}-api.json" \
  -r "$APIGEE_APIHUB_REGION" -o "$APIGEE_APIHUB_PROJECT_ID" -t "$TOKEN"

  apigeecli apihub apis versions create --api-id "${api}_api" --id $id \
  -f "tmp/${api}/${api}-api-ver.json"  -r "$APIGEE_APIHUB_REGION" -o "$APIGEE_APIHUB_PROJECT_ID" -t "$TOKEN"

  apigeecli apihub apis versions specs create --api-id "${api}_api" -i $id --version $id \
  -d ${api}.proto -f "tmp/${api}/${api}.proto"  -r "$APIGEE_APIHUB_REGION" -o "$APIGEE_APIHUB_PROJECT_ID" -t "$TOKEN"
}

add_mcp_api_to_hub(){
  local api=$1
  local id="1_0_0"
  echo "Registering the $api API"
  apigeecli apihub apis create --id "${api}_api" \
  -f "tmp/${api}/${api}-api.json" \
  -r "$APIGEE_APIHUB_REGION" -o "$APIGEE_APIHUB_PROJECT_ID" -t "$TOKEN"
}

_sleep() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") Sleeping for $1 seconds ..."
  sleep "$1"
  echo "$(date +"%Y-%m-%d %H:%M:%S") Sleep done ..."
}

echo "================================================="
echo "Started deploy-adk-cymbal-retail-agent.sh"
echo "================================================="

PRE_PROP="project_id=$VERTEXAI_PROJECT_ID
model_id=$MODEL_NAME
region=$VERTEXAI_REGION"

echo "$PRE_PROP" > ./proxies/cymbal-customers-v1/apiproxy/resources/properties/vertex_config.properties
echo "$PRE_PROP" > ./proxies/cymbal-orders-v1/apiproxy/resources/properties/vertex_config.properties
echo "$PRE_PROP" > ./proxies/cymbal-returns-v1/apiproxy/resources/properties/vertex_config.properties

gcloud services enable dlp.googleapis.com logging.googleapis.com aiplatform.googleapis.com modelarmor.googleapis.com --project "$PROJECT_ID"

echo "Installing apigeecli"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

echo "✅ Installing apigee-go-gen tool ..."
curl -s https://apigee.github.io/apigee-go-gen/install | bash -s v1.1.0-beta.9 ~/.apigee-go-gen/bin
export PATH=$PATH:$HOME/.apigee-go-gen/bin

echo "Installing dependencies..."
#npm install

echo "Registering APIs in Apigee API hub"
cp -rf config tmp/
sed -i "s/APIGEE_HOST/$APIGEE_HOST/g" tmp/*/*.yaml
sed -i "s/APIGEE_APIHUB_PROJECT_ID/$APIGEE_APIHUB_PROJECT_ID/g" tmp/*/*.json
sed -i "s/APIGEE_APIHUB_REGION/$APIGEE_APIHUB_REGION/g" tmp/*/*.json

apigeecli apihub attributes update -r "$APIGEE_APIHUB_REGION" -o "$APIGEE_APIHUB_PROJECT_ID" -t "$TOKEN" --allowed-values  "config/business-units.json" --data-type "ENUM" -i "system-business-unit" -s "API" -m "allowed_values" -d "Business Unit"
apigeecli apihub attributes update -r "$APIGEE_APIHUB_REGION" -o "$APIGEE_APIHUB_PROJECT_ID" -t "$TOKEN" --allowed-values  "config/teams.json" --data-type "ENUM" -i "system-team" -s "API" -m "allowed_values" -d "Team"

add_grpc_api_to_hub "shipments"
add_mcp_api_to_hub "customers-mcp"
add_soap_api_to_hub "payments"
add_rest_api_to_hub "accounts"
add_rest_api_to_hub "communications"
add_rest_api_to_hub "customers"
add_rest_api_to_hub "employees"
add_rest_api_to_hub "orders"
add_rest_api_to_hub "products"
add_rest_api_to_hub "returns"
add_rest_api_to_hub "stocks"

apigee-go-gen render apiproxy \
  --template ./config/templates/mcp/apiproxy.yaml \
  --set-oas spec=./tmp/customers/customers.yaml \
  --include ./config/templates/mcp/*.tmpl \
  --output ./proxies/mcp-cymbal-customers-v1

rm -rf tmp

echo "Creating Service Account and assigning permissions"
gcloud iam service-accounts create "$SERVICE_ACCOUNT_NAME" --project "$PROJECT_ID"
_sleep 10

add_role_to_serviceaccount "roles/logging.logWriter"
add_role_to_serviceaccount "roles/aiplatform.user"
add_role_to_serviceaccount "roles/modelarmor.admin"
add_role_to_serviceaccount "roles/iam.serviceAccountUser"
add_role_to_serviceaccount "roles/dlp.reader"
add_role_to_serviceaccount "roles/dlp.user"
add_role_to_serviceaccount "roles/apigee.analyticsEditor"
add_role_to_serviceaccount "roles/integrations.integrationEditor"

gcloud config set api_endpoint_overrides/modelarmor "https://modelarmor.$MODEL_ARMOR_REGION.rep.googleapis.com/"

gcloud model-armor templates create "$MODEL_ARMOR_TEMPLATE_ID" -q --location "$MODEL_ARMOR_REGION" --project="$PROJECT_ID" \
  --rai-settings-filters='[{ "filterType": "HATE_SPEECH", "confidenceLevel": "MEDIUM_AND_ABOVE" },{ "filterType": "HARASSMENT", "confidenceLevel": "MEDIUM_AND_ABOVE" },{ "filterType": "SEXUALLY_EXPLICIT", "confidenceLevel": "MEDIUM_AND_ABOVE" }]' \
  --basic-config-filter-enforcement=enabled \
  --pi-and-jailbreak-filter-settings-enforcement=enabled \
  --pi-and-jailbreak-filter-settings-confidence-level=LOW_AND_ABOVE \
  --malicious-uri-filter-settings-enforcement=enabled

curl --location "https://dlp.googleapis.com/v2/projects/$PROJECT_ID/deidentifyTemplates" \
--header "X-Goog-User-Project: $PROJECT_NUMBER" \
--header "Content-Type: application/json" \
--header "Authorization: Bearer $TOKEN" \
--data "{
   \"templateId\": \"Basic_PII\",
   \"deidentifyTemplate\":{
      \"name\":\"Basic_PII\",
      \"displayName\":\"Basic_PII\",
      \"description\": \"Basic_PII\",
      \"deidentifyConfig\":{
         \"infoTypeTransformations\":{
            \"transformations\":[
               {
                  \"primitiveTransformation\":{
                     \"characterMaskConfig\":{
                        \"maskingCharacter\":\"#\"
                     }
                  }
               }
            ]
         },
         \"transformationErrorHandling\":{
            \"throwError\":{}
         }
      }
   }
}" 

echo "Creating Data collectors..."

apigeecli datacollectors create -d "Collects PII or Jailbreak attack matches" -n dc_ma_pi_jailbreak -p INTEGER --org "$PROJECT_ID" --token "$TOKEN"
apigeecli datacollectors create -d "Collects malicious URI matches" -n dc_ma_malicious_uri -p INTEGER --org "$PROJECT_ID" --token "$TOKEN"
apigeecli datacollectors create -d "Collects dangerous and Responsible AI matches" -n dc_ma_rai -p INTEGER --org "$PROJECT_ID" --token "$TOKEN"
apigeecli datacollectors create -d "Collects CSAM matches" -n dc_ma_csam -p INTEGER --org "$PROJECT_ID" --token "$TOKEN"
apigeecli datacollectors create -d "Candidates token count" -n dc_candidates_token_count -p INTEGER --org "$PROJECT_ID" --token "$TOKEN"
apigeecli datacollectors create -d "Prompt token count" -n dc_prompt_token_count -p INTEGER --org "$PROJECT_ID" --token "$TOKEN"
apigeecli datacollectors create -d "Total token count" -n dc_total_token_count -p INTEGER --org "$PROJECT_ID" --token "$TOKEN"

echo "Creating Token Consumption Report...."

curl --request POST \
  "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/reports" \
  --header "Authorization: Bearer $TOKEN" \
  --header 'Accept: application/json' \
  --header 'Content-Type: application/json' \
  --data '{"name":"tokens-consumption-report","displayName":"Tokens Consumption Report","metrics":[{"name":"dc_prompt_token_count","function":"sum"},{"name":"dc_candidates_token_count","function":"sum"},{"name":"dc_total_token_count","function":"sum"}],"dimensions":["api_product","developer_app"],"properties":[{"value":[{}]}],"chartType":"line"}' \
  --compressed

echo "Creating Responsible AI report...."

curl --request POST \
  "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/reports" \
  --header "Authorization: Bearer $TOKEN" \
  --header 'Accept: application/json' \
  --header 'Content-Type: application/json' \
  --data '{"name":"ai-responsible-report","displayName":"Responsible AI Report","metrics":[{"name":"dc_ma_pi_jailbreak","function":"sum"},{"name":"dc_ma_malicious_uri","function":"sum"},{"name":"dc_ma_csam","function":"sum"},{"name":"dc_ma_rai","function":"sum"}],"dimensions":["api_product","developer_app"],"properties":[{"value":[{}]}],"chartType":"line"}' \
  --compressed

echo "Deploying the sharedflows"
import_and_deploy_sharedflow "llm-extract-candidates-v1"
import_and_deploy_sharedflow "llm-extract-prompts-v1"
import_and_deploy_sharedflow "llm-logger-v1"
import_and_deploy_sharedflow "cloud-logger-v1"


echo "Deploying the proxies"
import_and_deploy_proxy "cymbal-customers-v1"
import_and_deploy_proxy "cymbal-orders-v1"
import_and_deploy_proxy "cymbal-returns-v1"
import_and_deploy_proxy "mcp-cymbal-customers-v1"
import_and_deploy_proxy "adk-retail-agent-llm-governance-v1"

rm -rf proxies/mcp-cymbal-customers-v1

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

echo "Crating Flow-Hook for cloud-logger-v1 sharedflow ..."
apigeecli flowhooks attach \
 --name "PostProxyFlowHook" \
 --sharedflow "cloud-logger-v1" \
 --env "$APIGEE_ENV" \
 --org "$PROJECT_ID" \
 --token "$TOKEN"

export APIKEY
export PROXY_URL="$APIGEE_HOST/v1/samples/adk-cymbal-retail"

# npm test

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
echo "Returns: "
echo " "
echo "curl --location \"https://$APIGEE_HOST/v1/samples/adk-cymbal-retail/returns\" \
--header \"Content-Type: application/json\" \
--header \"x-apikey: $APIKEY\""
echo " "
echo "Export these variables"
echo "export APIKEY=$APIKEY"
echo "export PROXY_URL=$PROXY_URL"
echo "export APIGEE_HOST=$APIGEE_HOST"
echo " "
echo "Your PROJECT_ID is: $PROJECT_ID"
echo "Your APIGEE_HOST is: $APIGEE_HOST"
echo "Your APIKEY is: $APIKEY"

echo "================================================="
echo "Finished deploy-adk-cymbal-retail-agent.sh"
echo "================================================="
