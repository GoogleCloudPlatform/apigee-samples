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

if [ -z "$SERVICE_ACCOUNT_NAME" ]; then
  echo "No SERVICE_ACCOUNT_NAME variable set"
  exit 1
fi

if [ -z "$VERTEXAI_REGION" ]; then
  echo "No VERTEXAI_REGION variable set"
  exit 1
fi

if [ -z "$NON_ADMIN_USER" ]; then
  echo "No NON_ADMIN_USER variable set"
  exit 1
fi

if [ -z "$TOKEN" ]; then
  TOKEN=$(gcloud auth print-access-token)
fi

# Determine sed in-place arguments for portability (macOS vs Linux)
sedi_args=("-i")
if [[ "$(uname)" == "Darwin" ]]; then
  sedi_args=("-i" "") # For macOS, sed -i requires an extension argument. "" means no backup.
fi

add_role_to_serviceaccount(){
  local role=$1
  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="${role}"
}

echo "======================"
echo "Started bq-setup.sh"
echo "======================"

gcloud services enable bigquery.googleapis.com datacatalog.googleapis.com --project "$PROJECT_ID"

echo "Creating Service Account and assigning permissions"
gcloud iam service-accounts create "$SERVICE_ACCOUNT_NAME" --project "$PROJECT_ID"

echo "Assigning BQ roles to service account"
add_role_to_serviceaccount "roles/bigquery.readSessionUser"
add_role_to_serviceaccount "roles/bigquery.jobUser"
add_role_to_serviceaccount "roles/bigquery.dataEditor"
add_role_to_serviceaccount "roles/datacatalog.categoryAdmin"

echo "Creating BQ Taxonomy"
TAXONOMY_ID=$(curl --location "https://datacatalog.googleapis.com/v1/projects/$PROJECT_ID/locations/$VERTEXAI_REGION/taxonomies" \
--header "Content-Type: application/json" \
--header "Authorization: Bearer $TOKEN" \
--data "{
  \"name\": \"product_sensitivity\",
  \"displayName\": \"product_sensitivity\",
  \"description\": \"product sensitivity\"
}" | jq ."name" -r)

echo "Creating BQ Policy Tag"
POLICYTAG_ID=$(curl --location "https://datacatalog.googleapis.com/v1/$TAXONOMY_ID/policyTags" \
--header "Content-Type: application/json" \
--header "Authorization: Bearer $TOKEN" \
--data "{
  \"name\": \"HIGH\",
  \"displayName\": \"HIGH\",
  \"description\": \"high sensitivity\"
}" | jq ."name" -r)

echo "Create Data policies to enable the policy tag"
curl --location "https://bigquerydatapolicy.googleapis.com/v1/projects/$PROJECT_ID/locations/$VERTEXAI_REGION/dataPolicies" \
--header "Content-Type: application/json" \
--header "Authorization: Bearer $TOKEN" \
--data "{
    \"dataPolicyType\": \"COLUMN_LEVEL_SECURITY_POLICY\",
    \"dataPolicyId\": \"high_sensitivity_policy\",
    \"policyTag\": \"$POLICYTAG_ID\"
}"

echo "Create Data policies to mask the column records"
curl --location "https://bigquerydatapolicy.googleapis.com/v1/projects/$PROJECT_ID/locations/$VERTEXAI_REGION/dataPolicies" \
--header "Content-Type: application/json" \
--header "Authorization: Bearer $TOKEN" \
--data "{
    \"dataPolicyType\": \"DATA_MASKING_POLICY\",
    \"dataPolicyId\": \"nullify\",
    \"policyTag\": \"$POLICYTAG_ID\",
    \"dataMaskingPolicy\": {
        \"predefinedExpression\": \"ALWAYS_NULL\"
    }
}"

curl --location "https://bigquerydatapolicy.googleapis.com/v1/projects/$PROJECT_ID/locations/$VERTEXAI_REGION/dataPolicies/nullify:setIamPolicy" \
--header "Content-Type: application/json" \
--header "Authorization: Bearer $TOKEN" \
--data "{
    \"policy\": {
        \"bindings\": [
            {
                \"role\": \"roles/bigquerydatapolicy.maskedReader\",
                \"members\": [
                    \"user:$NON_ADMIN_USER\"
                ]
            }
        ]
    }
}"

cp ./config/products/schema.json ./config/products/schema-temp.json
sed "${sedi_args[@]}" "s|POLICYTAG_ID|${POLICYTAG_ID}|g" ./config/products/schema-temp.json

echo "Creating the products_sample_data dataset"
bq --location="$VERTEXAI_REGION" mk \
    --dataset \
    --description "Products Sample Dataset" \
    "$PROJECT_ID:products_sample_data"

echo "Creating Products table"
bq mk \
 --table \
 --schema "./config/products/schema-temp.json" \
 --project_id "$PROJECT_ID" \
 --description "Products table" \
 products_sample_data.products

echo "Loading sample data to products table"
bq --location="$VERTEXAI_REGION"  --project_id "$PROJECT_ID" load \
--autodetect --source_format="NEWLINE_DELIMITED_JSON" \
"products_sample_data.products" \
"./config/products/product-items.json"

rm ./config/products/schema-temp.json

echo "======================"
echo "Finished bq-setup.sh"
echo "======================"