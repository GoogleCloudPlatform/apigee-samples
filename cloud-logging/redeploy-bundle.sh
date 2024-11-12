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
# shellcheck disable=SC2034
PROXY_NAME="sample-cloud-logging"
# shellcheck disable=SC2034
scriptid="redeploy-bundle"

source ./lib/utils.sh

# ====================================================================

MISSING_ENV_VARS=()
[[ -z "$PROJECT" ]] && MISSING_ENV_VARS+=('PROJECT')
[[ -z "$APIGEE_ENV" ]] && MISSING_ENV_VARS+=('APIGEE_ENV')
[[ -z "$APIGEE_HOST" ]] && MISSING_ENV_VARS+=('APIGEE_HOST')

[[ ${#MISSING_ENV_VARS[@]} -ne 0 ]] && {
  printf -v joined '%s,' "${MISSING_ENV_VARS[@]}"
  printf "You must set these environment variables: %s\n" "${joined%,}"
  exit 1
}

# shellcheck disable=SC2034
TOKEN=$(gcloud auth print-access-token)

maybe_install_apigeecli

# shellcheck disable=SC2034
SA_NAME=$(<./.sa_name)
need_sa=0
if [[ -z "$SA_NAME" ]]; then
  need_sa=1
else
  SA_EMAIL="${SA_NAME}@${PROJECT}.iam.gserviceaccount.com"
  if gcloud iam service-accounts describe "$SA_EMAIL" >/dev/null; then
    printf "Found existing SA [%s]\n" "$SA_EMAIL"
  else
    need_sa=1
  fi
fi

if [[ $need_sa -eq 1 ]]; then
  # shellcheck disable=SC2002
  rand_string=$(cat /dev/urandom | LC_CTYPE=C tr -cd '[:alnum:]' | head -c 6)
  SA_NAME="${SA_BASE}${rand_string}"
  create_service_account_and_grant_logWriter_role "$SA_NAME"
  # the above implicitly sets SA_EMAIL
fi

printf "Checking if proxy needs to be redeployed...\n"
maybe_import_and_deploy ./apiproxy "$SA_EMAIL"

# wait outside of the fn, in case there were multiple deploys
# shellcheck disable=SC2154
if [[ $need_wait -eq 1 ]]; then
  printf "Waiting...\n"
  wait
  printf "redeployed...\n"
else
  printf "redeploy was not necessary...\n"
fi
