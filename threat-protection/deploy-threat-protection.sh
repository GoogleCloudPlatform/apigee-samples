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

echo "Installing dependencies"
npm install

echo "Installing apigeecli"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/master/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

echo "Running apigeelint"
npm run lint

echo "Deploying Apigee artifacts..."

echo "Importing and Deploying Apigee threat-protection proxy..."
REV=$(apigeecli apis create bundle -f apiproxy -n threat-protection --org "$PROJECT" --token "$TOKEN" --disable-check | jq ."revision" -r)
apigeecli apis deploy --wait --name threat-protection --ovr --rev "$REV" --org "$PROJECT" --env "$APIGEE_ENV" --token "$TOKEN"

#echo "Creating API Products"
#apigeecli products create --name basic-quota-trial --displayname "basic-quota-trial" --opgrp ./basic-quota-product-ops.json --envs "$APIGEE_ENV" --approval auto --quota 10 --interval 1 --unit minute --org "$PROJECT" --token "$TOKEN"
#apigeecli products create --name basic-quota-premium --displayname "basic-quota-premium" --opgrp ./basic-quota-product-ops.json --envs "$APIGEE_ENV" --approval auto --quota 1000 --interval 1 --unit hour --org "$PROJECT" --token "$TOKEN"

#echo "Creating Developer"
#apigeecli developers create --user testuser --email basic-quota_apigeesamples@acme.com --first Test --last User --org "$PROJECT" --token "$TOKEN"

#echo "Creating Developer Apps"
#apigeecli apps create --name basic-quota-trial-app --email basic-quota_apigeesamples@acme.com --prods basic-quota-trial --org "$PROJECT" --token "$TOKEN" --disable-check
#apigeecli apps create --name basic-quota-premium-app --email basic-quota_apigeesamples@acme.com --prods basic-quota-premium --org "$PROJECT" --token "$TOKEN" --disable-check

#CLIENT_ID_1=$(apigeecli apps get --name basic-quota-trial-app --org "$PROJECT" --token "$TOKEN" --disable-check | jq ."[0].credentials[0].consumerKey" -r)
#export CLIENT_ID_1

#CLIENT_ID_2=$(apigeecli apps get --name basic-quota-premium-app --org "$PROJECT" --token "$TOKEN" --disable-check | jq ."[0].credentials[0].consumerKey" -r)
#export CLIENT_ID_2

# var is expected by integration test (apickli)
export PROXY_URL="$APIGEE_HOST/v1/threat-protection"

# integration tests

npm run test

echo " "
echo "All the Apigee artifacts are successfully deployed!"
echo " "
echo "Your Proxy URL is: https://$PROXY_URL"
echo "-----------------------------"
echo " "
echo "To test the API Proxy:"
echo " "
echo "curl -X GET https://$PROXY_URL/json?query=delete"
echo "curl -X GET https://$PROXY_URL/json?query=select"
echo "curl -X POST 'https://$PROXY_URL/echo' -H 'Content-Type: application/json' -d '{\"field1\": \"test_value1\", \"field2\": \"test_value2\", \"field3]\": \"test_value3\", \"field4\": \"test_value4\", \"field5\": \"test_value5\", \"field6\": \"test_value6\"}'"
echo "curl -X POST 'https://$PROXY_URL/echo' -H 'Content-Type: application/json' -d '{\"field1\": \"test_value1\", \"field2\": \"test_value2\", \"field3]\": \"test_value3\", \"field4\": \"test_value4\", \"field5\": \"test_value5\"}'"
