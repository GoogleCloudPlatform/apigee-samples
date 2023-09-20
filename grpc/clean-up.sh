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

if ! [ -x "$(command -v jq)" ]; then
  echo "jq command is not on your PATH"
  exit
fi

function wait_for_operation() {
  while true; do
    STATE="$(apigeecli operations get -o "$PROJECT" -n "$1" -t "$TOKEN" | jq --raw-output '.metadata.state')"
    if [ "$STATE" = "FINISHED" ]; then
      echo
      break
    fi
    echo -n .
    sleep 5
  done
}

echo "Installing apigeecli"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/master/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

TOKEN="$(gcloud auth print-access-token)"

# Get Org and instance information
INSTANCE_JSON=$(apigeecli instances list -o "$PROJECT" -t "$TOKEN")
INSTANCE_NAME=$(echo "$INSTANCE_JSON" | jq --raw-output '.instances[0].name')
REGION=$(echo "$INSTANCE_JSON" | jq --raw-output '.instances[0].location')
ENVIRONMENT_NAME="sample-environment"
ENVIRONMENT_GROUP_NAME="sample-environment-group"

echo "Deleting load balancer..."
# Delete forwarding rule
gcloud compute forwarding-rules delete sample-apigee-https-lb-rule \
  --global \
  --project="$PROJECT" --quiet

# Delete target HTTPS proxy
gcloud compute target-https-proxies delete sample-apigee-https-proxy \
  --project="$PROJECT" --quiet

# Delete URL map
gcloud compute url-maps delete sample-apigee-urlmap \
  --project="$PROJECT" --quiet

# Delete backend service
gcloud compute backend-services delete sample-apigee-backend \
  --global \
  --project="$PROJECT" --quiet

# Delete NEG
gcloud compute network-endpoint-groups delete sample-apigee-neg \
  --region="$REGION" \
  --project="$PROJECT" --quiet

# Delete cert
echo "Deleting SSL certificate..."
gcloud compute ssl-certificates delete sample-apigee-ssl-cert \
  --project "$PROJECT" --quiet

# Delete VIP
echo "Deleting load balancer IP address..."
gcloud compute addresses delete sample-apigee-vip \
  --global \
  --project "$PROJECT" --quiet

#Undeploy gRPC service from Cloud Run and delete images
echo "Deleting Cloud Run gRPC service..."
gcloud run services delete grpc-backend-apigee --region "$REGION" --quiet

echo "Deleting Developer Apps..."
DEVELOPER_ID=$(apigeecli developers get --email grpc_apigeesamples@acme.com --org "$PROJECT" --token "$TOKEN" --disable-check | jq .'developerId' -r)
apigeecli apps delete --id "$DEVELOPER_ID" --name grpcApp --org "$PROJECT" --token "$TOKEN"

echo "Deleting Developer..."
apigeecli developers delete --email grpc_apigeesamples@acme.com --org "$PROJECT" --token "$TOKEN"

echo "Deleting API Products..."
apigeecli products delete --name grpc --org "$PROJECT" --token "$TOKEN"

echo "Undeploying grpc proxy..."
REV=$(apigeecli envs deployments get --env "$ENVIRONMENT_NAME" --org "$PROJECT" --token "$TOKEN" --disable-check | jq .'deployments[]| select(.apiProxy=="grpc").revision' -r)
apigeecli apis undeploy --name grpc --env "$ENVIRONMENT_NAME" --rev "$REV" --org "$PROJECT" --token "$TOKEN"

echo "Deleting grpc proxy..."
apigeecli apis delete --name grpc --org "$PROJECT" --token "$TOKEN"

echo "Deleting gRPC target server..."
apigeecli targetservers delete --name grpc-server --org "$PROJECT" --token "$TOKEN" -e "$ENVIRONMENT_NAME"

echo -n "Detaching environment from group..."
OPERATION=$(apigeecli envgroups detach -o "$PROJECT" -e "$ENVIRONMENT_NAME" -n "$ENVIRONMENT_GROUP_NAME" -t "$TOKEN" | jq --raw-output '.name' | awk -F/ '{print $4}')
wait_for_operation "$OPERATION"

echo -n "Deleting environment group..."
OPERATION=$(apigeecli envgroups delete -o "$PROJECT" -n "$ENVIRONMENT_GROUP_NAME" -t "$TOKEN" | jq --raw-output '.name' | awk -F/ '{print $4}')
wait_for_operation "$OPERATION"

echo -n "Detaching environment from instance..."
OPERATION=$(apigeecli instances attachments detach -o "$PROJECT" -e "$ENVIRONMENT_NAME" -n "$INSTANCE_NAME" -t "$TOKEN" | jq --raw-output '.name' | awk -F/ '{print $4}')
wait_for_operation "$OPERATION"

echo -n "Deleting environment..."
OPERATION=$(apigeecli environments delete -o "$PROJECT" -e "$ENVIRONMENT_NAME" -t "$TOKEN" | jq --raw-output '.name' | awk -F/ '{print $4}')
wait_for_operation "$OPERATION"

echo "Clean up complete!"
