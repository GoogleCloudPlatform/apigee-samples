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

echo "💻 Deploying Apigee proxy and portal catalog entry..."

# copy oas for apigee proxy
cp oas.yaml oas.local.yaml

# create apigee proxy based on spec
apigeecli apis create openapi -n "apihub-portal-publish" -f . --oas-name "oas.local.yaml" -p "/v1/samples/apihub-portal-publish" --add-cors=true -o "$PROJECT_ID" --env "$APIGEE_ENV" --wait=true -t "$(gcloud auth print-access-token)"

# Determine sed in-place arguments for portability (macOS vs Linux)
sedi_args=("-i")
if [[ "$(uname)" == "Darwin" ]]; then
  sedi_args=("-i" "") # For macOS, sed -i requires an extension argument. "" means no backup.
fi

# now replace oas server with apigee
sed "${sedi_args[@]}" "s,mocktarget.apigee.net,$APIGEE_HOST,g" ./oas.local.yaml
sed "${sedi_args[@]}" "s,/:,/v1/samples/apihub-portal-publish:,g" ./oas.local.yaml
sed "${sedi_args[@]}" "s,/ip:,/v1/samples/apihub-portal-publish/ip:,g" ./oas.local.yaml
sed "${sedi_args[@]}" "s,/json:,/v1/samples/apihub-portal-publish/json:,g" ./oas.local.yaml

# create apigee product
apigeecli products create --name "apihub-portal-product" --display-name "Apigee API hub Apigee Product" -p "apihub-portal-publish" --envs "dev" --approval "auto" --attrs "access=public" -o "$PROJECT_ID" -t "$(gcloud auth print-access-token)"

# get portal id from url
APIGEE_PORTAL_ID="${APIGEE_PORTAL_URL/.apigee.io/}"

# create portal doc
CATALOG_RESULT=$(apigeecli apidocs create --allow-anon "true" --api-product "apihub-portal-product" --desc "Apigee Sample Product" --image-url "https://storage.googleapis.com/gweb-developer-goog-blog-assets/images/Banner-Apigee-API-Hub.original.png" -p "true" --require-callback-url "false" -l "Apigee Sample Product" -s "$APIGEE_PORTAL_ID" -o "$PROJECT_ID" -t "$(gcloud auth print-access-token)")
CATALOG_ID=$(echo "$CATALOG_RESULT" | jq --raw-output ".data.id")

# update portal documentation
apigeecli apidocs documentation update -i "$CATALOG_ID" -n "Apigee Sample Product" -p "./oas.local.yaml" -s "$APIGEE_PORTAL_ID" -o "$PROJECT_ID" -t "$(gcloud auth print-access-token)"

echo "💻 Registering Apigee managed API to Apigee API hub..."

sed "${sedi_args[@]}" "s,mocktarget.apigee.net/help,$APIGEE_PORTAL_URL/docs/apihub-portal-product/1,g" ./apihub-api.local.json
sed "${sedi_args[@]}" "s,mocktarget.apigee.net/help,$APIGEE_PORTAL_URL/docs/apihub-portal-product/1,g" ./apihub-api-version.local.json
sed "${sedi_args[@]}" "s,mocktarget.apigee.net/help,$APIGEE_PORTAL_URL/docs/apihub-portal-product/1,g" ./apihub-api-deployment.local.json
sed "${sedi_args[@]}" "s,mocktarget.apigee.net,$APIGEE_HOST/v1/samples/apihub-portal-publish,g" ./apihub-api-deployment.local.json
sed "${sedi_args[@]}" "s,unmanaged,apigee,g" ./apihub-api-deployment.local.json
sed "${sedi_args[@]}" "s,Unmanaged,Apigee,g" ./apihub-api-deployment.local.json
sed "${sedi_args[@]}" "s,test,prod,g" ./apihub-api-deployment.local.json
sed "${sedi_args[@]}" "s,Test,Production,g" ./apihub-api-deployment.local.json
sed "${sedi_args[@]}" "s.-v1-deployment\".-v1-deployment\", \"projects/$PROJECT_ID/locations/$APIHUB_REGION/deployments/apigee-sample-managed-v1-deployment\".g" ./apihub-api-version.local.json
sed "${sedi_args[@]}" "s,develop,prod,g" ./apihub-api-version.local.json
sed "${sedi_args[@]}" "s,Develop,Production,g" ./apihub-api-version.local.json

# create managed deployment
curl -X POST "https://apihub.googleapis.com/v1/projects/$PROJECT_ID/locations/$APIHUB_REGION/deployments?deploymentId=apigee-sample-managed-v1-deployment" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  --data "@apihub-api-deployment.local.json"

# create api version spec for apigee
apigeecli apihub apis versions specs create -i "apigee-sample-managed-api-v1-spec" --api-id "apigee-sample-api" --version "apigee-sample-api-v1" -d "Apigee Sample Managed API v1 Spec" -f "./oas.local.yaml" -r "$APIHUB_REGION" -o "$PROJECT_ID" -t "$(gcloud auth print-access-token)"
apigeecli apihub apis versions update --api-id "apigee-sample-api" -i "apigee-sample-api-v1" -f apihub-api-version.local.json -r "$APIHUB_REGION" -o "$PROJECT_ID" -t "$(gcloud auth print-access-token)"
apigeecli apihub apis update -i "apigee-sample-api" -f apihub-api.local.json -r "$APIHUB_REGION" -o "$PROJECT_ID" -t "$(gcloud auth print-access-token)"

echo "🎊 Finished with managed API deployment and Apigee API hub registration!"
echo "🎊 Visit Apigee API hub here to see results: https://console.cloud.google.com/apigee/api-hub/apis"