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

gen_key_pairs (){
    if [ -z "$PR_KEY" ]; then
        PR_KEY=$(openssl genrsa 2048)
        PU_KEY=$(printf '%s\n' "$PR_KEY" | openssl rsa -outform PEM -pubout)
        JWK=$(printf '%s\n' "$PU_KEY" | pem-jwk)
        PR_KEY=$(printf '%s\n' "$PR_KEY" | tr -d '\n')
        JWK=$(printf '%s\n' "$JWK" | tr -d '\n') 
        TOKEN_CLIENT_ID_CLAIM=client_id
        JWKS_URI="$APIGEE_HOST/v1/samples/oidc/jwks"
        TOKEN_ISSUER="$APIGEE_HOST/"
    fi
}

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

if [ -z "$JWKS_URI" ]; then
    echo "No JWKS_URI variable set"
    echo "Generating mock oidc config"
    gen_key_pairs
fi

if [ -z "$TOKEN_ISSUER" ]; then
    echo "No TOKEN_ISSUER variable set"
    echo "Generating mock oidc config"
    gen_key_pairs
fi

if [ -z "$TOKEN_AUDIENCE" ]; then
    echo "No TOKEN_AUDIENCE variable set"
    echo "Generating mock oidc config"
    gen_key_pairs
fi

if [ -z "$TOKEN_CLIENT_ID_CLAIM" ]; then
    echo "No TOKEN_CLIENT_ID_CLAIM variable set"
    echo "Generating mock oidc config"
    gen_key_pairs
fi

if [ -z "$IDP_APP_CLIENT_ID" ]; then
    echo "No IDP_CLIENT_ID variable set"
    echo "Generating mock oidc config"
    gen_key_pairs
fi

if [ -z "$IDP_APP_CLIENT_SECRET" ]; then
    echo "No IDP_CLIENT_SECRET variable set"
    echo "Generating mock oidc config"
    gen_key_pairs
fi

TOKEN=$(gcloud auth print-access-token)
APP_NAME=authz-idp-acccess-tokens-sample-app

echo "Installing dependencies"
npm run preinstall
npm install

echo "Installing apigeecli"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/master/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

echo "Running apigeelint"
npm run lint

echo "Deploying Apigee artifacts..."

mkdir rendered
cp -r ./sharedflowbundle ./rendered
sed -i "s/REPLACEWITHIDPCLIENTIDCLAIM/$TOKEN_CLIENT_ID_CLAIM/g" ./rendered/sharedflowbundle/policies/VK-IdentifyClientApp.xml
if [ ! -z "$PR_KEY" ]; then
    cd mock-tooks
    cd ../
    echo "Deploying public and private keys for mock oidc..."
    echo -e "jwk=$JWK\nprivate_key=$PR_KEY" > mock_configuration.properties
    apigeecli res create --org "$PROJECT" --env "$APIGEE_ENV" --token "$TOKEN" --name mock_configuration --type properties --respath mock_configuration.properties
fi

echo "Importing and Deploying Apigee authorize-idp-access-tokens sharedflow..."
REV_SF=$(apigeecli sharedflows create bundle -f ./sharedflowbundle -n authorize-idp-access-tokens --org "$PROJECT" --token "$TOKEN" --disable-check | jq ."revision" -r)
apigeecli sharedflows deploy --name authorize-idp-access-tokens --ovr --rev "$REV_SF" --org "$PROJECT" --env "$APIGEE_ENV" --token "$TOKEN"

echo "Importing and Deploying Apigee sample-authorize-idp-access-tokens proxy..."
REV=$(apigeecli apis create bundle -f ./apiproxy -n sample-authorize-idp-access-tokens --org "$PROJECT" --token "$TOKEN" --disable-check | jq ."revision" -r)
apigeecli apis deploy --wait --name sample-authorize-idp-access-tokens --ovr --rev "$REV" --org "$PROJECT" --env "$APIGEE_ENV" --token "$TOKEN"

echo "Creating API Product"
apigeecli products create --name authz-idp-acccess-tokens-sample-product --displayname "authz-idp-acccess-tokens-sample-product" --proxies sample-authorize-idp-access-tokens --envs "$APIGEE_ENV" --approval auto --quota 10 --interval 1 --unit minute --org "$PROJECT" --token "$TOKEN"

echo "Creating Developer"
apigeecli developers create --user testuser --email authz-idp-acccess-tokens_apigeesamples@acme.com --first Test --last User --org "$PROJECT" --token "$TOKEN"

echo "Creating Developer App"
apigeecli apps create --name $APP_NAME --email authz-idp-acccess-tokens_apigeesamples@acme.com --prods authz-idp-acccess-tokens-sample-product --callback https://developers.google.com/oauthplayground/ --org "$PROJECT" --token "$TOKEN" --disable-check


if [ ! -z "$PR_KEY" ]; then
    TOKEN_AUDIENCE=$(apigeecli apps get --name $APP_NAME --org "$PROJECT" --token "$TOKEN" --disable-check | jq ."[0].credentials[0].consumerKey" -r)
    echo "Importing and Deploying Apigee authorization-server-mock proxy..."
    REV_A=$(apigeecli apis create bundle -f ./mock-tools/apiproxy -n authorization-server-mock --org "$PROJECT" --token "$TOKEN" --disable-check | jq ."revision" -r)
    apigeecli apis deploy --wait --name authorization-server-mock --ovr --rev "$REV" --org "$PROJECT" --env "$APIGEE_ENV" --token "$TOKEN"
else
    echo "Creating Developer App Key"
    apigeecli apps keys create --name $APP_NAME --dev authz-idp-acccess-tokens_apigeesamples@acme.com --prods authz-idp-acccess-tokens-sample-product --org "$PROJECT" --token "$TOKEN" --key "$IDP_APP_CLIENT_ID" --secret "$IDP_APP_CLIENT_SECRET" --disable-check
fi

rm idp_configuration.properties
echo -e "jwks_uri=$JWKS_URI\nissuer=$TOKEN_ISSUER\naudience=$TOKEN_AUDIENCE" > idp_configuration.properties

echo "Importing and Deploying IdP config as an environemnt property set..."
apigeecli res create --org "$PROJECT" --env "$APIGEE_ENV" --token "$TOKEN" --name idp_configuration --type properties --respath idp_configuration.properties

