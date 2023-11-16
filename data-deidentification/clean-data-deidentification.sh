#!/bin/bash

# Copyright 2023 Google LLC
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

PROXY_NAME=data-deidentification
SA_NAME_PREFIX=samples-data-deid-
DLP=https://dlp.googleapis.com

delete_apiproxy() {
    local proxy_name=$1
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

remove_sample_deid_templates() {
    local ARR name OUTFILE nextPageToken="start" query=""

    OUTFILE=$(mktemp /tmp/apigee-samples.data-deid.curl.out.XXXXXX)

    # The template list can be paged, so we need to iterate.
    while [[ -n $nextPageToken ]]; do

        #echo "GET ${DLP}/v2/projects/${PROJECT}/deidentifyTemplates${query}"

        # list the templates
        curl -s -H "Authorization: Bearer $TOKEN" \
            -H "x-goog-user-project: $PROJECT" \
            -H 'content-type: application/json' \
            -X GET "${DLP}/v2/projects/${PROJECT}/deidentifyTemplates${query}" >"$OUTFILE" 2>&1

        # filter that list to select those with apigee-deid-sample in the description
        mapfile -t ARR < <(jq -r '.deidentifyTemplates[]? | select( .description | test("^apigee-deid-sample.+") ) | .name ' "$OUTFILE")

        if [[ ${#ARR[@]} -gt 0 ]]; then
            # Delete those
            for name in "${ARR[@]}"; do
                echo "Delete DLP de-identify template ${name}"
                curl -s -H "Authorization: Bearer $TOKEN" \
                    -H "x-goog-user-project: $PROJECT" \
                    -H 'content-type: application/json' \
                    -X DELETE "${DLP}/v2/${name}" >>/dev/null 2>&1
            done
        fi

        # get the next page token
        nextPageToken=$(jq -r '.nextPageToken | ""' "$OUTFILE")
        if [[ -z $nextPageToken ]]; then
            query=""
        else
            query="?pageToken=${nextPageToken}"
        fi
    done

    [[ -f "$OUTFILE" ]] && rm "$OUTFILE"
}

[[ -z "$PROJECT" ]] && echo "No PROJECT variable set" && exit 1
[[ -z "$APIGEE_ENV" ]] && echo "No APIGEE_ENV variable set" && exit 1
[[ -z "$APIGEE_HOST" ]] && echo "No APIGEE_HOST variable set" && exit 1

TOKEN=$(gcloud auth print-access-token)

echo "Installing apigeecli"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/master/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

delete_apiproxy "${PROXY_NAME}"

echo "Checking service account"

mapfile -t ARR < <(gcloud iam service-accounts list | grep $SA_NAME_PREFIX | sed -e 's/EMAIL: //')
if [[ ${#ARR[@]} -gt 0 ]]; then
    # Delete those
    for sa in "${ARR[@]}"; do
        echo "Deleting service account ${sa}"
        gcloud --quiet iam service-accounts delete "${sa}"
    done
fi

echo "Removing sample De-Identification templates"
remove_sample_deid_templates

echo " "
echo "All the artifacts for this sample have now been removed."
echo " "
