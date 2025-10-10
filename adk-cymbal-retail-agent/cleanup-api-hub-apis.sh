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
# set -e

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

TOKEN=$(gcloud auth print-access-token)

delete_api_from_hub() {
  local api=$1
  apigeecli apihub apis delete --id "${api}_api" \
  --force true \
  -r "$APIGEE_APIHUB_REGION" -o "$APIGEE_APIHUB_PROJECT_ID" -t "$TOKEN"
}

echo "Installing apigeecli"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

delete_api_from_hub "customers"
delete_api_from_hub "orders"
delete_api_from_hub "returns"
delete_api_from_hub "accounts"
delete_api_from_hub "communications"
delete_api_from_hub "employees"
delete_api_from_hub "products"
delete_api_from_hub "stocks"
delete_api_from_hub "payments"
delete_api_from_hub "shipments"

rm -rf tmp