#!/bin/bash
set -euo pipefail

# Copyright 2026 Google LLC
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

echo "Installing apigeecli"
if ! command -v apigeecli &> /dev/null; then
    echo "Installing apigeecli"
    curl -L https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | sh -
fi
export PATH=$PATH:$HOME/.apigeecli/bin

echo "Undeploying spike-arrest proxy"
DEPLOYED_REV=$(apigeecli envs deployments get --env "$APIGEE_ENV" --org "$PROJECT" --token "$TOKEN" --disable-check | jq --raw-output '.deployments[] | select(.apiProxy=="spike-arrest").revision' | head -n 1)
if [ -n "$DEPLOYED_REV" ]; then
  apigeecli apis undeploy --name spike-arrest --env "$APIGEE_ENV" --rev "$DEPLOYED_REV" --org "$PROJECT" --token "$TOKEN"
fi

echo "Deleting proxy spike-arrest"
apigeecli apis delete --name spike-arrest --org "$PROJECT" --token "$TOKEN"

echo "Clean up complete!"
