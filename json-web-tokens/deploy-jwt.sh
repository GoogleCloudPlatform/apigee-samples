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

if ! [ -x "$(command -v jq)" ]; then
    echo "jq command is not on your PATH"
    exit
fi

if ! [ -x "$(command -v openssl)" ]; then
    echo "openssl command is not on your PATH"
    exit
fi

TOKEN=$(gcloud auth print-access-token)

echo "Installing dependencies"
npm install

echo "Installing apigeecli"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/master/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

echo "Running apigeelint"
npm run lint

echo "Deploying Apigee artifacts..."

echo "Importing and Deploying Apigee json-web-tokens proxy..."
REV=$(apigeecli apis create bundle -f apiproxy  -n json-web-tokens --org "$PROJECT" --token "$TOKEN" --disable-check | jq ."revision" -r)
apigeecli apis deploy --wait --name json-web-tokens --ovr --rev "$REV" --org "$PROJECT" --env "$APIGEE_ENV" --token "$TOKEN"

echo "Generating keypair..."
openssl genrsa -out private.pem 2048
openssl rsa -in private.pem -pubout -out public.pem

echo "Creating KVMs..."
apigeecli kvms create --org "$PROJECT" --env "$APIGEE_ENV" --name jwt-keys --token "$TOKEN"
apigeecli kvms entries create --org "$PROJECT" --env "$APIGEE_ENV" --map jwt-keys create --key rsa_privatekey --value "$(cat private.pem)" --token "$TOKEN"
apigeecli kvms entries create --org "$PROJECT" --env "$APIGEE_ENV" --map jwt-keys create --key rsa_publickey --value "$(cat public.pem)" --token "$TOKEN"

# var is expected by integration test (apickli)
export PROXY_URL="$APIGEE_HOST/v1/samples/json-web-tokens"

# integration tests
npm run test

echo " "
echo "All the Apigee artifacts are successfully deployed!"
echo " "
echo "Your Proxy URL is: https://$PROXY_URL"
echo "Run:"
echo "export PROXY_URL=$PROXY_URL"
echo "----------------------------------------------------------------"
echo " "
echo "To generate a signed JWT run the following request:"
echo " "
echo "curl -x POST https://$PROXY_URL/generate-signed"
echo " "
echo "To verify the signed JWT run the following request"
echo "using the token value generated above:"
echo " "
echo "curl -v GET https://$PROXY_URL/verify-signed -H 'Content-Type: application/x-www-form-urlencoded' --data-urlencode 'JWT=<JWT>'"
echo " "
echo "To generate an encrypted JWT run the following request:"
echo " "
echo "curl -v GET https://$PROXY_URL/generate-encrypted"
echo " "
echo "To verify the encrypted JWT run the following request"
echo "using the token value generated above:"
echo " "
echo "curl -v GET https://$PROXY_URL/verify-encrypted -H 'Content-Type: application/x-www-form-urlencoded' --data-urlencode 'JWT=<JWT>'"
echo " "