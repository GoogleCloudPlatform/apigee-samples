#!/bin/bash

# Copyright 2024 Google LLC
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

if [ -z "$REGION" ]; then
  echo "No REGION variable set"
  exit
fi

#Create Load Balancer and Apigee backend
echo "Installing apigeecli"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

TOKEN="$(gcloud auth print-access-token)"

# Enable APIs
gcloud services enable \
  compute.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  --project="$PROJECT" --quiet

echo "Build and deploy the gRPC-Web application to Cloud Run"
./app/deploy-grpc-web-cloud-run.sh

#echo "Installing npm dependencies..."
#npm install

#echo "Running apigeelint..."
#npm run lint