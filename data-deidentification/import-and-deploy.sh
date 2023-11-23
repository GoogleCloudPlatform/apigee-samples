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

PROXY_NAME="data-deidentification"
SA_NAME="unset"
SA_EMAIL="unset"

get_service_account() {
  local cached_sa_name
  cached_sa_name=$(<./.sa_name)
  SA_NAME="${cached_sa_name}"
  SA_EMAIL="${SA_NAME}@${PROJECT}.iam.gserviceaccount.com"
  gcloud projects get-iam-policy "${PROJECT}" \
    --flatten="bindings[].members" \
    --filter="bindings.members:${SA_EMAIL}" | grep -v deleted | grep -A 1 members | grep role | sed -e 's/role: //'
}

[[ -z "$PROJECT" ]] && echo "No PROJECT variable set" && exit 1
[[ -z "$APIGEE_ENV" ]] && echo "No APIGEE_ENV variable set" && exit 1
[[ -z "$APIGEE_HOST" ]] && echo "No APIGEE_HOST variable set" && exit 1

echo "Setting path for apigeecli"
! [[ -d $HOME/.apigeecli/bin ]] && echo "apigeecli is not installed" && exit 1

export PATH=$PATH:$HOME/.apigeecli/bin

TOKEN=$(gcloud auth print-access-token)

echo "Checking Service Account..."
get_service_account

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
