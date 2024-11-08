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
scriptid="deploy-cloud-logging"

source ./lib/utils.sh

# ====================================================================

check_shell_variables

TOKEN=$(gcloud auth print-access-token)

# check and maybe enable services
SERVICES_OF_INTEREST=( "logging.googleapis.com" )
for svc in "${SERVICES_OF_INTEREST[@]}"; do
    if gcloud services list --enabled --project $PROJECT --format="value(config.name)" --filter="config.name=$svc" > /dev/null ; then
        printf "%s is already enabled in the project...\n" "$svc"
    else
        printf "Attempting to enable %s...\n" "$svc"
        if gcloud services enable logging --project="$PROJECT" ; then
            printf "  done.\n"
        else
            printf "%s is not enabled, and the attempt to enable it failed. Cannot proceed.\n" "$svc"
            exit 1
        fi
    fi
done


# Creating and deleting an SA by the same name, repeatedly, can cause problems.
# This uses a random factor to uniquify the SA name.
# shellcheck disable=SC2002
rand_string=$(cat /dev/urandom | LC_CTYPE=C tr -cd '[:alnum:]' | head -c 6)
SA_NAME="${SA_BASE}${rand_string}"

create_service_account_and_grant_logWriter_role "$SA_NAME"
# the above implicitly sets SA_EMAIL

maybe_install_apigeecli

printf "Creating and Deploying Apigee sample-cloud-logging proxy...\n"
maybe_import_and_deploy ./apiproxy "$SA_EMAIL" "force"

# wait outside of the fn, in case there were multiple deploys
if [[ $need_wait -eq 1 ]]; then
    printf "Waiting...\n"
    wait
fi

printf "\nAll the Apigee artifacts are successfully deployed!\n\n"
printf "Generate some calls with:\n"
printf "  curl -i https://$APIGEE_HOST/v1/samples/cloud-logging\n\n"
printf "After that, make sure you read the logs from Cloud Logging with\n"
printf "  gcloud logging read \"logName=projects/$PROJECT/logs/apigee\"\n"
