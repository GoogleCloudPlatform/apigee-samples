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

check_shell_variables() {
  local MISSING_ENV_VARS
  MISSING_ENV_VARS=()
  for var_name in "$@"; do
    if [[ -z "${!var_name}" ]]; then
      MISSING_ENV_VARS+=("$var_name")
    fi
  done

  if [[ ${#MISSING_ENV_VARS[@]} -ne 0 ]]; then
    printf -v joined '%s,' "${MISSING_ENV_VARS[@]}"
    printf "You must set these environment variables: %s\n" "${joined%,}"
    exit 1
  fi

  printf "Settings in use:\n"
  for var_name in "$@"; do
    if [[ "$var_name" == *_APIKEY || "$var_name" == *_API_KEY || "$var_name" == *_SECRET || "$var_name" == *_CLIENT_ID ]]; then
      local value="${!var_name}"
      printf "  %s=%s\n" "$var_name" "${value:0:4}..."
    else
      printf "  %s=%s\n" "$var_name" "${!var_name}"
    fi
  done
  printf "\n"
}

check_required_commands() {
  local missing
  missing=()
  for cmd in "$@"; do
    #printf "checking %s\n" "$cmd"
    if ! command -v "$cmd" &>/dev/null; then
      missing+=("$cmd")
    fi
  done
  # shellcheck disable=SC2128
  if [[ ${#missing[@]} -ne 0 ]]; then
    printf -v joined '%s,' "${missing[@]}"
    printf "\n\nThese commands are missing; they must be available on path: %s\nExiting.\n" "${joined%,}"
    exit 1
  fi
}

insure_apigeecli() {
  if [[ ! -f $HOME/.apigeecli/bin/apigeecli ]]; then
    echo "Installing apigeecli"
    curl -s https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | bash
  fi
  export PATH=$PATH:$HOME/.apigeecli/bin
}

is_role_present() {
  local search_role="$1"
  local -n role_array="$2" # -n creates a nameref to the array passed by name
  for element in "${role_array[@]}"; do
    if [[ "${element}" == "${search_role}" ]]; then
      return 0
    fi
  done
  return 1
}

get_sa_roles() {
  local sa_email project collected_roles LINE
  sa_email="$1"
  project="$2"
  local -n ref_array="$3"
  collected_roles=()
  while IFS= read -r LINE; do
    collected_roles+=("$LINE")
  done < <(gcloud projects get-iam-policy "${project}" \
    --flatten="bindings[].members" \
    --filter="bindings.members:${sa_email}" \
    --format="value(bindings.role)" 2>/dev/null)

  ref_array=("${collected_roles[@]}")

}
add_roles_to_service_account() {
  local sa_email project roles_var reqd_roles current_roles LINE role
  sa_email="$1"
  project="$2"
  roles_var="$3"

  declare -n reqd_roles="$roles_var"

  get_sa_roles "$sa_email" "$project" "current_roles"

  for role in "${reqd_roles[@]}"; do
    printf "\nChecking for '%s' role....\n" "${role}"
    if ! is_role_present "${role}" "current_roles"; then
      printf "Adding role '%s' for SA '%s'....\n" "${role}" "${sa_email}"
      gcloud projects add-iam-policy-binding "${project}" \
        --member="serviceAccount:${sa_email}" \
        --role="$role" --quiet >/dev/null
    else
      printf "Role '%s' is already applied to the service account.\n" "${role}"
    fi
  done
}

import_and_deploy_sharedflow() {
  local sharedflow_name project env sa_email sa_args sf_dir
  sharedflow_name=$1
  project=$2
  env=$3
  sa_email=$4

  sa_args=("")
  if [[ -n "$sa_email" ]]; then
    sa_args=("-s" "$sa_email")
  fi

  sf_dir="sharedflowbundles/${sharedflow_name}/sharedflowbundle"
  if [[ ! -d "$sf_dir" ]]; then
    echo "Error: import_and_deploy_sharedflow - missing sharedflow directory ${sf_dir} " >&2
    exit 1
  fi

  echo "Importing and deploying Shared Flow: $sharedflow_name"
  apigeecli sharedflows create bundle -n "$sharedflow_name" \
    -f "$sf_dir" -e "$env" --token "$TOKEN" -o "$project" "${sa_args[@]}" \
    --ovr --wait
}

import_and_deploy_apiproxy() {
  local proxy_name project env sa_email sa_args api_dir
  proxy_name=$1
  project=$2
  env=$3
  sa_email=$4

  sa_args=("")
  if [[ -n "$sa_email" ]]; then
    sa_args=("-s" "$sa_email")
  fi

  api_dir="proxybundles/${proxy_name}/apiproxy"
  if [[ ! -d "$api_dir" ]]; then
    echo "Error: import_and_deploy_apiproxy - missing proxy directory ${api_dir} " >&2
    exit 1
  fi

  echo "Importing and deploying Proxy: $proxy_name"
  apigeecli apis create bundle -n "$proxy_name" \
    -f "$api_dir" -e "$env" --token "$TOKEN" -o "$project" "${sa_args[@]}" \
    --ovr --wait
}

get_sedi_args() {
  # Check if a variable name was passed
  if [[ -z "$1" ]]; then
    echo "Error: get_sedi_args - must pass the name of the array to populate." >&2
    exit 1
  fi
  # shellcheck disable=SC2178
  local -n ref_array="$1"

  local args=("-i")
  if [[ "$(uname)" == "Darwin" ]]; then
    # For macOS, sed -i requires an extension argument. "" means no backup.
    args=("-i" "")
  fi

  # shellcheck disable=SC2034
  ref_array=("${args[@]}")
}

create_service_account_if_necessary() {
  local sa_shortname project sa_email display_name sa_args
  sa_shortname="$1"
  project="$2"
  display_name="$3"
  sa_args=("")
  if [[ -n "$display_name" ]]; then
    sa_args=("--display-name" "$display_name")
  fi

  sa_email="${sa_shortname}@${project}.iam.gserviceaccount.com"
  printf "Checking Service Account %s ...\n" "$sa_email"
  if gcloud iam service-accounts describe "${sa_email}" --project "$project" --quiet &>/dev/null; then
    printf "The service account %s already exists.\n" "$sa_email"
  else
    printf "Creating Service Account %s ..." "$sa_email"
    gcloud iam service-accounts create "$sa_shortname" --project "$project" "${sa_args[@]}"
    printf "There can be errors if all these changes happen too quickly, so we need to sleep a bit...\n"
    sleep 8
  fi
}

create_product_if_necessary() {
  local product_name project env ops_file
  product_name="$1"
  project="$2"
  env="$3"
  printf "\nCheck and maybe create the product %s...\n" "$product_name"
  if apigeecli products get --name "${product_name}" --org "$project" --token "$TOKEN" --disable-check &>/dev/null; then
    printf "  The apiproduct %s already exists!\n" "${product_name}"
  else
    echo "Creating API Product..."
    ops_file="./config/${product_name}-ops.json"
    if [[ ! -f "$ops_file" ]]; then
      printf "cannot find product ops file %s . exiting." "$ops_file" >&2
      exit 1
    fi
    apigeecli products create --name "${product_name}" --display-name "${product_name}" \
      --opgrp "$ops_file" --envs "$env" \
      --approval auto --org "$project" --token "$TOKEN"
  fi
}

create_developer_if_necessary() {
  local dev_moniker project label dev_email
  dev_moniker="$1"
  project="$2"
  label="$3"
  dev_email="${dev_moniker}@acme.com"

  printf "\nCheck and maybe create the developer...\n"
  if apigeecli developers get --email "${dev_email}" --org "$project" --token "$TOKEN" --disable-check &>/dev/null; then
    printf "  The developer %s already exists.\n" "$dev_email"
  else
    echo "Creating Developer %s ..." "$dev_email"
    apigeecli developers create --user "${dev_moniker}" \
      --email "$dev_email" --first="$label" \
      --last="Sample User" --org "$project" --token "$TOKEN"
  fi
}

create_app_if_necessary() {
  local app_name project product_name dev_email
  app_name="$1"
  project="$2"
  product_name="$3"
  dev_email="$4"
  printf "\nCheck and maybe create the app %s...\n" "$app_name"
  OUTPUT=$(apigeecli apps get --name "${app_name}" --org "$project" --token "$TOKEN" --disable-check 2>/dev/null)
  if [[ "$(echo "$OUTPUT" | jq -r 'type')" == "object" ]]; then
    echo "Creating Developer App..."
    apigeecli apps create --name "${app_name}" --email "${dev_email}" --prods "${product_name}" --org "$project" --token "$TOKEN" --disable-check
  else
    printf "The Developer App %s already exists." "$app_name"
  fi
  OUTPUT=$(apigeecli apps get --name "${app_name}" --org "$project" --token "$TOKEN" --disable-check 2>/dev/null)
  if [[ "$(echo "$OUTPUT" | jq -r 'type')" == "object" ]]; then
    printf "Something is wrong, the app has not been created...\n"
    exit 1
  fi
}

delete_app_if_necessary() {
  local app_name project dev_email dev_id
  app_name="$1"
  project="$2"
  dev_email="$3"
  printf "\nCheck and maybe delete the app %s...\n" "$app_name"
  OUTPUT=$(apigeecli apps get --name "${app_name}" --org "$project" --token "$TOKEN" --disable-check 2>/dev/null)
  if [[ "$(echo "$OUTPUT" | jq -r 'type')" == "object" ]]; then
    printf "  The Developer App %s does not exist.\n" "$app_name"
  else
    echo "  Deleting Developer App..."
    dev_id=$(apigeecli developers get --email "$dev_email" --org "$project" --token "$TOKEN" --disable-check | jq .'developerId' -r)
    apigeecli apps delete --id "$dev_id" --name "$app_name" --org "$project" --token "$TOKEN"
  fi
}

delete_developer_if_necessary() {
  local dev_email project
  dev_email="$1"
  project="$2"

  printf "\nCheck and maybe delete the developer %s...\n" "$dev_email"
  if apigeecli developers get --email "${dev_email}" --org "$project" --token "$TOKEN" --disable-check &>/dev/null; then
    echo "  Deleting Developer..."
    apigeecli developers delete --email "$dev_email" --org "$project" --token "$TOKEN"
  else
    printf "  The developer %s does not exist.\n" "$dev_email"
  fi
}

delete_product_if_necessary() {
  local product_name project
  product_name="$1"
  project="$2"
  printf "\nCheck and maybe delete the product %s...\n" "$product_name"
  if apigeecli products get --name "${product_name}" --org "$project" --token "$TOKEN" --disable-check &>/dev/null; then
    echo "   Deleting API Product..."
    apigeecli products delete --name "$product_name" --org "$project" --token "$TOKEN"
  else
    printf "  The apiproduct %s does not exist\n" "${product_name}"
  fi
}

delete_kvm_if_necessary() {
  local kvm_name project env
  kvm_name="$1"
  project="$2"
  env="$3"
  # ------------------------------------------------
  printf "\nCheck and maybe delete the KVM %s...\n" "$kvm_name"
  if apigeecli kvms list -e "${env}" -o "$project" --token "$TOKEN" | jq -e 'any(. == "'"$kvm_name"'")' >/dev/null; then
    echo "  Deleting KVM..."
    apigeecli kvms delete -n "$kvm_name" --env "$env" --org "$project" --token "$TOKEN"
  else
    echo "  The KVM $kvm_name does not exist..."
  fi
}

remove_roles_from_service_account() {
  # shellcheck disable=SC2034
  local sa_email project roles_var assnd_roles current_roles role LINE
  sa_email="$1"
  project="$2"
  roles_var="$3"

  declare -n assnd_roles="$roles_var"

  printf "\nChecking roles on service account %s ...\n" "$sa_email"
  if gcloud iam service-accounts describe "${sa_email}" --project="$project" --quiet &>/dev/null; then
    get_sa_roles "$sa_email" "$project" "current_roles"
    for role in "${assnd_roles[@]}"; do
      printf "\nChecking for '%s' role....\n" "${role}"
      if is_role_present "${role}" "current_roles"; then
        printf "Removing role '%s' for SA '%s'....\n" "${role}" "${sa_email}"
        gcloud projects remove-iam-policy-binding "$project" \
          --member="serviceAccount:${sa_email}" \
          --role="$role" &>/dev/null
      fi
    done
  else
    printf "  That service account does not exist.\n"
  fi
}

delete_deployable_asset() {
  local asset_type asset_name project collection envname rev outfile num_deploys
  asset_type="$1"
  asset_name="$2"
  project="$3"

  collection="${asset_type}s"

  printf "\nChecking %s %s\n" "$asset_type" "${asset_name}"
  if apigeecli "$collection" get --name "$asset_name" --org "$project" --token "$TOKEN" --disable-check &>/dev/null; then
    outfile=$(mktemp /tmp/apigee-samples.apigeecli.out.XXXXXX)
    if apigeecli "$collection" listdeploy --name "$asset_name" --org "$project" --token "$TOKEN" --disable-check >"$outfile" 2>&1; then
      num_deploys=$(jq -r '.deployments | length' "$outfile")
      if [[ $num_deploys -ne 0 ]]; then
        echo "Undeploying ${asset_name}"
        for ((i = 0; i < num_deploys; i++)); do
          envname=$(jq -r ".deployments[$i].environment" "$outfile")
          rev=$(jq -r ".deployments[$i].revision" "$outfile")
          apigeecli "$collection" undeploy --name "${asset_name}" --env "$envname" --rev "$rev" --org "$project" --token "$TOKEN" --disable-check
        done
      else
        printf "  There are no deployments of %s to remove.\n" "${asset_name}"
      fi
    fi
    [[ -f "$outfile" ]] && rm "$outfile"
    echo "Deleting ${asset_type} ${asset_name}"
    apigeecli "$collection" delete --name "${asset_name}" --org "$project" --token "$TOKEN" --disable-check
  else
    printf "  The %s %s does not exist.\n" "${asset_type}" "${asset_name}"
  fi
}

delete_apiproxy() {
  local proxy_name project
  proxy_name="$1"
  project="$2"
  delete_deployable_asset api "$proxy_name" "$project"
}

delete_sharedflow() {
  local sf_name project
  sf_name="$1"
  project="$2"
  delete_deployable_asset sharedflow "$sf_name" "$project"
}

delete_sa_if_necessary() {
  local sa_email project
  sa_email="$1"
  project="$2"
  printf "\nChecking Service Account %s...\n" "$sa_email"
  if gcloud iam service-accounts describe "${sa_email}" --project="$project" --quiet &>/dev/null; then
    printf "  Deleting the service account...\n"
    gcloud iam service-accounts delete "${sa_email}" --project "$project" --quiet
  else
    printf "  The service account %s does not exist.\n" "$sa_email"
  fi
}
