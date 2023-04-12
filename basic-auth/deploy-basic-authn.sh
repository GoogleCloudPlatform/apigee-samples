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
APP_NAME=basic-auth-sample-app

echo "Installing apigeecli"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/master/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

echo "Deploying Apigee artifacts..."

echo "Importing and Deploying Apigee sample-basic-auth proxy..."
REV=$(apigeecli apis create bundle -f ./apiproxy -n sample-basic-auth --org "$PROJECT" --token "$TOKEN" --disable-check | jq ."revision" -r)
apigeecli apis deploy --wait --name sample-basic-auth --ovr --rev "$REV" --org "$PROJECT" --env "$APIGEE_ENV" --token "$TOKEN"

echo "Creating API Product"
apigeecli products create --name basic-auth-sample-product --displayname "basic-auth-sample-product"  --envs "$APIGEE_ENV" --scopes "READ" --scopes "WRITE" --scopes "ACTION" --approval auto --quota 50 --interval 1 --unit minute --opgrp ./apiproduct-opgroup.json --org "$PROJECT" --token "$TOKEN"

echo "Creating Developer"
apigeecli developers create --user testuser --email basic-auth_apigeesamples@acme.com --first Test --last User --org "$PROJECT" --token "$TOKEN"

echo "Creating Developer App"
apigeecli apps create --name $APP_NAME --email basic-auth_apigeesamples@acme.com --prods basic-auth-sample-product --callback https://developers.google.com/oauthplayground/ --org "$PROJECT" --token "$TOKEN" --disable-check
apigeecli apps keys create --name $APP_NAME --dev basic-auth_apigeesamples@acme.com --prods basic-auth-sample-product --org "$PROJECT" --token "$TOKEN" --key "$USER_ID" --secret "$USER_PASSWORD" --disable-check

ENCODED_PAIR=$(printf '%s\n' "$USER_ID:$USER_PASSWORD" | base64)
BASIC_HEADER="Basic $ENCODED_PAIR"
echo " "
echo "All the Apigee artifacts are successfully deployed!"
echo " "
echo "Your USER_ID for testing is: $USER_ID"
echo " "
echo "Your USER_PASSWORD for testing is: $USER_PASSWORD"
echo " "
echo "Your Basic Authentication header value is: $BASIC_HEADER"
echo " "
echo "Your Sample Request URL is: https://$APIGEE_HOST/v1/samples/basic-auth"
echo " "
echo "Try this cURL request: curl -H 'Authorization: $BASIC_HEADER' https://$APIGEE_HOST/v1/samples/basic-auth"