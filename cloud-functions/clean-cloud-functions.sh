#!/bin/bash

# Copyright 2024 Google LLC
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

delete_service_account() {
    local sa_email="$1" project="$2"
    if gcloud iam service-accounts describe "$sa_email" --project="$project" >/dev/null 2>&1; then
        gcloud iam service-accounts delete "$sa_email" --project="$project" --quiet
    else
        printf "  That service account does not exist.\n"
    fi
}

delete_apiproxy() {
    local proxy_name=$1
    printf "Checking Proxy %s\n" "${proxy_name}"
    if apigeecli apis get --name "$proxy_name" --org "$APIGEE_PROJECT" --token "$TOKEN" --disable-check >/dev/null 2>&1; then
        OUTFILE=$(mktemp /tmp/apigee-samples.apigeecli.out.XXXXXX)
        if apigeecli apis listdeploy --name "$proxy_name" --org "$APIGEE_PROJECT" --token "$TOKEN" --disable-check >"$OUTFILE" 2>&1; then
            NUM_DEPLOYS=$(jq -r '.deployments | length' "$OUTFILE")
            if [[ $NUM_DEPLOYS -ne 0 ]]; then
                echo "Undeploying ${proxy_name}"
                for ((i = 0; i < NUM_DEPLOYS; i++)); do
                    ENVNAME=$(jq -r ".deployments[$i].environment" "$OUTFILE")
                    REV=$(jq -r ".deployments[$i].revision" "$OUTFILE")
                    apigeecli apis undeploy --name "${proxy_name}" --env "$ENVNAME" --rev "$REV" --org "$APIGEE_PROJECT" --token "$TOKEN" --disable-check
                done
            else
                printf "  There are no deployments of %s to remove.\n" "${proxy_name}"
            fi
        fi
        [[ -f "$OUTFILE" ]] && rm "$OUTFILE"

        echo "Deleting proxy ${proxy_name}"
        apigeecli apis delete --name "${proxy_name}" --org "$APIGEE_PROJECT" --token "$TOKEN" --disable-check

    else
        printf "  The proxy %s does not exist.\n" "${proxy_name}"
    fi
}

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

TOKEN=$(gcloud auth print-access-token)

printf "Installing apigeecli\n"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

delete_apiproxy "${PROXY_NAME}"

printf "Deleting the proxy service account...\n"
PROXY_SA_NAME=proxy-apigee-sample-sa-1
PROXY_SA_EMAIL="${PROXY_SA_NAME}@${APIGEE_PROJECT}.iam.gserviceaccount.com"
delete_service_account "$PROXY_SA_EMAIL" "$APIGEE_PROJECT"

printf "Deleting the cloud function...\n"
if gcloud functions describe "$CLOUD_FUNCTION_NAME" --region="$CLOUD_FUNCTIONS_REGION" --project="$CLOUD_FUNCTIONS_PROJECT" >/dev/null 2>&1; then
    gcloud functions delete "$CLOUD_FUNCTION_NAME" \
        --region="$CLOUD_FUNCTIONS_REGION" \
        --project="$CLOUD_FUNCTIONS_PROJECT" \
        --quiet
else
    printf "  That Cloud function does not exist.\n"
fi

printf "Deleting the cloud function service account...\n"
CF_SA_NAME=cf-apigee-sample-sa-1
CF_SA_EMAIL="${CF_SA_NAME}@${CLOUD_FUNCTIONS_PROJECT}.iam.gserviceaccount.com"
delete_service_account "${CF_SA_EMAIL}" "$CLOUD_FUNCTIONS_PROJECT"

printf "\nAll the artifacts for this sample have been removed.\n"
