#!/bin/bash
set -euo pipefail
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

if [ -z "$APIGEE_HOST" ]; then
  echo "No APIGEE_HOST variable set"
  exit
fi

TOKEN=$(gcloud auth print-access-token)
SCRIPTPATH="$( cd "$(dirname "$0")" || exit >/dev/null 2>&1 ; pwd -P )"

echo "Installing apigeecli"
if ! command -v apigeecli &> /dev/null; then
    echo "Installing apigeecli"
    curl -L https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | sh -
fi
export PATH=$PATH:$HOME/.apigeecli/bin

echo "Deploying Traffic Mirroring Shared Flow"
REV=$(apigeecli sharedflows create bundle -f "$SCRIPTPATH/sharedflowbundle" -n traffic-mirroring --org "$PROJECT" --token "$TOKEN" --disable-check | jq ."revision" -r)
apigeecli sharedflows deploy --name traffic-mirroring --ovr --rev "$REV" --org "$PROJECT" --env "$APIGEE_ENV" --token "$TOKEN"

echo " "
echo "Deploying Example Proxy"
REV=$(apigeecli apis create bundle -f "$SCRIPTPATH/example-proxy/apiproxy" -n traffic-mirror-example --org "$PROJECT" --token "$TOKEN" --disable-check | jq ."revision" -r)
apigeecli apis deploy --wait --name traffic-mirror-example --ovr --rev "$REV" --org "$PROJECT" --env "$APIGEE_ENV" --token "$TOKEN"

echo " "
echo "============================="
echo "Traffic Mirroring Shared Flow is deployed!"
echo "============================="
echo " "
echo "Example API Endpoint:"
echo "  https://$APIGEE_HOST/v1/samples/traffic-mirror/get"
echo " "
echo "Try it:"
echo "  curl https://$APIGEE_HOST/v1/samples/traffic-mirror/get"
echo " "
