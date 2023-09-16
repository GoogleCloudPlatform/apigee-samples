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
APP_NAME=oauth-client-credentials-app

echo "Installing apigeecli"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/master/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

echo "Deleting Developer App"
DEVELOPER_ID=$(apigeecli developers get --email oauth-client-credentials_apigeesamples@acme.com --org "$PROJECT" --token "$TOKEN" --disable-check | jq .'developerId' -r)
apigeecli apps delete --id "$DEVELOPER_ID" --name $APP_NAME --org "$PROJECT" --token "$TOKEN"

echo "Deleting Developer"
apigeecli developers delete --email oauth-client-credentials_apigeesamples@acme.com --org "$PROJECT" --token "$TOKEN"

echo "Deleting API Products"
apigeecli products delete --name oauth-client-credentials-product --org "$PROJECT" --token "$TOKEN"

echo "Undeploying oauth-client-credentials"
REV=$(apigeecli envs deployments get --env "$APIGEE_ENV" --org "$PROJECT" --token "$TOKEN" --disable-check | jq .'deployments[]| select(.apiProxy=="oauth-client-credentials").revision' -r)
apigeecli apis undeploy --name oauth-client-credentials --env "$APIGEE_ENV" --rev "$REV" --org "$PROJECT" --token "$TOKEN"

echo "Deleting proxy oauth-client-credentials"
apigeecli apis delete --name oauth-client-credentials --org "$PROJECT" --token "$TOKEN"
