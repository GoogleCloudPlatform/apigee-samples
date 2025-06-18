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

replace_element_text() {
  local element_name=$1
  local cf_url=$2
  local file_name=$3
  local match_pattern="<${element_name}>.\\+</${element_name}>"
  local replace_pattern="<${element_name}>${cf_url}</${element_name}>"
  local sed_script="s#${match_pattern}#${replace_pattern}#"
  #  in-place editing
  local SEDOPTION="-i"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    SEDOPTION='-i \x27\x27'
  fi
  sed "$SEDOPTION" -e "${sed_script}" "${file_name}"
}

echo "Installing dependencies, including apigeelint"
npm install

echo "Installing apigeecli"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

# construct the URL for the Cloud Function that we will deploy
CF_URL=$(gcloud functions describe "$CLOUD_FUNCTION_NAME" --region="$CLOUD_FUNCTIONS_REGION" --format='value(serviceConfig:.uri)')
# URL will be like : https://apigee-sample-hello-RANDOM-CHARS-wl.a.run.app
# This is a Cloud Run URL. Do Not Be Alarmed. Cloud Functions is built atop Cloud Run.
CF_URL_WITH_PATH="$CF_URL/apigee-sample-hello"

# Insert that URL into the proper places, in the Apigee API Proxy TargetEndpoint
# configuration file.

echo "Setting the Cloud Functions endpoint in the proxy..."
TARGET_1="./bundle/${PROXY_NAME}/apiproxy/targets/target-1.xml"
replace_element_text "Audience" "${CF_URL_WITH_PATH}" "${TARGET_1}"
replace_element_text "URL" "${CF_URL_WITH_PATH}" "${TARGET_1}"

echo "Running apigeelint"
node_modules/apigeelint/cli.js --profile apigeex -e TD002,TD004 -s "./bundle/${PROXY_NAME}/apiproxy" -f table.js

echo " "
echo "Preliminary setup is complete. "
