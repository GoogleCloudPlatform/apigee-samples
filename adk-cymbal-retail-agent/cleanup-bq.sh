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

if [ -z "$TOKEN" ]; then
  TOKEN=$(gcloud auth print-access-token)
fi

remove_role_from_service_account() {
  local role=$1
  gcloud projects remove-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="$role"
}

echo "Deleting products_sample_data dataset"
bq rm -r -f --project_id $PROJECT_ID products_sample_data 

echo "Deleting Data policies to enable the policy tag"
curl --location --request DELETE "https://bigquerydatapolicy.googleapis.com/v1/projects/$PROJECT_ID/locations/$VERTEXAI_REGION/dataPolicies/high_sensitivity_policy" \
--header "Content-Type: application/json" \
--header "Authorization: Bearer $TOKEN"

echo "Deleting Data policies to mask the column records"
curl --location --request DELETE "https://bigquerydatapolicy.googleapis.com/v1/projects/$PROJECT_ID/locations/$VERTEXAI_REGION/dataPolicies/nullify" \
--header "Content-Type: application/json" \
--header "Authorization: Bearer $TOKEN"

echo "Deleting BQ Policy Tag"

TAXONOMY_ID=$(curl --location "https://datacatalog.googleapis.com/v1/projects/$PROJECT_ID/locations/$VERTEXAI_REGION/taxonomies/" \
--header "Content-Type: application/json" \
--header "Authorization: Bearer $TOKEN" \
| jq ."taxonomies[] | select(.displayName == \"product_sensitivity\") | .name" -r)

POLICYTAG_ID=$(curl --location "https://datacatalog.googleapis.com/v1/$TAXONOMY_ID/policyTags" \
--header "Content-Type: application/json" \
--header "Authorization: Bearer $TOKEN" \
| jq ."policyTags[] | select(.displayName == \"HIGH\") | .name" -r)

curl --location --request DELETE "https://datacatalog.googleapis.com/v1/$POLICYTAG_ID" \
--header "Content-Type: application/json" \
--header "Authorization: Bearer $TOKEN"

echo "Deleting BQ Taxonomy"
curl --location --request DELETE "https://datacatalog.googleapis.com/v1/$TAXONOMY_ID" \
--header "Content-Type: application/json" \
--header "Authorization: Bearer $TOKEN"

echo "Removing BQ roles from service account"
remove_role_from_service_account "roles/bigquery.readSessionUser"
remove_role_from_service_account "roles/bigquery.jobUser"
remove_role_from_service_account "roles/bigquery.dataEditor"
remove_role_from_service_account "roles/datacatalog.categoryAdmin"
