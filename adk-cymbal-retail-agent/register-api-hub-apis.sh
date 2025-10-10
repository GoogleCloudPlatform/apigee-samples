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

if [ -z "$APIGEE_APIHUB_PROJECT_ID" ]; then
  echo "No APIGEE_APIHUB_PROJECT_ID variable set"
  exit 1
fi

if [ -z "$APIGEE_APIHUB_REGION" ]; then
  echo "No APIGEE_APIHUB_REGION variable set"
  exit 1
fi

if [ -z "$TOKEN" ]; then
  TOKEN=$(gcloud auth print-access-token)
fi

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

echo "Registering APIs in Apigee API hub"
cp -rf config tmp/
sed -i "s/APIGEE_HOST/$APIGEE_HOST/g" tmp/*/*.yaml
sed -i "s/APIGEE_APIHUB_PROJECT_ID/$APIGEE_APIHUB_PROJECT_ID/g" tmp/*/*.json
sed -i "s/APIGEE_APIHUB_REGION/$APIGEE_APIHUB_REGION/g" tmp/*/*.json

apigeecli apihub attributes update -r "$APIGEE_APIHUB_REGION" -o "$APIGEE_APIHUB_PROJECT_ID" -t "$TOKEN" --allowed-values  "config/business-units.json" --data-type "ENUM" -i "system-business-unit" -s "API" -m "allowed_values" -d "Business Unit"
apigeecli apihub attributes update -r "$APIGEE_APIHUB_REGION" -o "$APIGEE_APIHUB_PROJECT_ID" -t "$TOKEN" --allowed-values  "config/teams.json" --data-type "ENUM" -i "system-team" -s "API" -m "allowed_values" -d "Team"

add_rest_api_to_hub "customers"
add_rest_api_to_hub "orders"
add_rest_api_to_hub "returns"
add_rest_api_to_hub "accounts"
add_rest_api_to_hub "communications"
add_rest_api_to_hub "employees"
add_rest_api_to_hub "products"
add_rest_api_to_hub "stocks"
add_soap_api_to_hub "payments"
add_grpc_api_to_hub "shipments"

rm -rf tmp