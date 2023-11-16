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
DLP=https://dlp.googleapis.com
SA_NAME_PREFIX=samples-data-deid-

# creating and deleting the SA repeatedly causes problems?
# So I need to introduce a random factor into the SA
# shellcheck disable=SC2002
rand_string=$(cat /dev/urandom | LC_CTYPE=C tr -cd '[:alnum:]' | head -c 6)
SA_NAME=${SA_NAME_PREFIX}${rand_string}
SA_EMAIL=${SA_NAME}@${PROJECT}.iam.gserviceaccount.com

create_deid_template() {
    local template_name=$1 template_file
    template_file="./configuration-data/${template_name}.json"
    local TNAME
    [[ ! -f "$template_file" ]] && printf "missing template definition file %s\n" "$template_file" && exit 1
    TNAME=$(curl -s -X POST "${DLP}/v2/projects/${PROJECT}/deidentifyTemplates" \
        -H content-type:application/json \
        -H "Authorization: Bearer $TOKEN" -d @"${template_file}" | jq -r .name)
    # eg, projects/infinite-epoch-2900/deidentifyTemplates/3396177047123483279
    echo "$TNAME"
}

create_service_account() {
    local ARR NEEDED_ROLES
    echo "Creating service account $SA_NAME"
    gcloud iam service-accounts create "$SA_NAME"

    echo "Checking DLP permissions on service account"
    # shellcheck disable=SC2086
    ARR=($(gcloud projects get-iam-policy "${PROJECT}" \
        --flatten="bindings[].members" \
        --filter="bindings.members:${SA_EMAIL}" | grep -v deleted | grep -A 1 members | grep role | sed -e 's/role: //'))

    NEEDED_ROLES=("roles/dlp.deidentifyTemplatesReader" "roles/dlp.user")
    for role in "${NEEDED_ROLES[@]}"; do
        echo "Checking ${role}"
        # shellcheck disable=SC2076
        if ! [[ ${ARR[*]} =~ "$role" ]]; then
            echo "Adding ${role}"
            gcloud projects add-iam-policy-binding "${PROJECT}" \
                --member="serviceAccount:${SA_EMAIL}" \
                --role="$role" >>/dev/null 2>&1
        fi
    done

    gcloud projects get-iam-policy ${PROJECT} \
        --flatten="bindings[].members" \
        --filter="bindings.members:${SA_EMAIL}" | grep -v deleted | grep -A 1 members | grep role | sed -e 's/role: //'
}

[[ -z "$PROJECT" ]] && echo "No PROJECT variable set" && exit 1
[[ -z "$APIGEE_ENV" ]] && echo "No APIGEE_ENV variable set" && exit 1
[[ -z "$APIGEE_HOST" ]] && echo "No APIGEE_HOST variable set" && exit 1

TOKEN=$(gcloud auth print-access-token)

echo "Installing dependencies"
npm install

echo "Installing apigeecli"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/master/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

echo "Running apigeelint"
node_modules/apigeelint/cli.js -s ./bundle/apiproxy -f table.js --profile apigeex -e CC001

echo "Checking Service Account..."
create_service_account

WHOAMI=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
echo "Applying serviceAccountUser role for $SA_NAME to $WHOAMI..."
gcloud iam service-accounts add-iam-policy-binding "$SA_EMAIL" \
    --member="user:$WHOAMI" \
    --role="roles/iam.serviceAccountUser" >>/dev/null 2>&1

TOKEN=$(gcloud auth print-access-token)

echo "Creating DLP templates..."
TMPL1=$(create_deid_template "template-1-URL-Phone-Email")
TMPL2=$(create_deid_template "template-2-just-Email")

echo "Configuring Apigee artifacts..."

cat >./bundle/apiproxy/resources/properties/dlp.properties <<END_OF_TEXT
infotypes = { "name": "EMAIL_ADDRESS" }, { "name": "PHONE_NUMBER" }, { "name": "URL" }
deidentify_template1 = $TMPL1
deidentify_template2 = $TMPL2
project = ${PROJECT}
END_OF_TEXT

echo "Importing the Apigee proxy..."
REV=$(apigeecli apis create bundle -f "./bundle/apiproxy" -n "$PROXY_NAME" --org "$PROJECT" --token "$TOKEN" --disable-check | jq '.revision' -r)

TOKEN=$(gcloud auth print-access-token)
echo "Deploying the Apigee proxy..."
apigeecli apis deploy --wait --name "$PROXY_NAME" --ovr \
    --rev "$REV" --org "$PROJECT" --env "$APIGEE_ENV" \
    --token "$TOKEN" --sa "$SA_EMAIL" --disable-check

# Must export. This variable is expected by the integration tests (apickli).
export SAMPLE_PROXY_BASEPATH="/v1/samples/$PROXY_NAME"

# run the integration tests
npm run test

echo " "
echo "All the sample artifacts are successfully provisioned and deployed."
echo " "
echo "Copy/paste these statements into your shell to set the variable that"
echo "allows you to run the builtin tests."
echo " "
echo " export SAMPLE_PROXY_BASEPATH=\"/v1/samples/$PROXY_NAME\""
echo " "

echo "-----------------------------"
echo " "
echo "To test the API manually, invoke requests like the following:"
echo " "
echo "curl -i -X POST https://${APIGEE_HOST}${SAMPLE_PROXY_BASEPATH}/mask-xml -H content-type:application/xml -d @example-input.xml"
echo "curl -i -X POST https://${APIGEE_HOST}${SAMPLE_PROXY_BASEPATH}/mask-xml\\?justemail=true -H content-type:application/xml -d @example-input.xml"
echo "curl -i -X POST https://${APIGEE_HOST}${SAMPLE_PROXY_BASEPATH}/mask-json -H content-type:application/json -d @example-input.json"
echo "curl -i -X POST https://${APIGEE_HOST}${SAMPLE_PROXY_BASEPATH}/mask-json\\?justemail=true -H content-type:application/json -d @example-input.json"
echo " "
