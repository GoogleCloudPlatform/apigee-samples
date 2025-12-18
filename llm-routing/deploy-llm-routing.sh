#!/bin/bash

# Copyright © 2024-2025 Google LLC
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

check_shell_variables PROJECT_ID \
  APIGEE_ENV \
  APIGEE_HOST \
  SERVICE_ACCOUNT_NAME \
  VERTEXAI_REGION \
  VERTEXAI_PROJECT_ID \
  GEMINI_MODEL_ID \
  HUGGINGFACE_TOKEN \
  MISTRAL_APIKEY

check_required_commands gcloud jq curl sed

[[ -z "$TOKEN" ]] && TOKEN=$(gcloud auth print-access-token)

insure_apigeecli

create_service_account_if_necessary "${SERVICE_ACCOUNT_NAME}" "${PROJECT_ID}" "For Apigee LLM Routing Example"
SA_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

# shellcheck disable=SC2034
REQUIRED_ROLES=(
  "roles/apigee.analyticsEditor"
  "roles/logging.logWriter"
  "roles/aiplatform.user"
  "roles/iam.serviceAccountUser"
)

add_roles_to_service_account "$SA_EMAIL" "$VERTEXAI_PROJECT_ID" "REQUIRED_ROLES"

get_sedi_args sedi_args

proxy_name="llm-routing-v1"
product_name="llm-routing-product"
dev_moniker="llm-routing-developer"
app_name="llm-routing-app"
dev_email="${dev_moniker}@acme.com"
kvm_name="llm-routing-v1-modelprovider-config"

if apigeecli kvms list -e "${APIGEE_ENV}" -o "$PROJECT_ID" --token "$TOKEN" | jq -e 'any(. == "'$kvm_name'")' >/dev/null; then
  printf "The KVM %s already exists...\n" "$kvm_name"
else
  echo "Updating KVM configurations"
  json_file="config/env__${APIGEE_ENV}__${kvm_name}__kvmfile__0.json"
  cp "config/env__envname__${kvm_name}__kvmfile__0.json" "$json_file"
  # shellcheck disable=SC2154
  sed "${sedi_args[@]}" "s/MISTRAL_APIKEY/$MISTRAL_APIKEY/g" "$json_file"
  # shellcheck disable=SC2154
  sed "${sedi_args[@]}" "s/HUGGINGFACE_TOKEN/$HUGGINGFACE_TOKEN/g" "$json_file"
  # shellcheck disable=SC2154
  sed "${sedi_args[@]}" "s/VERTEXAI_REGION/$VERTEXAI_REGION/g" "$json_file"
  # shellcheck disable=SC2154
  sed "${sedi_args[@]}" "s/VERTEXAI_PROJECT_ID/$VERTEXAI_PROJECT_ID/g" "$json_file"

  echo "Importing KVMs to Apigee environment"
  apigeecli kvms import -f "$json_file" --org "$PROJECT_ID" --token "$TOKEN" 2>/dev/null
  rm "$json_file"
fi

echo "Deploying the Proxy"
sed "${sedi_args[@]}" "s/HOST/$APIGEE_HOST/g" "proxybundles/${proxy_name}/apiproxy/resources/oas/spec.yaml"

if [[ "$PROJECT_ID" != "$VERTEXAI_PROJECT_ID" ]]; then
  printf "When the Vertex AI project is different from the Apigee project, we need\n"
  printf "to wait a bit for IAM consistency..."
  sleep 8
  printf "\n"
fi

import_and_deploy_apiproxy "$proxy_name" "$PROJECT_ID" "$APIGEE_ENV" "${SA_EMAIL}"

sed "${sedi_args[@]}" "s/$APIGEE_HOST/HOST/g" "proxybundles/${proxy_name}/apiproxy/resources/oas/spec.yaml"

create_product_if_necessary "${product_name}" "$PROJECT_ID" "$APIGEE_ENV"
create_developer_if_necessary "$dev_moniker" "$PROJECT_ID" "LLM Security V2"
create_app_if_necessary "$app_name" "$PROJECT_ID" "$product_name" "$dev_email"

APIKEY=$(apigeecli apps get --name "${app_name}" --org "$PROJECT_ID" --token "$TOKEN" --disable-check | jq ."[0].credentials[0].consumerKey" -r)
PROXY_URL="$APIGEE_HOST/v1/samples/llm-routing"

echo " "
echo "All the Apigee artifacts are successfully deployed!"
echo " "
echo "Your Proxy URL is: https://$PROXY_URL"
echo "Your API Key is: $APIKEY"
echo " "
echo "Run the following commands to test the API"
echo " "
echo "Gemini: "
echo " "
echo "curl --location \"https://$APIGEE_HOST/v1/samples/llm-routing/chat/completions\" \\"
echo "  --header \"Content-Type: application/json\" \\"
echo "  --header \"x-llm-provider: google\" \\"
echo "  --header \"x-logpayload: false\" \\"
echo "  --header \"x-apikey: \$APIKEY\" \\"
echo "  --data '{
  \"model\": \"google/'\${GEMINI_MODEL_ID}'\",
  \"messages\": [ {
    \"role\": \"user\",
    \"content\": [{
      \"type\": \"image_url\",
      \"image_url\": { \"url\": \"gs://generativeai-downloads/images/character.jpg\" }
    },
    {
      \"type\": \"text\",
      \"text\": \"Describe this image in one sentence of 18-25 words.\"
    }]
  }],
  \"stream\": false
}'"

echo " "
echo "Mistral: "
echo " "
echo "curl --location \"https://$APIGEE_HOST/v1/samples/llm-routing/chat/completions\" \\"
echo "  --header \"Content-Type: application/json\" \\"
echo "  --header \"x-llm-provider: mistral\" \\"
echo "  --header \"x-logpayload: false\" \\"
echo "  --header \"x-apikey: \$APIKEY\" \\"
echo "  --data '{
  \"model\": \"open-mistral-nemo\",
  \"messages\": [ {
      \"role\": \"user\",
      \"content\": [
        {
          \"type\": \"text\",
          \"text\": \"Suggest few names for a flower shop targeted at younger, budget-conscious customers.\"
        }
      ]
  } ],
  \"max_tokens\": 250,
  \"stream\": false
}'"

echo " "
echo "HuggingFace: "
echo " "
echo "curl --location \"https://$APIGEE_HOST/v1/samples/llm-routing/chat/completions\" \\"
echo "  --header \"Content-Type: application/json\" \\"
echo "  --header \"x-llm-provider: huggingface\" \\"
echo "  --header \"x-logpayload: false\" \\"
echo "  --header \"x-apikey: \$APIKEY\" \\"
echo "  --data '{
  \"model\": \"Meta-Llama-3.1-8B-Instruct\",
  \"messages\": [ {
      \"role\": \"user\",
      \"content\": [
        {
          \"type\": \"text\",
          \"text\": \"Suggest few names for a flower shop targeted at younger, budget-conscious customers.\"
        }
      ]
  } ],
  \"max_tokens\": 250,
  \"stream\": false
}'"
echo " "
echo "Export these variables"
echo "  export APIKEY=$APIKEY"
echo " "
echo "You can now go back to the Colab notebook to test the sample. You will need the following variables during your test."
echo "Your PROJECT_ID is: $PROJECT_ID"
echo "Your APIGEE_HOST is: $APIGEE_HOST"
echo "Your APIKEY is: $APIKEY"
