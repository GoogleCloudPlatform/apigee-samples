#!/bin/bash

# Copyright 2023-2024 Google LLC
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

PROXY_NAME=cloud-function-http-trigger

import_and_deploy_apiproxy() {
  local proxy_name=$1 TOKEN REV
  TOKEN=$(gcloud auth print-access-token)
  REV=$(apigeecli apis create bundle -f "./bundle/${proxy_name}/apiproxy" -n "$proxy_name" --org "$PROJECT" --token "$TOKEN" --disable-check | jq ."revision" -r)
  apigeecli apis deploy --wait --name "$proxy_name" --ovr --rev "$REV" --org "$APIGEE_PROJECT" --env "$APIGEE_ENV" --token "$TOKEN" --disable-check
}

MISSING_ENV_VARS=()
[[ -z "$APIGEE_PROJECT" ]] && MISSING_ENV_VARS+=('APIGEE_PROJECT')
[[ -z "$APIGEE_ENV" ]] && MISSING_ENV_VARS+=('APIGEE_ENV')
[[ -z "$APIGEE_HOST" ]] && MISSING_ENV_VARS+=('APIGEE_HOST')
[[ -z "$CLOUD_FUNCTIONS_REGION" ]] && MISSING_ENV_VARS+=('CLOUD_FUNCTIONS_REGION')
[[ -z "$CLOUD_FUNCTIONS_PROJECT" ]] && MISSING_ENV_VARS+=('CLOUD_FUNCTIONS_PROJECT')
[[ -z "$CLOUD_FUNCTION_NAME" ]] && MISSING_ENV_VARS+=('CLOUD_FUNCTION_NAME')

[[ ${#MISSING_ENV_VARS[@]} -ne 0 ]] && {
  printf -v joined '%s,' "${MISSING_ENV_VARS[@]}"
  printf "You must set these environment variables: %s\n" "${joined%,}"
  exit 1
}

echo "Running apigeelint"
node_modules/apigeelint/cli.js --profile apigeex -e TD002,TD004 -s "./bundle/${PROXY_NAME}/apiproxy" -f table.js

echo "Installing apigeecli"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

import_and_deploy_apiproxy "$PROXY_NAME"

echo " "
echo "The proxy is deployed. "
