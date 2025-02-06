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

SA_BASE="example-cloudlogger-sa-"
PROXY_NAME="sample-cloud-logging"

delete_apiproxy() {
  local proxy_name=$1
  local ENVNAME REV OUTFILE NUM_DEPLOYS
  printf "Checking Proxy %s\n" "${proxy_name}"
  if apigeecli apis get --name "$proxy_name" --org "$PROJECT" --token "$TOKEN" --disable-check >/dev/null 2>&1; then
    OUTFILE=$(mktemp /tmp/apigee-samples.apigeecli.out.XXXXXX)
    if apigeecli apis listdeploy --name "$proxy_name" --org "$PROJECT" --token "$TOKEN" --disable-check >"$OUTFILE" 2>&1; then
      NUM_DEPLOYS=$(jq -r '.deployments | length' "$OUTFILE")
      if [[ $NUM_DEPLOYS -ne 0 ]]; then
        echo "Undeploying ${proxy_name}"
        for ((i = 0; i < NUM_DEPLOYS; i++)); do
          ENVNAME=$(jq -r ".deployments[$i].environment" "$OUTFILE")
          REV=$(jq -r ".deployments[$i].revision" "$OUTFILE")
          apigeecli apis undeploy --name "${proxy_name}" --env "$ENVNAME" --rev "$REV" --org "$PROJECT" --token "$TOKEN" --disable-check
        done
      else
        printf "  There are no deployments of %s to remove.\n" "${proxy_name}"
      fi
    fi
    [[ -f "$OUTFILE" ]] && rm "$OUTFILE"

    echo "Deleting proxy ${proxy_name}"
    apigeecli apis delete --name "${proxy_name}" --org "$PROJECT" --token "$TOKEN" --disable-check

  else
    printf "  The proxy %s does not exist.\n" "${proxy_name}"
  fi
}

# ====================================================================

MISSING_ENV_VARS=()
[[ -z "$PROJECT" ]] && MISSING_ENV_VARS+=('PROJECT')
[[ -z "$APIGEE_ENV" ]] && MISSING_ENV_VARS+=('APIGEE_ENV')

[[ ${#MISSING_ENV_VARS[@]} -ne 0 ]] && {
  printf -v joined '%s,' "${MISSING_ENV_VARS[@]}"
  printf "You must set these environment variables: %s\n" "${joined%,}"
  exit 1
}

TOKEN=$(gcloud auth print-access-token)

maybe_install_apigeecli

delete_apiproxy "${PROXY_NAME}"

printf "Removing IAM Policy Bindings\n"
ROLES_OF_INTEREST=("roles/logging.logWriter")
for role in "${ROLES_OF_INTEREST[@]}"; do
  printf "Checking role %s\n" "$role"
  # shellcheck disable=SC2207
  members=($(gcloud projects get-iam-policy "$PROJECT" --format=json |
    jq --arg r "$role" '.bindings[] | select( .role == $r )' | jq --arg prefix "$SA_BASE" '.members[] | select(contains("serviceAccount:") and contains($prefix))' | sed -e 's/"//g'))

  for member in "${members[@]}"; do
    printf "  Removing IAM binding for %s\n" "$member"
    gcloud projects remove-iam-policy-binding "${PROJECT}" \
      --member="$member" \
      --role="$role" >>/dev/null
  done
done

printf "Checking service account(s)\n"
mapfile -t ARR < <(gcloud iam service-accounts list --project "$PROJECT" --format="value(email)" | grep $SA_BASE)
if [[ ${#ARR[@]} -gt 0 ]]; then
  for sa in "${ARR[@]}"; do
    printf "Deleting service account %s\n" "${sa}"
    gcloud --quiet iam service-accounts delete "${sa}" --project "$PROJECT"
  done
else
  printf "  No service accounts to delete.\n"
fi
[[ -f "./.sa_name" ]] && rm -f ./.sa_name
