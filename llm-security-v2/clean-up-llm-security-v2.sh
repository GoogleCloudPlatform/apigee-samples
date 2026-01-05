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

check_shell_variables PROJECT_ID \
  APIGEE_ENV \
  SERVICE_ACCOUNT_NAME

check_required_commands gcloud jq curl

# shellcheck disable=SC2034
TOKEN=$(gcloud auth print-access-token)

insure_apigeecli

proxy_name="llm-security-v2"
product_name="llm-security-product-v2"
dev_moniker="llm-security-developer-v2"
app_name="llm-security-app-v2"
dev_email="${dev_moniker}@acme.com"
kvm_name="model-armor-config-v2"

delete_app_if_necessary "$app_name" "$PROJECT_ID" "$dev_email"
delete_developer_if_necessary "$dev_email" "$PROJECT_ID"
delete_product_if_necessary "$product_name" "$PROJECT_ID"
delete_kvm_if_necessary "$kvm_name" "$PROJECT_ID" "$APIGEE_ENV"
delete_apiproxy "${proxy_name}" "$PROJECT_ID"
delete_sharedflow "ModelArmor-v2" "$PROJECT_ID"

# shellcheck disable=SC2034
ASSIGNED_ROLES=(
  "roles/apigee.analyticsEditor"
  "roles/logging.logWriter"
  "roles/aiplatform.user"
  "roles/modelarmor.admin"
  "roles/iam.serviceAccountUser"
)
SA_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
remove_roles_from_service_account "$SA_EMAIL" "$PROJECT_ID" "ASSIGNED_ROLES"

delete_sa_if_necessary "$SA_EMAIL" "$PROJECT_ID"

printf "\nAll done. All of the Apigee assets should have been removed.\n\n"
