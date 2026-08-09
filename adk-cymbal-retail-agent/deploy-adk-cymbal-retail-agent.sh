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

set -e

sed_i() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i "" "$@"
  else
    sed -i "$@"
  fi
}

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

if [ -z "$AGENT_GATEWAY_NAME" ]; then
  echo "No AGENT_GATEWAY_NAME variable set"
  exit 1
fi

if [ -z "$TOKEN" ]; then
  TOKEN=$(gcloud auth application-default print-access-token)
fi
export TOKEN

DEPLOY_DISCOVERY_PROXY="${DEPLOY_DISCOVERY_PROXY:-true}"
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --deploy-discovery-proxy) DEPLOY_DISCOVERY_PROXY="$2"; shift 2 ;;
    --deploy-discovery-proxy=*) DEPLOY_DISCOVERY_PROXY="${1#*=}"; shift ;;
    *) echo "Unknown parameter: $1"; exit 1 ;;
  esac
done
export DEPLOY_DISCOVERY_PROXY

add_role_to_serviceaccount(){
  local role=$1
  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="${role}"
}

is_proxy_deployed() {
  local proxy=$1
  local output
  if ! output=$(apigeecli apis listdeploy -n "$proxy" -o "$PROJECT_ID" -t "$TOKEN" 2>/dev/null); then
    return 1
  fi
  if echo "$output" | jq -e ".deployments[] | select(.environment==\"$APIGEE_ENV\")" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

is_sharedflow_deployed() {
  local sf=$1
  local output
  if ! output=$(apigeecli sharedflows listdeploy -n "$sf" -o "$PROJECT_ID" -t "$TOKEN" 2>/dev/null); then
    return 1
  fi
  if echo "$output" | jq -e ".deployments[] | select(.environment==\"$APIGEE_ENV\")" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

import_and_deploy_sharedflow() {
  local sharedflow_name=$1
  if is_sharedflow_deployed "$sharedflow_name"; then
    echo "Shared Flow $sharedflow_name is already deployed to $APIGEE_ENV. Skipping."
    return 0
  fi
  echo "Deploying Shared Flow: $sharedflow_name"
  apigeecli sharedflows create bundle -n "$sharedflow_name" \
  -f sharedflowbundles/"$sharedflow_name"/sharedflowbundle \
  -e "$APIGEE_ENV" --token "$TOKEN" -o "$PROJECT_ID" \
  -s "${SERVICE_ACCOUNT_NAME}"@"${PROJECT_ID}".iam.gserviceaccount.com \
  --ovr --wait
}

import_and_deploy_proxy() {
  local proxy=$1
  if is_proxy_deployed "$proxy"; then
    echo "Proxy $proxy is already deployed to $APIGEE_ENV. Skipping."
    return 0
  fi
  echo "Deploying Proxy: $proxy"
  rm -rf "tmp/${proxy}"
  mkdir -p "tmp/${proxy}"
  cp -rf "proxies/${proxy}/apiproxy" "tmp/${proxy}/"
  if [ -d "tmp/${proxy}/apiproxy/policies" ]; then
    sed_i "s/APIGEE_HOST/$APIGEE_HOST/g" tmp/${proxy}/apiproxy/policies/*.xml 2>/dev/null || true
  fi
  if [ -d "tmp/${proxy}/apiproxy/resources/oas" ]; then
    sed_i "s/APIGEE_HOST/$APIGEE_HOST/g" tmp/${proxy}/apiproxy/resources/oas/*.yaml 2>/dev/null || true
  fi
  if [ -d "tmp/${proxy}/apiproxy/resources/properties" ]; then
    echo "$PRE_PROP" > "tmp/${proxy}/apiproxy/resources/properties/vertex_config.properties" 2>/dev/null || true
  fi
  if [ -d "tmp/${proxy}/apiproxy/targets" ]; then
    sed_i "s/apigee-ai.mcp.apigee.internal/mcp.apigee.internal/g" tmp/${proxy}/apiproxy/targets/*.xml 2>/dev/null || true
    sed_i "s/APIGEE_HOST/$APIGEE_HOST/g" tmp/${proxy}/apiproxy/targets/*.xml 2>/dev/null || true
  fi
  apigeecli apis create bundle -n "$proxy" \
  -f "tmp/${proxy}/apiproxy" \
  -e "$APIGEE_ENV" --token "$TOKEN" -o "$PROJECT_ID" \
  -s "${SERVICE_ACCOUNT_NAME}"@"${PROJECT_ID}".iam.gserviceaccount.com \
  --ovr --wait
  rm -rf "tmp/${proxy}"
}

add_rest_api_to_hub(){
  local api=$1
  local id="1_0_0"
  echo "Registering the $api API"
  ( apigeecli apihub apis create --id "${api}_api" \
  -f "tmp/${api}/${api}-api.json" \
  -r "$APIGEE_APIHUB_REGION" -o "$APIGEE_APIHUB_PROJECT_ID" -t "$TOKEN" ) || true

  ( apigeecli apihub apis versions create --api-id "${api}_api" --id $id \
  -f "tmp/${api}/${api}-api-ver.json"  -r "$APIGEE_APIHUB_REGION" -o "$APIGEE_APIHUB_PROJECT_ID" -t "$TOKEN" ) || true

  ( apigeecli apihub apis versions specs create --api-id "${api}_api" -i $id --version $id \
  -d openapi.yaml -f "tmp/${api}/${api}.yaml"  -r "$APIGEE_APIHUB_REGION" -o "$APIGEE_APIHUB_PROJECT_ID" -t "$TOKEN" ) || true
}

add_soap_api_to_hub(){
  local api=$1
  local id="1_0_0"
  echo "Registering the $api API"
  ( apigeecli apihub apis create --id "${api}_api" \
  -f "tmp/${api}/${api}-api.json" \
  -r "$APIGEE_APIHUB_REGION" -o "$APIGEE_APIHUB_PROJECT_ID" -t "$TOKEN" ) || true

  ( apigeecli apihub apis versions create --api-id "${api}_api" --id $id \
  -f "tmp/${api}/${api}-api-ver.json"  -r "$APIGEE_APIHUB_REGION" -o "$APIGEE_APIHUB_PROJECT_ID" -t "$TOKEN" ) || true

  ( apigeecli apihub apis versions specs create --api-id "${api}_api" -i $id --version $id \
  -d ${api}.wsdl -f "tmp/${api}/${api}.wsdl"  -r "$APIGEE_APIHUB_REGION" -o "$APIGEE_APIHUB_PROJECT_ID" -t "$TOKEN" ) || true
}

add_grpc_api_to_hub(){
  local api=$1
  local id="1_0_0"
  echo "Registering the $api API"
  ( apigeecli apihub apis create --id "${api}_api" \
  -f "tmp/${api}/${api}-api.json" \
  -r "$APIGEE_APIHUB_REGION" -o "$APIGEE_APIHUB_PROJECT_ID" -t "$TOKEN" ) || true

  ( apigeecli apihub apis versions create --api-id "${api}_api" --id $id \
  -f "tmp/${api}/${api}-api-ver.json"  -r "$APIGEE_APIHUB_REGION" -o "$APIGEE_APIHUB_PROJECT_ID" -t "$TOKEN" ) || true

  ( apigeecli apihub apis versions specs create --api-id "${api}_api" -i $id --version $id \
  -d ${api}.proto -f "tmp/${api}/${api}.proto"  -r "$APIGEE_APIHUB_REGION" -o "$APIGEE_APIHUB_PROJECT_ID" -t "$TOKEN" ) || true
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


gcloud services enable dlp.googleapis.com logging.googleapis.com aiplatform.googleapis.com modelarmor.googleapis.com dialogflow.googleapis.com discoveryengine.googleapis.com --project "$PROJECT_ID"

if ! command -v apigeecli &> /dev/null; then
  echo "Installing apigeecli"
  curl -s https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | bash
  export PATH=$PATH:$HOME/.apigeecli/bin
fi

echo "Installing dependencies..."
#npm install

echo "Registering APIs in Apigee API hub"
rm -rf tmp
mkdir -p tmp
cp -rf config/* tmp/
sed_i "s/APIGEE_HOST/$APIGEE_HOST/g" tmp/*/*.yaml
sed_i "s/APIGEE_APIHUB_PROJECT_ID/$APIGEE_APIHUB_PROJECT_ID/g" tmp/*/*.json
sed_i "s/APIGEE_APIHUB_REGION/$APIGEE_APIHUB_REGION/g" tmp/*/*.json

apigeecli apihub attributes update -r "$APIGEE_APIHUB_REGION" -o "$APIGEE_APIHUB_PROJECT_ID" -t "$TOKEN" --allowed-values  "config/business-units.json" --data-type "ENUM" -i "system-business-unit" -s "API" -m "allowed_values" -d "Business Unit"
apigeecli apihub attributes update -r "$APIGEE_APIHUB_REGION" -o "$APIGEE_APIHUB_PROJECT_ID" -t "$TOKEN" --allowed-values  "config/teams.json" --data-type "ENUM" -i "system-team" -s "API" -m "allowed_values" -d "Team"

add_grpc_api_to_hub "shipments"
add_soap_api_to_hub "payments"
add_rest_api_to_hub "accounts"
add_rest_api_to_hub "communications"
add_rest_api_to_hub "customers"
add_rest_api_to_hub "employees"
add_rest_api_to_hub "orders"
add_rest_api_to_hub "products"
add_rest_api_to_hub "returns"
add_rest_api_to_hub "stocks"
add_rest_api_to_hub "shipping"

rm -rf tmp

echo "Checking Service Account..."
if ! gcloud iam service-accounts describe "${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" --project "$PROJECT_ID" &>/dev/null; then
  echo "Creating Service Account..."
  gcloud iam service-accounts create "$SERVICE_ACCOUNT_NAME" --project "$PROJECT_ID"
  _sleep 10
else
  echo "Service Account ${SERVICE_ACCOUNT_NAME} already exists. Skipping creation."
fi

add_role_to_serviceaccount "roles/logging.logWriter"
add_role_to_serviceaccount "roles/aiplatform.user"
add_role_to_serviceaccount "roles/modelarmor.admin"
add_role_to_serviceaccount "roles/iam.serviceAccountUser"
add_role_to_serviceaccount "roles/dlp.reader"
add_role_to_serviceaccount "roles/dlp.user"
add_role_to_serviceaccount "roles/apigee.analyticsEditor"
add_role_to_serviceaccount "roles/secretmanager.secretAccessor"
add_role_to_serviceaccount "roles/apigee.apiReaderV2"

echo "Granting Apigee Service Agent permissions on custom Service Account"
gcloud iam service-accounts add-iam-policy-binding \
  "${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --member="serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-apigee.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser" \
  --project="${PROJECT_ID}" || true

gcloud iam service-accounts add-iam-policy-binding \
  "${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
  --member="serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-apigee.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountTokenCreator" \
  --project="${PROJECT_ID}" || true


gcloud config set api_endpoint_overrides/modelarmor "https://modelarmor.$MODEL_ARMOR_REGION.rep.googleapis.com/"

gcloud model-armor templates create "$MODEL_ARMOR_TEMPLATE_ID" -q --location "$MODEL_ARMOR_REGION" --project="$PROJECT_ID" \
  --rai-settings-filters='[{ "filterType": "HATE_SPEECH", "confidenceLevel": "MEDIUM_AND_ABOVE" },{ "filterType": "HARASSMENT", "confidenceLevel": "MEDIUM_AND_ABOVE" },{ "filterType": "SEXUALLY_EXPLICIT", "confidenceLevel": "MEDIUM_AND_ABOVE" }]' \
  --basic-config-filter-enforcement=enabled \
  --pi-and-jailbreak-filter-settings-enforcement=enabled \
  --pi-and-jailbreak-filter-settings-confidence-level=LOW_AND_ABOVE \
  --malicious-uri-filter-settings-enforcement=enabled || true

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
}" || true 

echo "Creating Data collectors..."

apigeecli datacollectors create -d "Collects PII or Jailbreak attack matches" -n dc_ma_pi_jailbreak -p INTEGER --org "$PROJECT_ID" --token "$TOKEN" || true
apigeecli datacollectors create -d "Collects malicious URI matches" -n dc_ma_malicious_uri -p INTEGER --org "$PROJECT_ID" --token "$TOKEN" || true
apigeecli datacollectors create -d "Collects dangerous and Responsible AI matches" -n dc_ma_rai -p INTEGER --org "$PROJECT_ID" --token "$TOKEN" || true
apigeecli datacollectors create -d "Collects CSAM matches" -n dc_ma_csam -p INTEGER --org "$PROJECT_ID" --token "$TOKEN" || true
apigeecli datacollectors create -d "Candidates token count" -n dc_candidates_token_count -p INTEGER --org "$PROJECT_ID" --token "$TOKEN" || true
apigeecli datacollectors create -d "Prompt token count" -n dc_prompt_token_count -p INTEGER --org "$PROJECT_ID" --token "$TOKEN" || true
apigeecli datacollectors create -d "Total token count" -n dc_total_token_count -p INTEGER --org "$PROJECT_ID" --token "$TOKEN" || true

REPORTS_JSON=$(curl -s "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/reports" \
  --header "Authorization: Bearer $TOKEN" \
  --header 'Accept: application/json')

if echo "$REPORTS_JSON" | jq -e '.qualifier[]? | select(.displayName == "Tokens Consumption Report")' >/dev/null; then
  echo "Tokens Consumption Report already exists. Skipping."
else
  echo "Creating Token Consumption Report...."
  curl -s --request POST \
    "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/reports" \
    --header "Authorization: Bearer $TOKEN" \
    --header 'Accept: application/json' \
    --header 'Content-Type: application/json' \
    --data '{"name":"tokens-consumption-report","displayName":"Tokens Consumption Report","metrics":[{"name":"dc_prompt_token_count","function":"sum"},{"name":"dc_candidates_token_count","function":"sum"},{"name":"dc_total_token_count","function":"sum"}],"dimensions":["api_product","developer_app"],"properties":[{"value":[{}]}],"chartType":"line"}' \
    --compressed || true
fi

if echo "$REPORTS_JSON" | jq -e '.qualifier[]? | select(.displayName == "Responsible AI Report")' >/dev/null; then
  echo "Responsible AI Report already exists. Skipping."
else
  echo "Creating Responsible AI report...."
  curl -s --request POST \
    "https://apigee.googleapis.com/v1/organizations/$PROJECT_ID/reports" \
    --header "Authorization: Bearer $TOKEN" \
    --header 'Accept: application/json' \
    --header 'Content-Type: application/json' \
    --data '{"name":"ai-responsible-report","displayName":"Responsible AI Report","metrics":[{"name":"dc_ma_pi_jailbreak","function":"sum"},{"name":"dc_ma_malicious_uri","function":"sum"},{"name":"dc_ma_csam","function":"sum"},{"name":"dc_ma_rai","function":"sum"}],"dimensions":["api_product","developer_app"],"properties":[{"value":[{}]}],"chartType":"line"}' \
    --compressed || true
fi

echo "Deploying the sharedflows"
import_and_deploy_sharedflow "llm-extract-candidates-v1"
import_and_deploy_sharedflow "llm-extract-prompts-v1"
import_and_deploy_sharedflow "llm-logger-v1"
import_and_deploy_sharedflow "cloud-logger-v1"

echo "Deploying the proxies"
import_and_deploy_proxy "cymbal-customers-v2"
import_and_deploy_proxy "cymbal-orders-v2"
import_and_deploy_proxy "cymbal-returns-v2"
import_and_deploy_proxy "cymbal-shipping-v2"
import_and_deploy_proxy "oauth-server"
import_and_deploy_proxy "adk-retail-agent-llm-governance-v1"
if [ "$DEPLOY_DISCOVERY_PROXY" = "true" ]; then
  import_and_deploy_proxy "cymbal-discovery-v1"
fi

echo "Creating or Updating API Products"
apigeecli products update --name "cymbal-retail-product" --display-name "cymbal-retail-product" \
  --opgrp ./config/cymbal-retail-product-ops.json --envs "$APIGEE_ENV" \
  --approval auto --scopes "customer" --org "$PROJECT_ID" --token "$TOKEN" || \
apigeecli products create --name "cymbal-retail-product" --display-name "cymbal-retail-product" \
  --opgrp ./config/cymbal-retail-product-ops.json --envs "$APIGEE_ENV" \
  --approval auto --scopes "customer" --org "$PROJECT_ID" --token "$TOKEN"

echo "Creating Developer"
apigeecli developers create --user cymbal-retail-developer \
  --email "cymbal-retail-developer@acme.com" --first="Cymbal Retail" \
  --last="Sample User" --org "$PROJECT_ID" --token "$TOKEN" || true

echo "Creating Developer App"
apigeecli apps create --name cymbal-retail-app --email "cymbal-retail-developer@acme.com" \
  --prods "cymbal-retail-product" --callback "http://127.0.0.1:9000/callback,http://127.0.0.1:8000/oauth2-redirect,http://localhost:8000/oauth2-redirect,https://iamconnectorcredentials.googleapis.com/v1/projects/${PROJECT_ID}/locations/${VERTEXAI_REGION}/connectors/idp-connector/oauthcallback" --org "$PROJECT_ID" --token "$TOKEN" --disable-check || true

CLIENT_ID=$(apigeecli apps get --name "cymbal-retail-app" --org "$PROJECT_ID" --token "$TOKEN" --disable-check | jq ."[0].credentials[0].consumerKey" -r)
CLIENT_SECRET=$(apigeecli apps get --name "cymbal-retail-app" --org "$PROJECT_ID" --token "$TOKEN" --disable-check | jq ."[0].credentials[0].consumerSecret" -r)

echo "Creating secrets that will be used by ADK"

CLIENT_ID_SECRET_ID="cymbal-retail-client-id"
gcloud secrets create "$CLIENT_ID_SECRET_ID" --replication-policy="automatic" --project "$PROJECT_ID" || true
echo -n "$CLIENT_ID" | gcloud secrets versions add "$CLIENT_ID_SECRET_ID" --project "$PROJECT_ID" --data-file=- || true
echo "Secret $CLIENT_ID_SECRET_ID created successfully"

CLIENT_SECRET_SECRET_ID="cymbal-retail-client-secret"
gcloud secrets create "$CLIENT_SECRET_SECRET_ID" --replication-policy="automatic" --project "$PROJECT_ID" || true
echo -n "$CLIENT_SECRET" | gcloud secrets versions add "$CLIENT_SECRET_SECRET_ID" --project "$PROJECT_ID" --data-file=- || true
echo "Secret $CLIENT_SECRET_SECRET_ID created successfully"

echo "Creating Flow-Hook for cloud-logger-v1 sharedflow ..."
apigeecli flowhooks attach \
 --name "PostProxyFlowHook" \
 --sharedflow "cloud-logger-v1" \
 --env "$APIGEE_ENV" \
 --org "$PROJECT_ID" \
 --token "$TOKEN" || true

export CLIENT_ID
export PROXY_URL="$APIGEE_HOST/v2/samples/adk-cymbal-retail"

# Sync dependencies in the package source folder before deploying
echo "Syncing agent dependencies..."
pushd python/agents/cymbal-retail-agent-geap >/dev/null
if command -v uv &> /dev/null; then
  uv sync
else
  # Fallback to standard pip if uv is not available
  if [ ! -d ".venv" ]; then
    python3 -m venv .venv
  fi
  source .venv/bin/activate
  pip install --upgrade pip
  pip install -e ".[agent-identity,a2a]"
fi

# Deploy Agent to Agent Runtime
echo "🚀 Deploying GEAP Agent to Agent Runtime..."
export GOOGLE_CLOUD_PROJECT="$PROJECT_ID"
export GOOGLE_CLOUD_LOCATION="$VERTEXAI_REGION"
source .venv/bin/activate
python3 deployment/deploy.py \
  --project "$PROJECT_ID" \
  --location "$VERTEXAI_REGION" \
  --bucket "${PROJECT_ID}_cymbal_retail_agent" \
  --client-id "$CLIENT_ID" \
  --client-secret "$CLIENT_SECRET" \
  --apigee-hostname "$APIGEE_HOST" \
  --egress-gateway "$AGENT_GATEWAY_NAME"
deactivate
popd >/dev/null

echo "Configuring Agent Egress Policies..."
./setup-agent-gateway-egress.sh

# npm test

echo " "
echo "All the Apigee artifacts are successfully deployed!"
echo " "
echo "Your Proxy URL is: https://$PROXY_URL"
echo "Your Client ID is: $CLIENT_ID"
echo "Your Client Secret is: $CLIENT_SECRET"
echo " "
echo "Run the following commands to test the API using OAuth:"
echo " "
echo "# 1. Fetch authorization code"
echo "CODE=\$(curl -s -o /dev/null -w \"%{redirect_url}\" \"https://$APIGEE_HOST/authorize?client_id=$CLIENT_ID&response_type=code&scope=manager&redirect_uri=http://127.0.0.1:9000/callback\" | grep -oE \"code=[^&]+\" | cut -d= -f2)"
echo " "
echo "# 2. Exchange code for access token"
echo "ACCESS_TOKEN=\$(curl -s -X POST \"https://$APIGEE_HOST/token\" \\"
echo "  -H \"Content-Type: application/x-www-form-urlencoded\" \\"
echo "  -d \"grant_type=authorization_code\" \\"
echo "  -d \"code=\$CODE\" \\"
echo "  -d \"client_id=$CLIENT_ID\" \\"
echo "  -d \"redirect_uri=http://127.0.0.1:9000/callback\" \\"
echo "  -d \"client_secret=$CLIENT_SECRET\" | jq -r .access_token)"
echo " "
echo "# 3. Call REST endpoints using the Bearer Token:"
echo " "
echo "Customers API:"
echo "curl --location \"https://$APIGEE_HOST/v2/samples/adk-cymbal-retail/customers\" \\"
echo "  --header \"Authorization: Bearer \$ACCESS_TOKEN\""
echo " "
echo "Orders API:"
echo "curl --location \"https://$APIGEE_HOST/v2/samples/adk-cymbal-retail/orders\" \\"
echo "  --header \"Authorization: Bearer \$ACCESS_TOKEN\""
echo " "
echo "Returns API:"
echo "curl --location \"https://$APIGEE_HOST/v2/samples/adk-cymbal-retail/returns\" \\"
echo "  --header \"Authorization: Bearer \$ACCESS_TOKEN\""
echo " "
echo "Export these variables for local agent configuration:"
echo "export CLIENT_ID=$CLIENT_ID"
echo "export CLIENT_SECRET=$CLIENT_SECRET"
echo "export APIGEE_HOST=$APIGEE_HOST"
echo " "
echo "Your PROJECT_ID is: $PROJECT_ID"
echo "Your APIGEE_HOST is: $APIGEE_HOST"
echo "Your CLIENT_ID is: $CLIENT_ID"
echo "Your CLIENT_SECRET is: $CLIENT_SECRET"

echo "================================================="
echo "✅ Finished deploy-adk-cymbal-retail-agent.sh"
echo "================================================="
