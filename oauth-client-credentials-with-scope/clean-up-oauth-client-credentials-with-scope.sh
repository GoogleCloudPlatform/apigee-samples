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

if [ -z "$APIGEE_HOST" ]; then
    echo "No APIGEE_HOST variable set"
    exit
fi

TOKEN=$(gcloud auth print-access-token)
APP_NAME_READ_SCOPE=oauth-client-credentials-app-with-read-scope
APP_NAME_WRITE_SCOPE=oauth-client-credentials-app-with-write-scope

echo "Installing apigeecli"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/master/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

echo "Deleting Developer App"
DEVELOPER_ID=$(apigeecli developers get --email oauth-client-credentials-with-scope_apigeesamples@acme.com --org "$PROJECT" --token "$TOKEN" --disable-check | jq .'developerId' -r)
apigeecli apps delete --id "$DEVELOPER_ID" --name $APP_NAME_READ_SCOPE --org "$PROJECT" --token "$TOKEN"
apigeecli apps delete --id "$DEVELOPER_ID" --name $APP_NAME_WRITE_SCOPE --org "$PROJECT" --token "$TOKEN"

echo "Deleting Developer"
apigeecli developers delete --email oauth-client-credentials-with-scope_apigeesamples@acme.com --org "$PROJECT" --token "$TOKEN"

echo "Deleting API Products"
apigeecli products delete --name oauth-client-credentials-product-with-read-scope --org "$PROJECT" --token "$TOKEN"
apigeecli products delete --name oauth-client-credentials-product-with-write-scope --org "$PROJECT" --token "$TOKEN"

echo "Undeploying oauth-client-credentials-with-scope"
REV=$(apigeecli envs deployments get --env "$APIGEE_ENV" --org "$PROJECT" --token "$TOKEN" --disable-check | jq .'deployments[]| select(.apiProxy=="oauth-client-credentials-with-scope").revision' -r)
apigeecli apis undeploy --name oauth-client-credentials-with-scope --env "$APIGEE_ENV" --rev "$REV" --org "$PROJECT" --token "$TOKEN"

echo "Deleting proxy oauth-client-credentials-with-scope"
apigeecli apis delete --name oauth-client-credentials-with-scope --org "$PROJECT" --token "$TOKEN"