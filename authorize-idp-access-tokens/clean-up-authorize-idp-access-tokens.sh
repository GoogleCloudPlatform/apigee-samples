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

#echo "Enabling APIs..."
#gcloud services enable cloudbuild.googleapis.com

if [ -z "$PROJECT" ]; then
    echo "No PROJECT variable set"
    exit
fi

if [ -z "$APIGEE_ENV" ]; then
    echo "No APIGEE_ENV variable set"
    exit
fi

TOKEN=$(gcloud auth print-access-token)
APP_NAME=authz-idp-acccess-tokens-sample-app

echo "Installing apigeecli"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/master/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

echo "Deleting Developer App"
DEVELOPER_ID=$(apigeecli developers get --email authz-idp-acccess-tokens_apigeesamples@acme.com --org "$PROJECT" --token "$TOKEN" --disable-check | jq .'developerId' -r)
apigeecli apps delete --id "$DEVELOPER_ID" --name $APP_NAME --org "$PROJECT" --token "$TOKEN"

echo "Deleting Developer"
apigeecli developers delete --email authz-idp-acccess-tokens_apigeesamples@acme.com --org "$PROJECT" --token "$TOKEN"

echo "Deleting API Products"
apigeecli products delete --name authz-idp-acccess-tokens-sample-product --org "$PROJECT" --token "$TOKEN"

echo "Undeploying sample-authorize-idp-access-tokens proxy"
REV=$(apigeecli envs deployments get --env "$APIGEE_ENV" --org "$PROJECT" --token "$TOKEN" --disable-check | jq .'deployments[]| select(.apiProxy=="sample-authorize-idp-access-tokens").revision' -r)
apigeecli apis undeploy --name sample-authorize-idp-access-tokens --env "$APIGEE_ENV" --rev "$REV" --org "$PROJECT" --token "$TOKEN"

echo "Deleting proxy sample-authorize-idp-access-tokens proxy"
apigeecli apis delete --name sample-authorize-idp-access-tokens --org "$PROJECT" --token "$TOKEN"

rm sample-authorize-idp-access-tokens.zip

echo "Undeploying authorize-idp-access-tokens sharedflow"
REV=$(apigeecli envs deployments get --env "$APIGEE_ENV" --org "$PROJECT" --token "$TOKEN" --sharedflows true --disable-check | jq .'deployments[]| select(.apiProxy=="authorize-idp-access-tokens").revision' -r)
apigeecli sharedflows undeploy --name authorize-idp-access-tokens --env "$APIGEE_ENV" --rev "$REV" --org "$PROJECT" --token "$TOKEN"

echo "Deleting proxy authorize-idp-access-tokens sharedflow"
apigeecli sharedflows delete --name authorize-idp-access-tokens --org "$PROJECT" --token "$TOKEN"

rm authorize-idp-access-tokens.zip

echo "Deleting IdP config environemnt property set..."
apigeecli res delete --org "$PROJECT" --env "$APIGEE_ENV" --token "$TOKEN" --name idp_configuration --type properties

rm idp_configuration.properties