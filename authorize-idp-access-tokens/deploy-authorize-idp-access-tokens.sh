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

if [ -z "$JWKS_URI" ]; then
    echo "No JWKS_URI variable set"
    exit
fi

if [ -z "$TOKEN_ISSUER" ]; then
    echo "No TOKEN_ISSUER variable set"
    exit
fi

if [ -z "$TOKEN_AUDIENCE" ]; then
    echo "No TOKEN_AUDIENCE variable set"
    exit
fi

if [ -z "$TOKEN_CLIENT_ID_CLAIM" ]; then
    echo "No TOKEN_CLIENT_ID_CLAIM variable set"
    exit
fi

if [ -z "$IDP_APP_CLIENT_ID" ]; then
    echo "No IDP_CLIENT_ID variable set"
    exit
fi

if [ -z "$IDP_APP_CLIENT_SECRET" ]; then
    echo "No IDP_CLIENT_SECRET variable set"
    exit
fi

TOKEN=$(gcloud auth print-access-token)
APP_NAME=authz-idp-acccess-tokens-sample-app

echo "Installing dependencies"
npm install

echo "Installing apigeecli"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/master/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

echo "Running apigeelint"
npm run lint

echo "Deploying Apigee artifacts..."
rm authorize-idp-access-tokens.zip
mkdir rendered
cp -r ./sharedflowbundle ./rendered
sed -i "s/REPLACEWITHIDPCLIENTIDCLAIM/$TOKEN_CLIENT_ID_CLAIM/g" ./rendered/policies/VK-IdentifyClientApp.xml
cd rendered
zip -r authorize-idp-access-tokens.zip sharedflowbundle
cp authorize-idp-access-tokens.zip ../
cd ../
rm -r ./rendered
rm sample-authorize-idp-access-tokens.zip
zip -r sample-authorize-idp-access-tokens.zip apiproxy
rm idp_configuration.properties
echo -e "jwks_uri=$JWKS_URI\nissuer=$TOKEN_ISSUER\naudience=$TOKEN_AUDIENCE" > idp_configuration.properties

echo "Importing and Deploying IdP config as an environemnt property set..."
apigeecli res create --org "$PROJECT" --env "$APIGEE_ENV" --token "$TOKEN" --name idp_configuration --type properties --respath idp_configuration.properties

echo "Importing and Deploying Apigee authorize-idp-access-tokens sharedflow..."
REV_SF=$(apigeecli sharedflows import -f authorize-idp-access-tokens.zip --org "$PROJECT" --token "$TOKEN" --disable-check | jq ."revision" -r)
apigeecli sharedflows deploy --name authorize-idp-access-tokens --ovr --rev "$REV_SF" --org "$PROJECT" --env "$APIGEE_ENV" --token "$TOKEN"

echo "Importing and Deploying Apigee sample-authorize-idp-access-tokens proxy..."
REV=$(apigeecli apis import -f sample-authorize-idp-access-tokens.zip --org "$PROJECT" --token "$TOKEN" --disable-check | jq ."revision" -r)
apigeecli apis deploy --wait --name sample-authorize-idp-access-tokens --ovr --rev "$REV" --org "$PROJECT" --env "$APIGEE_ENV" --token "$TOKEN"

echo "Creating API Product"
apigeecli products create --name authz-idp-acccess-tokens-sample-product --displayname "authz-idp-acccess-tokens-sample-product" --proxies sample-authorize-idp-access-tokens --envs "$APIGEE_ENV" --approval auto --quota 10 --interval 1 --unit minute --org "$PROJECT" --token "$TOKEN"

echo "Creating Developer"
apigeecli developers create --user testuser --email authz-idp-acccess-tokens_apigeesamples@acme.com --first Test --last User --org "$PROJECT" --token "$TOKEN"

echo "Creating Developer App"
apigeecli apps create --name $APP_NAME --email authz-idp-acccess-tokens_apigeesamples@acme.com --prods authz-idp-acccess-tokens-sample-product --org "$PROJECT" --token "$TOKEN" --disable-check

echo "Creating Developer App Key"
apigeecli apps keys create --name $APP_NAME --dev authz-idp-acccess-tokens_apigeesamples@acme.com --prods authz-idp-acccess-tokens-sample-product --org "$PROJECT" --token "$TOKEN" --key "$IDP_APP_CLIENT_ID" --secret "$IDP_APP_CLIENT_SECRET" --disable-check
