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

if [ -z "$CLOUD_RUN_SERVICE_URL" ]; then
  echo "No CLOUD_RUN_SERVICE_URL variable set"
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
echo "Deploying target server for the Cloud Run service $CLOUD_RUN_SERVICE_URL..."
apigeecli targetservers create -n websockets --org "$PROJECT" --env "$APIGEE_ENV" --token "$TOKEN" -p 443 -s "$CLOUD_RUN_SERVICE_URL" --tls

echo "Importing and Deploying Apigee websockets proxy..."
REV=$(apigeecli apis create bundle -f apiproxy -n websockets --org "$PROJECT" --token "$TOKEN" --disable-check | jq ."revision" -r)
apigeecli apis deploy --wait --name websockets --ovr --rev "$REV" --org "$PROJECT" --env "$APIGEE_ENV" --token "$TOKEN"

echo "Creating API Products"
apigeecli products create --name websockets --displayname "websockets" --envs "$APIGEE_ENV" --approval auto --org "$PROJECT" --token "$TOKEN"

echo "Creating Developer"
apigeecli developers create --user testuser --email websockets_apigeesamples@acme.com --first Test --last User --org "$PROJECT" --token "$TOKEN"

echo "Creating Developer App"
apigeecli apps create --name websocketsApp --email websockets_apigeesamples@acme.com --prods websockets --org "$PROJECT" --token "$TOKEN" --disable-check

CLIENT_ID=$(apigeecli apps get --name websocketsApp --org "$PROJECT" --token "$TOKEN" --disable-check | jq ."[0].credentials[0].consumerKey" -r)
export CLIENT_ID

# var is expected by integration test (apickli)
export PROXY_URL="$APIGEE_HOST/v1/samples/websockets"

# integration tests

npm run test

echo " "
echo "All the Apigee artifacts are successfully deployed!"
echo " "
echo "Your Proxy URL is: wss://$PROXY_URL"
echo " "
echo "-----------------------------"
echo " "
echo "To call the API use wscat or another websockets client:"
echo " "
echo "wscat -c wss://$PROXY_URL?apikey=$CLIENT_ID"
echo " "
