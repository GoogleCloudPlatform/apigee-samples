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

if [ -z "$APIGEE_ENV" ]; then
  echo "No APIGEE_ENV variable set"
  exit
fi

TOKEN=$(gcloud auth print-access-token)

echo "Installing apigeecli"
curl -L https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | sh -
export PATH=$PATH:$HOME/.apigeecli/bin

echo "Undeploying and deleting Example Proxy"
DEPLOYED_REV=$(apigeecli apis listdeploy --name traffic-mirror-example --org "$PROJECT" --env "$APIGEE_ENV" --token "$TOKEN" --disable-check | jq .'deployments[0].revision' -r)
if [ "$DEPLOYED_REV" != "null" ]; then
  apigeecli apis undeploy --name traffic-mirror-example --env "$APIGEE_ENV" --rev "$DEPLOYED_REV" --org "$PROJECT" --token "$TOKEN"
fi
apigeecli apis delete --name traffic-mirror-example --org "$PROJECT" --token "$TOKEN"

echo "Undeploying and deleting Traffic Mirroring Shared Flow"
DEPLOYED_REV=$(apigeecli sharedflows listdeploy --name traffic-mirroring --org "$PROJECT" --env "$APIGEE_ENV" --token "$TOKEN" --disable-check | jq .'deployments[0].revision' -r)
if [ "$DEPLOYED_REV" != "null" ]; then
  apigeecli sharedflows undeploy --name traffic-mirroring --env "$APIGEE_ENV" --rev "$DEPLOYED_REV" --org "$PROJECT" --token "$TOKEN"
fi
apigeecli sharedflows delete --name traffic-mirroring --org "$PROJECT" --token "$TOKEN"

echo "Clean up complete!"
