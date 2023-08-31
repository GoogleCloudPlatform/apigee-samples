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

if [ -z "$ENV_GROUP_NAME" ]; then
    echo "No ENV_GROUP_NAME variable set"
    exit
fi

if [ -z "$ENV_GROUP_HOSTNAME_GRPC" ]; then
    echo "No ENV_GROUP_HOSTNAME_GRPC variable set"
    exit
fi

if [ -z "$CLOUD_RUN_SERVICE_URL" ]; then
    echo "No CLOUD_RUN_SERVICE_URL variable set"
    exit
fi

if [ -z "$GRPC_TARGET_SERVER_NAME" ]; then
    echo "No GRPC_TARGET_SERVER_NAME variable set"
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

echo "Updating environment group to include grpc domain $ENV_GROUP_HOSTNAME_GRPC..."
apigeecli envgroups update -n "$ENV_GROUP_NAME"  --hosts "$APIGEE_HOST,$ENV_GROUP_HOSTNAME_GRPC"  --org "$PROJECT" --token "$TOKEN"

echo "Creating the gRPC target server..."
curl -fsSL "https://apigee.googleapis.com/v1/organizations/$PROJECT/environments/$APIGEE_ENV/targetservers"   -H "Authorization: Bearer $TOKEN"   -X POST   -H "Content-Type:application/json"   -d '{
  "name": "'"$GRPC_TARGET_SERVER_NAME"'",
  "host": "'"$CLOUD_RUN_SERVICE_URL"'",
  "port": 443,
  "isEnabled": true,
  "sSLInfo": {
    "commonName": {}
  },
  "protocol": "GRPC_TARGET"
}'

echo "Importing and Deploying Apigee grpc proxy..."
REV=$(apigeecli apis create bundle -f apiproxy  -n grpc --org "$PROJECT" --token "$TOKEN" --disable-check | jq ."revision" -r)
apigeecli apis deploy --wait --name grpc --ovr --rev "$REV" --org "$PROJECT" --env "$APIGEE_ENV" --token "$TOKEN"

echo "Creating API Products..."
apigeecli products create --name grpc --displayname "gRPC" --envs "$APIGEE_ENV" --approval auto --org "$PROJECT" --token "$TOKEN"

echo "Creating Developer..."
apigeecli developers create --user testuser --email grpc_apigeesamples@acme.com --first Test --last User --org "$PROJECT" --token "$TOKEN"

echo "Creating Developer App..."
apigeecli apps create --name grpcApp --email grpc_apigeesamples@acme.com --prods grpc --org "$PROJECT" --token "$TOKEN" --disable-check

CLIENT_ID=$(apigeecli apps get --name grpcApp --org "$PROJECT" --token "$TOKEN" --disable-check | jq ."[0].credentials[0].consumerKey" -r)
export CLIENT_ID

# var is expected by integration test (apickli)
export PROXY_URL="$ENV_GROUP_HOSTNAME_GRPC/helloworld.Greeter/SayHello"

# integration tests

npm run test

echo " "
echo "All the Apigee artifacts are successfully deployed!"
echo " "
echo "Your gRPC Proxy URL is: $PROXY_URL"
echo " "
echo "-----------------------------"
echo " "
echo "To call the API you can use the following grpcurl command:"
echo " "
echo "grpcurl -H "x-apikey:$CLIENT_ID" -import-path $HOME/grpc-backend/grpc/examples/protos -proto helloworld.proto -d '{"name":"Guest"}' $ENV_GROUP_HOSTNAME_GRPC:443 helloworld.Greeter/SayHello"
echo " "
