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

source ./shlib/utils.sh

delete_deployable_asset() {
  local asset_type asset_name collection REV ENVNAME OUTFILE NUM_DEPLOYS
  asset_type=$1
  asset_name=$2
  collection="${asset_type}s"

  printf "Checking %s %s\n" "$asset_type" "${asset_name}"
  if apigeecli "$collection" get --name "$asset_name" --org "$PROJECT_ID" --token "$TOKEN" --disable-check &>/dev/null; then
    OUTFILE=$(mktemp /tmp/apigee-samples.apigeecli.out.XXXXXX)
    if apigeecli "$collection" listdeploy --name "$asset_name" --org "$PROJECT_ID" --token "$TOKEN" --disable-check >"$OUTFILE" 2>&1; then
      NUM_DEPLOYS=$(jq -r '.deployments | length' "$OUTFILE")
      if [[ $NUM_DEPLOYS -ne 0 ]]; then
        echo "Undeploying ${asset_name}"
        for ((i = 0; i < NUM_DEPLOYS; i++)); do
          ENVNAME=$(jq -r ".deployments[$i].environment" "$OUTFILE")
          REV=$(jq -r ".deployments[$i].revision" "$OUTFILE")
          apigeecli "$collection" undeploy --name "${asset_name}" --env "$ENVNAME" --rev "$REV" --org "$PROJECT_ID" --token "$TOKEN" --disable-check
        done
      else
        printf "  There are no deployments of %s to remove.\n" "${asset_name}"
      fi
    fi
    [[ -f "$OUTFILE" ]] && rm "$OUTFILE"
    echo "Deleting ${asset_type} ${asset_name}"
    apigeecli "$collection" delete --name "${asset_name}" --org "$PROJECT_ID" --token "$TOKEN" --disable-check
  else
    printf "  The %s %s does not exist.\n" "${asset_type}" "${asset_name}"
  fi
}

remove_roles_from_service_account() {
  local ASSIGNED_ROLES role
  ASSIGNED_ROLES=(
    "roles/apigee.analyticsEditor"
    "roles/logging.logWriter"
    "roles/aiplatform.user"
    "roles/modelarmor.admin"
    "roles/iam.serviceAccountUser")
  # shellcheck disable=SC2034
  read -r -a ARR < <(gcloud projects get-iam-policy "${PROJECT_ID}" \
    --flatten="bindings[].members" \
    --filter="bindings.members:${SA_EMAIL}" \
    --format="value(bindings.role)" 2>/dev/null)

  for role in "${ASSIGNED_ROLES[@]}"; do
    printf "\nChecking for '%s' role....\n" "${role}"

    if is_role_present "${role}" "ARR"; then
      printf "Removing role '%s' for SA '%s'....\n" "${role}" "${SA_EMAIL}"
      gcloud projects remove-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:${SA_EMAIL}" \
        --role="$role" &>/dev/null
    fi
  done

}

# ====================================================================

check_shell_variables PROJECT_ID \
  APIGEE_ENV \
  SERVICE_ACCOUNT_NAME

check_required_commands gcloud jq curl

TOKEN=$(gcloud auth print-access-token)

if [[ ! -f $HOME/.apigeecli/bin/apigeecli ]]; then
  echo "Installing apigeecli"
  curl -s https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | bash
fi
export PATH=$PATH:$HOME/.apigeecli/bin

product_name="llm-security-product-v2"
dev_email="llm-security-developer-v2@acme.com"
app_name="llm-security-app-v2"

# ------------------------------------------------
printf "\nCheck and maybe delete the app...\n"
OUTPUT=$(apigeecli apps get --name "${app_name}" --org "$PROJECT_ID" --token "$TOKEN" --disable-check 2>/dev/null)
if [[ "$(echo "$OUTPUT" | jq -r 'type')" == "object" ]]; then
  printf "The Developer App %s does not exist." "$app_name"
else
  echo "Deleting Developer App..."
  DEVELOPER_ID=$(apigeecli developers get --email "$dev_email" --org "$PROJECT_ID" --token "$TOKEN" --disable-check | jq .'developerId' -r)
  apigeecli apps delete --id "$DEVELOPER_ID" --name "$app_name" --org "$PROJECT_ID" --token "$TOKEN"
fi

# ------------------------------------------------
printf "\nCheck and maybe delete the developer...\n"
if apigeecli developers get --email "${dev_email}" --org "$PROJECT_ID" --token "$TOKEN" --disable-check &>/dev/null; then
  echo "Deleting Developer"
  apigeecli developers delete --email "$dev_email" --org "$PROJECT_ID" --token "$TOKEN"
else
  printf "  The developer %s does not exist.\n" "$dev_email"
fi

# ------------------------------------------------
printf "\nCheck and maybe delete the product...\n"
if apigeecli products get --name "${product_name}" --org "$PROJECT_ID" --token "$TOKEN" --disable-check &>/dev/null; then
  echo "Deleting API Product..."
  apigeecli products delete --name "$product_name" --org "$PROJECT_ID" --token "$TOKEN"
else
  printf "  The apiproduct %s does not exist\n" "${product_name}"
fi

# ------------------------------------------------
printf "\nCheck and maybe delete the KVM...\n"
kvm_name="model-armor-config-v2"
if apigeecli kvms list -e "${APIGEE_ENV}" -o "$PROJECT_ID" --token "$TOKEN" | jq -e 'any(. == "'$kvm_name'")' >/dev/null; then
  echo "Deleting KVM"
  apigeecli kvms delete -n $kvm_name --env "$APIGEE_ENV" --org "$PROJECT_ID" --token "$TOKEN"
else
  echo "The KVM $kvm_name does not exist..."
fi

delete_deployable_asset api "llm-security-v2"
delete_deployable_asset sharedflow "ModelArmor-v2"

SA_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
echo "Removing assigned roles from Service Account"
remove_roles_from_service_account

echo "Deleting Service Account"
if gcloud iam service-accounts describe "${SA_EMAIL}" --project="$PROJECT_ID" --quiet &>/dev/null; then
  gcloud iam service-accounts delete "${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" --project "$PROJECT_ID" --quiet
else
  printf "The service account %s does not exist.\n" "$SA_EMAIL"
fi
