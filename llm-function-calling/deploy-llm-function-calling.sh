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

scriptdir="$(cd "$(dirname "BASH_SOURCE[0]")" >/dev/null 2>&1 && pwd)"

source "${scriptdir}/../shlib/utils.sh"

# ====================================================================

check_shell_variables PROJECT_ID APIGEE_ENV APIGEE_HOST
check_required_commands gcloud jq curl

[[ -z "$TOKEN" ]] && TOKEN=$(gcloud auth print-access-token)

insure_apigeecli

gcloud services enable aiplatform.googleapis.com dialogflow.googleapis.com --project "$PROJECT_ID"

proxy_name="llm-function-calling-v1"
import_and_deploy_apiproxy "$proxy_name" "$PROJECT_ID" "$APIGEE_ENV"

product_name="llm-function-calling-product"
dev_moniker="llm-function-calling-developer"
app_name="llm-function-calling-app"
dev_email="${dev_moniker}@acme.com"

create_product_if_necessary "${product_name}" "$PROJECT_ID" "$APIGEE_ENV"
create_developer_if_necessary "$dev_moniker" "$PROJECT_ID" "LLM Function Calling"
create_app_if_necessary "$app_name" "$PROJECT_ID" "$product_name" "$dev_email"

APIKEY=$(apigeecli apps get --name "$app_name" --org "$PROJECT_ID" --token "$TOKEN" --disable-check | jq ."[0].credentials[0].consumerKey" -r)

PROXY_URL="$APIGEE_HOST/v1/samples/llm-function-calling"

echo " "
echo "All the Apigee artifacts are successfully deployed!"
echo " "
echo "Your Proxy URL is: https://$PROXY_URL"
echo " "
echo "Run the following command to test the API"
echo " "
echo "curl --location \"https://\$APIGEE_HOST/v1/samples/llm-function-calling/products\" \\"
echo "  --header \"Content-Type: application/json\" \\"
echo "  --header \"x-apikey: \$APIKEY\""
echo " "
echo "Copy/paste this to set the APIKEY variable:"
echo "  export APIKEY=$APIKEY"
echo " "
echo "You can now go back to the Colab notebook to test the sample. You will need the following variables during your test."
echo "Your PROJECT_ID is: $PROJECT_ID"
echo "Your APIGEE_HOST is: $APIGEE_HOST"
echo "Your APIKEY is: $APIKEY"
