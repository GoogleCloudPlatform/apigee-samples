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

if [ -z "$PROJECT" ]
then
echo "No PROJECT variable set"
exit
fi


if [ -z "$APIGEE_ENV" ]
then
echo "No APIGEE_ENV variable set"
exit
fi

if [ -z "$APIGEE_HOST" ]
then
echo "No APIGEE_HOST variable set"
exit
fi

TOKEN=$(gcloud auth print-access-token)
APP_NAME=oauth-client-credentials-app

echo "Installing apigeecli"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/master/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

echo "Deploying Apigee artifacts..."

zip -r integrated-developer-portal.zip apiproxy

echo "Importing and Deploying Apigee sample-integrated-developer-portal proxy..."
REV=$(apigeecli apis import -f integrated-developer-portal.zip --org $PROJECT --token $TOKEN --disable-check | jq ."revision" -r)
apigeecli apis deploy --wait --name sample-integrated-developer-portal --ovr --rev $REV --org $PROJECT --env $APIGEE_ENV --token $TOKEN

echo "Creating API Product"
apigeecli products create --name sample-integrated-developer-portal-product --displayname "sample-integrated-developer-portal-product" --proxies sample-integrated-developer-portal --envs $APIGEE_ENV --approval auto --quota 10 --interval 1 --unit minute --org $PROJECT --token $TOKEN

echo "Creating Developer"
apigeecli developers create --user testuser --email sample-integrated-developer-portal_apigeesamples@acme.com --first Test --last User --org $PROJECT --token $TOKEN

echo "Creating Developer App"
APP_ID=$(apigeecli apps create --name $APP_NAME --email sample-integrated-developer-portal_apigeesamples@acme.com --prods sample-integrated-developer-portal-product --org $PROJECT --token $TOKEN --disable-check | jq ."appId" -r)

APP_CLIENT_ID=$(apigeecli apps get --name $APP_NAME --org $PROJECT --token $TOKEN --disable-check | jq ."[0].credentials[0].consumerKey" -r)
export APP_CLIENT_ID

APP_CLIENT_SECRET=$(apigeecli apps get --name $APP_NAME --org $PROJECT --token $TOKEN --disable-check | jq ."[0].credentials[0].consumerSecret" -r)
export APP_CLIENT_SECRET

# var is expected by integration test (apickli)
export PROXY_URL="$APIGEE_HOST/v1/sample/integrated-developer-portal"

# integration tests
npm install
npm run test

echo " "
echo "All the Apigee artifacts are successfully deployed!"

echo " "
echo "Your Proxy URL is: https://$PROXY_URL"
echo "Your app client id is: $APP_CLIENT_ID"
echo "Your app client secret is: $APP_CLIENT_SECRET"
echo "To call the API yourself: curl -X GET 'http://$PROXY_URL?apikey=$APP_CLIENT_ID'"
echo " "