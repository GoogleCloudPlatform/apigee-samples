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

echo "Installing dependencies"
npm install

echo "Installing apigeecli"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/master/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

echo "Running apigeelint"
npm run lint

echo "Deploying Apigee artifacts..."
rm oauth-client-credentials.zip
zip -r oauth-client-credentials.zip apiproxy

echo "Importing and Deploying Apigee oauth-client-credentials proxy..."
REV=$(apigeecli apis import -f oauth-client-credentials.zip --org "$PROJECT" --token "$TOKEN" --disable-check | jq ."revision" -r)
apigeecli apis deploy --wait --name oauth-client-credentials --ovr --rev "$REV" --org "$PROJECT" --env "$APIGEE_ENV" --token "$TOKEN"

echo "Creating API Product"
apigeecli products create --name oauth-client-credentials-product --displayname "oauth-client-credentials-product" --opgrp ./oauth-client-credentials-product-ops.json --envs "$APIGEE_ENV" --approval auto --quota 10 --interval 1 --unit minute --org "$PROJECT" --token "$TOKEN"

echo "Creating Developer"
apigeecli developers create --user testuser --email oauth-client-credentials_apigeesamples@acme.com --first Test --last User --org "$PROJECT" --token "$TOKEN"

echo "Creating Developer App"
apigeecli apps create --name $APP_NAME --email oauth-client-credentials_apigeesamples@acme.com --prods oauth-client-credentials-product --org "$PROJECT" --token "$TOKEN" --disable-check

APP_CLIENT_ID=$(apigeecli apps get --name $APP_NAME --org "$PROJECT" --token "$TOKEN" --disable-check | jq ."[0].credentials[0].consumerKey" -r)
export APP_CLIENT_ID

APP_CLIENT_SECRET=$(apigeecli apps get --name $APP_NAME --org "$PROJECT" --token "$TOKEN" --disable-check | jq ."[0].credentials[0].consumerSecret" -r)
export APP_CLIENT_SECRET

# var is expected by integration test (apickli)
export PROXY_URL="$APIGEE_HOST/v1/samples/oauth-client-credentials"

# integration tests

npm run test

echo " "
echo "All the Apigee artifacts are successfully deployed!"
echo " "
echo "Your Proxy URL is: https://$PROXY_URL"
echo "Your app client id is: $APP_CLIENT_ID"
echo "Your app client secret is: $APP_CLIENT_SECRET"
echo " "
echo "-----------------------------"
echo " "
echo "To obtain a short-lived opaque access token using the token endpoint, try the following command:"
echo " "
echo "curl -v POST https://$PROXY_URL/token -u $APP_CLIENT_ID:$APP_CLIENT_SECRET -d \"grant_type=client_credentials\" "
echo " "
echo "Then, to access the protected resource, copy the value of the access_token property"
echo "from the response body of the previous request and include it in the following request:"
echo " "
echo "curl -v GET https://$PROXY_URL/resource -H \"Authorization: Bearer access_token\" "
echo " "
