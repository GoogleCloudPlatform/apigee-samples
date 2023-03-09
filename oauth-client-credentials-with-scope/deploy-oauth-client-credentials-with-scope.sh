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
APP_NAME_READ_SCOPE=oauth-client-credentials-app-with-read-scope
APP_NAME_WRITE_SCOPE=oauth-client-credentials-app-with-write-scope

echo "Installing dependencies"
npm install

echo "Running apigeelint"
npm run lint

echo "Installing apigeecli"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/master/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

echo "Deploying Apigee artifacts..."

echo "Importing and Deploying Apigee oauth-client-credentials-with-scope proxy..."
REV=$(apigeecli apis create bundle -f apiproxy  -n oauth-client-credentials-with-scope --org "$PROJECT" --token "$TOKEN" --disable-check | jq ."revision" -r)
apigeecli apis deploy --wait --name oauth-client-credentials-with-scope --ovr --rev "$REV" --org "$PROJECT" --env "$APIGEE_ENV" --token "$TOKEN"

echo "Creating API Products"
apigeecli products create --name oauth-client-credentials-product-with-read-scope --displayname "oauth-client-credentials-product-with-read-scope" --opgrp ./oauth-client-credentials-product-ops.json --envs "$APIGEE_ENV" --approval auto --quota 10 --interval 1 --unit minute --org "$PROJECT" --token "$TOKEN" --scopes "read"
apigeecli products create --name oauth-client-credentials-product-with-write-scope --displayname "oauth-client-credentials-product-with-write-scope" --opgrp ./oauth-client-credentials-product-ops.json --envs "$APIGEE_ENV" --approval auto --quota 10 --interval 1 --unit minute --org "$PROJECT" --token "$TOKEN" --scopes "read" --scopes "write"

echo "Creating Developer"
apigeecli developers create --user testuser --email oauth-client-credentials-with-scope_apigeesamples@acme.com --first Test --last User --org "$PROJECT" --token "$TOKEN"

echo "Creating Developer Apps"
apigeecli apps create --name $APP_NAME_READ_SCOPE --email oauth-client-credentials-with-scope_apigeesamples@acme.com --prods oauth-client-credentials-product-with-read-scope --org "$PROJECT" --token "$TOKEN" --disable-check
apigeecli apps create --name $APP_NAME_WRITE_SCOPE --email oauth-client-credentials-with-scope_apigeesamples@acme.com --prods oauth-client-credentials-product-with-write-scope --org "$PROJECT" --token "$TOKEN" --disable-check

APP_READ_SCOPE_CLIENT_ID=$(apigeecli apps get --name $APP_NAME_READ_SCOPE --org "$PROJECT" --token "$TOKEN" --disable-check | jq ."[0].credentials[0].consumerKey" -r)
export APP_READ_SCOPE_CLIENT_ID
APP_READ_SCOPE_CLIENT_SECRET=$(apigeecli apps get --name $APP_NAME_READ_SCOPE --org "$PROJECT" --token "$TOKEN" --disable-check | jq ."[0].credentials[0].consumerSecret" -r)
export APP_READ_SCOPE_CLIENT_SECRET

APP_WRITE_SCOPE_CLIENT_ID=$(apigeecli apps get --name $APP_NAME_WRITE_SCOPE --org "$PROJECT" --token "$TOKEN" --disable-check | jq ."[0].credentials[0].consumerKey" -r)
export APP_WRITE_SCOPE_CLIENT_ID
APP_WRITE_SCOPE_CLIENT_SECRET=$(apigeecli apps get --name $APP_NAME_WRITE_SCOPE --org "$PROJECT" --token "$TOKEN" --disable-check | jq ."[0].credentials[0].consumerSecret" -r)
export APP_WRITE_SCOPE_CLIENT_SECRET

# var is expected by integration test (apickli)
export PROXY_URL="$APIGEE_HOST/v1/samples/oauth-client-credentials-with-scope"

# integration tests
npm run test

echo " "
echo "All the Apigee artifacts are successfully deployed!"
echo " "
echo "Your Proxy URL is: https://$PROXY_URL"
echo "Your app client id with read scope is: $APP_READ_SCOPE_CLIENT_ID"
echo "Your app client secret with read scope is: $APP_READ_SCOPE_CLIENT_SECRET"
echo " "
echo "Your app client id with write scope is: $APP_WRITE_SCOPE_CLIENT_ID"
echo "Your app client secret with write scope is: $APP_WRITE_SCOPE_CLIENT_SECRET"
echo " "
echo "-----------------------------"
echo " "
echo "Generating a read scope token using $APP_NAME_READ_SCOPE credentials"
READ_TOKEN=$(curl -s POST https://$PROXY_URL/token -u $APP_READ_SCOPE_CLIENT_ID:$APP_READ_SCOPE_CLIENT_SECRET -d "grant_type=client_credentials&scope=read" | jq ."access_token" -r )
export READ_TOKEN
echo " "
echo "Then, to access the protected resource, run the following curl commands"
echo " "
echo "curl -s GET https://$PROXY_URL/resource -H \"Authorization: Bearer $READ_TOKEN\" | jq ."
echo " "
echo "curl -s -X POST https://$PROXY_URL/resource -H \"Authorization: Bearer $READ_TOKEN\" | jq ."
echo " "
echo "-----------------------------"
echo " "
echo "Generating a write scope token using $APP_NAME_WRITE_SCOPE credentials"
WRITE_TOKEN=$(curl -s POST https://$PROXY_URL/token -u $APP_WRITE_SCOPE_CLIENT_ID:$APP_WRITE_SCOPE_CLIENT_SECRET -d "grant_type=client_credentials&scope=write" | jq ."access_token" -r )
export WRITE_TOKEN
echo " "
echo "Then, to access the protected resource, run the following curl commands"
echo " "
echo "curl -s GET https://$PROXY_URL/resource -H \"Authorization: Bearer $WRITE_TOKEN\" | jq ."
echo " "
echo "curl -s -X POST https://$PROXY_URL/resource -H \"Authorization: Bearer $WRITE_TOKEN\" | jq ."
echo " "