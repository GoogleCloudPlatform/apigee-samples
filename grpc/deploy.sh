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

if [ -z "$NETWORK" ]; then
  echo "No NETWORK variable set"
  exit
fi

if [ -z "$SUBNET" ]; then
  echo "No SUBNET variable set"
  exit
fi

if ! [ -x "$(command -v jq)" ]; then
  echo "jq command is not on your PATH"
  exit
fi

#Create Load Balancer and Apigee backend
echo "Installing apigeecli"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

echo "Installing dependencies..."
npm install

TOKEN="$(gcloud auth print-access-token)"

# Get Apigee instance information
INSTANCE_JSON=$(apigeecli instances list -o "$PROJECT" -t "$TOKEN")
INSTANCE_NAME=$(echo "$INSTANCE_JSON" | jq --raw-output '.instances[0].name')
REGION=$(echo "$INSTANCE_JSON" | jq --raw-output '.instances[0].location')
SERVICE_ATTACHMENT=$(echo "$INSTANCE_JSON" | jq --raw-output '.instances[0].serviceAttachment')
ENVIRONMENT_NAME="sample-environment"
ENVIRONMENT_GROUP_NAME="sample-environment-group"

# Create and attach a sample Apigee environment
echo -n "Creating environment..."
apigeecli environments create -o "$PROJECT" -e "$ENVIRONMENT_NAME" -d PROXY --wait=true -t "$TOKEN"


echo -n "Attaching environment to instance (may take a few minutes)..."
apigeecli instances attachments attach -o "$PROJECT" -e "$ENVIRONMENT_NAME" -n "$INSTANCE_NAME" --wait=true -t "$TOKEN"


# Enable APIs
gcloud services enable \
  compute.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  --project="$PROJECT" --quiet

# Reserve an IP address for the Load Balancer"
echo "Reserving load balancer IP address..."
gcloud compute addresses create sample-apigee-vip --ip-version=IPV4 --global --project "$PROJECT" --quiet
RUNTIME_IP=$(gcloud compute addresses describe sample-apigee-vip --format="get(address)" --global --project "$PROJECT" --quiet)
RUNTIME_HOST_ALIAS="grpc".$(echo "$RUNTIME_IP" | tr '.' '-').nip.io

# Create a sample Apigee environment group and attach the environment
echo -n "Creating environment group..."
apigeecli envgroups create -o "$PROJECT" -d "$RUNTIME_HOST_ALIAS" -n "$ENVIRONMENT_GROUP_NAME" --wait=true -t "$TOKEN"

echo -n "Attaching environment to group..."
apigeecli envgroups attach -o "$PROJECT" -e "$ENVIRONMENT_NAME" -n "$ENVIRONMENT_GROUP_NAME" --wait=true -t "$TOKEN"

#Deploy gRPC backend to Cloud Run
git clone https://github.com/grpc/grpc.git grpc-backend

gcloud run deploy grpc-backend-apigee --allow-unauthenticated \
  --port 50051 \
  --timeout 3600 \
  --region="${REGION}" \
  --quiet \
  --source=.

CLOUD_RUN_SERVICE_URL=$(gcloud run services describe grpc-backend-apigee --platform managed --region "$REGION" --format 'value(status.url)' | sed -E 's/http.+\///')

# Create a Google managed SSL certificate
echo "Creating SSL certificate..."
gcloud compute ssl-certificates create sample-apigee-ssl-cert \
  --domains="$RUNTIME_HOST_ALIAS" --project "$PROJECT" --quiet

## Create a global Load Balancer
echo "Creating external load balancer..."

# Create a PSC NEG
gcloud compute network-endpoint-groups create sample-apigee-neg \
  --network-endpoint-type=private-service-connect \
  --psc-target-service="$SERVICE_ATTACHMENT" \
  --region="$REGION" \
  --network="$NETWORK" \
  --subnet="$SUBNET" \
  --project="$PROJECT" --quiet

# Create a backend service and add the NEG
gcloud compute backend-services create sample-apigee-backend \
  --load-balancing-scheme=EXTERNAL_MANAGED \
  --protocol=HTTP2 \
  --global --project="$PROJECT" --quiet

gcloud compute backend-services add-backend sample-apigee-backend \
  --network-endpoint-group=sample-apigee-neg \
  --network-endpoint-group-region="$REGION" \
  --global --project="$PROJECT" --quiet

# Create a Load Balancing URL map
gcloud compute url-maps create sample-apigee-urlmap \
  --default-service sample-apigee-backend --project="$PROJECT" --quiet

# Create a Load Balancing target HTTPS proxy
gcloud compute target-https-proxies create sample-apigee-https-proxy \
  --url-map sample-apigee-urlmap \
  --ssl-certificates sample-apigee-ssl-cert --project="$PROJECT" --quiet

# Create a global forwarding rule
gcloud compute forwarding-rules create sample-apigee-https-lb-rule \
  --load-balancing-scheme=EXTERNAL_MANAGED \
  --network-tier=PREMIUM \
  --address=sample-apigee-vip --global \
  --target-https-proxy=sample-apigee-https-proxy --ports=443 --project="$PROJECT" --quiet

echo -n "Waiting for certificate provisioning to complete (may take some time)..."
while true; do
  TLS_STATUS="$(gcloud compute ssl-certificates describe sample-apigee-ssl-cert --format=json --project "$PROJECT" --quiet | jq -r '.managed.status')"
  if [ "$TLS_STATUS" = "ACTIVE" ]; then
    break
  fi
  echo -n .
  sleep 10
done

# Pause to allow TLS setup to complete
sleep 30

echo "Running apigeelint..."
npm run lint

echo "Deploying Apigee artifacts..."
echo -n "Creating the gRPC target server..."
GRPC_TARGET_SERVER_NAME="grpc-server"
apigeecli targetservers create \
  --name "${GRPC_TARGET_SERVER_NAME}" \
  --port 443 \
  --host "${CLOUD_RUN_SERVICE_URL}" \
  --enable \
  --tls true \
  --org "${PROJECT}" \
  --env "${ENVIRONMENT_NAME}" \
  --protocol GRPC_TARGET \
  --token "${TOKEN}"

echo "Importing and Deploying Apigee grpc proxy..."
REV=$(apigeecli apis create bundle -f apiproxy -n grpc --org "$PROJECT" --token "$TOKEN" --disable-check | jq ."revision" -r)
apigeecli apis deploy --wait --name grpc --ovr --rev "$REV" --org "$PROJECT" --env "$ENVIRONMENT_NAME" --token "$TOKEN"

echo "Creating API Products..."
apigeecli products create --name grpc --display-name "gRPC" --envs "$ENVIRONMENT_NAME" --approval auto --org "$PROJECT" --token "$TOKEN"

echo "Creating Developer..."
apigeecli developers create --user testuser --email grpc_apigeesamples@acme.com --first Test --last User --org "$PROJECT" --token "$TOKEN"

echo "Creating Developer App..."
apigeecli apps create --name grpcApp --email grpc_apigeesamples@acme.com --prods grpc --org "$PROJECT" --token "$TOKEN" --disable-check

CLIENT_ID=$(apigeecli apps get --name grpcApp --org "$PROJECT" --token "$TOKEN" --disable-check | jq ."[0].credentials[0].consumerKey" -r)
export CLIENT_ID

# var is expected by integration test (apickli)
export PROXY_URL="$RUNTIME_HOST_ALIAS/helloworld.Greeter/SayHello"

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
echo "grpcurl -H \"x-apikey:$CLIENT_ID\" -import-path $PWD/grpc-backend/examples/protos -proto helloworld.proto -d '{\"name\":\"Guest\"}' $RUNTIME_HOST_ALIAS:443 helloworld.Greeter/SayHello"
echo " "
echo " "
echo "If you get the following error:"
echo "Failed to dial target host $RUNTIME_HOST_ALIAS.nip.io:443\": remote error: tls: handshake failure"
echo "It means the Google-managed certificate is still being provisioned. Wait a few minutes and try again."
echo " "
