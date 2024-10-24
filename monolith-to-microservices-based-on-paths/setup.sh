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

if [ -z "$PROJECT_ID" ]; then
  echo "No PROJECT_ID variable set"
  exit
fi

if [ -z "$APIGEE_ENV" ]; then
  echo "No APIGEE_ENV variable set"
  exit
fi

if [ -z "$MICROSERVICE_PATH" ]; then
  echo "No MICROSERVICE_PATH variable set"
  exit
fi

if [ -z "$LEGACY_PATH" ]; then
  echo "No LEGACY_PATH variable set"
  exit
fi



TOKEN=$(gcloud auth print-access-token)


echo "Installing apigeecli"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

echo "Updating Target URLs..."
sed -i "s|LEGACY_PATH|${LEGACY_PATH}|g" ./apiproxy/targets/Monolith.xml
sed -i "s|MICROSERVICE_PATH|${MICROSERVICE_PATH}|g" ./apiproxy/targets/Microservice.xml


echo "Deploying Apigee artifacts..."

echo "Importing and Deploying Apigee proxy..."
REV=$(apigeecli apis create bundle -f apiproxy -n custom-routing --org "$PROJECT_ID" --token "$TOKEN" --disable-check | jq ."revision" -r)
apigeecli apis deploy --wait --name custom-routing --ovr --rev "$REV" --org "$PROJECT_ID" --env "$APIGEE_ENV" --token "$TOKEN"

echo "Create proxy-scoped KVM"
apigeecli apis kvm create -o ${PROJECT_ID} -t $TOKEN -n routing-rules -p custom-routing

echo "Export the empty KVM to local file."
apigeecli kvms entries export -p custom-routing -m routing-rules -o ${PROJECT_ID} -t $TOKEN

echo " "
echo "Now, please edit the exported file, adding the necessary entries. There's a sample file in this repo. Feel free to copy its contents to your local file for a simple test."
echo " "
echo "Execute the next steps in the documentation for importing the edited KVM file into Apigee and then testing the proxy routing!"

echo "DONE"
