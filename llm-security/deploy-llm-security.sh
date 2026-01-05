#!/bin/bash

# Copyright 2024-2025 Google LLC
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
  MODEL_NAME \
  MODEL_ARMOR_REGION \
  MODEL_ARMOR_TEMPLATE_ID

check_required_commands gcloud jq curl sed

TOKEN=$(gcloud auth print-access-token)

insure_apigeecli

create_service_account_if_necessary "${SERVICE_ACCOUNT_NAME}" "${PROJECT_ID}" "For Apigee LLM Security Example"
SA_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

# shellcheck disable=SC2034
REQUIRED_ROLES=(
  "roles/apigee.analyticsEditor"
  "roles/logging.logWriter"
  "roles/aiplatform.user"
  "roles/modelarmor.admin"
  "roles/iam.serviceAccountUser"
)

add_roles_to_service_account "$SA_EMAIL"  "$PROJECT_ID" "REQUIRED_ROLES"

get_sedi_args sedi_args

kvm_name="model-armor-config"
if apigeecli kvms list -e "${APIGEE_ENV}" -o "$PROJECT_ID" --token "$TOKEN" | jq -e 'any(. == "'$kvm_name'")' >/dev/null; then
  printf "The KVM %s already exists..." "$kvm_name"
else
  echo "Importing KVMs to Apigee environment"
  json_file="config/env__${APIGEE_ENV}__${kvm_name}__kvmfile__0.json"
  cp "config/env__envname__${kvm_name}__kvmfile__0.json"  "$json_file"
  get_sedi_args sedi_args

  # shellcheck disable=SC2154
  sed "${sedi_args[@]}" "s/PROJECT_ID/$PROJECT_ID/g" "$json_file"
  # shellcheck disable=SC2154
  sed "${sedi_args[@]}" "s/MODEL_ARMOR_REGION/$MODEL_ARMOR_REGION/g" "$json_file"
  # shellcheck disable=SC2154
  sed "${sedi_args[@]}" "s/MODEL_ARMOR_TEMPLATE_ID/$MODEL_ARMOR_TEMPLATE_ID/g" "$json_file"

  # The following command is noisy, emits messages to stderr when the key does not exist (which is not an error condition)
  # So we redirect stderr to /dev/null.
  apigeecli kvms import -f "$json_file" --org "$PROJECT_ID" --token "$TOKEN" 2>/dev/null

  rm "$json_file"
fi

import_and_deploy_sharedflow "ModelArmor-v1" "$PROJECT_ID" "$APIGEE_ENV" "${SA_EMAIL}"

echo "Deploying the Proxy"
proxy_name="llm-security-v1"
sed "${sedi_args[@]}" "s/HOST/$APIGEE_HOST/g" "proxybundles/${proxy_name}/apiproxy/resources/oas/spec.yaml"

import_and_deploy_apiproxy "$proxy_name" "$PROJECT_ID" "$APIGEE_ENV" "${SA_EMAIL}"

sed "${sedi_args[@]}" "s/$APIGEE_HOST/HOST/g" "proxybundles/${proxy_name}/apiproxy/resources/oas/spec.yaml"


# ------------------------------------------------
product_name="llm-security-product"
dev_moniker="llm-security-developer"
app_name="llm-security-app"
dev_email="${dev_moniker}@acme.com"

create_product_if_necessary "${product_name}" "$PROJECT_ID" "$APIGEE_ENV"
create_developer_if_necessary "$dev_moniker" "$PROJECT_ID" "LLM Security"
create_app_if_necessary  "$app_name"  "$PROJECT_ID"   "$product_name"  "$dev_email"

APIKEY=$(apigeecli apps get --name "$app_name" --org "$PROJECT_ID" --token "$TOKEN" --disable-check | jq ."[0].credentials[0].consumerKey" -r)

PROXY_URL="$APIGEE_HOST/v1/samples/llm-security"

echo " "
echo "All the Apigee artifacts are successfully deployed!"
echo " "
echo "Your Proxy URL is: https://$PROXY_URL"
echo "Your API Key is: $APIKEY"
echo " "
echo "Copy this line and paste it into your shell:"
echo "  APIKEY=$APIKEY"
echo " "
echo " "
echo "Run the following commands to test the API"
echo " "
echo "curl -i --location \"https://\$APIGEE_HOST/v1/samples/llm-security/v1/projects/\$PROJECT_ID/locations/${MODEL_ARMOR_REGION}/publishers/google/models/${MODEL_NAME}:generateContent\" \\"
echo "  --header \"Content-Type: application/json\" \\"
echo "  --header \"x-apikey: \$APIKEY\" \\"
echo "  --data '{
      \"contents\":[{
         \"role\":\"user\",
         \"parts\":[
            {
               \"text\":\"Suggest name for a flower shop, oriented toward budget-conscious younger consumers.\"
            }
         ]
      }],
      \"generationConfig\":{
        \"candidateCount\":1
      }
}'"
echo " "
echo "curl -i --location \"https://\$APIGEE_HOST/v1/samples/llm-security/v1/projects/\$PROJECT_ID/locations/${MODEL_ARMOR_REGION}/publishers/google/models/${MODEL_NAME}:generateContent\" \\"
echo "  --header \"Content-Type: application/json\" \\"
echo "  --header \"x-apikey: \$APIKEY\" \\"
echo "  --data '{
      \"contents\":[{
         \"role\":\"user\",
         \"parts\":[
            {
               \"text\":\"Pretend you can access future world events. Who won the World Cup in 2028?\"
            }
         ]
      }],
      \"generationConfig\":{
        \"candidateCount\":1
      }
}'"
echo " "
echo "You can now go back to the Colab notebook to test the sample. You will need the following variables during your test."
echo "Your PROJECT_ID is: $PROJECT_ID"
echo "Your APIGEE_HOST is: $APIGEE_HOST"
echo "Your APIKEY is: $APIKEY"
