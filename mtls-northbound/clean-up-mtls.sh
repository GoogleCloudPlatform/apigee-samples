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

#echo "Enabling APIs..."
#gcloud services enable cloudbuild.googleapis.com

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

echo "Passed variable tests"

TOKEN=$(gcloud auth print-access-token)

echo "Installing apigeecli"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/master/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

echo "Restoring Target HTTPS Proxy to no mTLS"
gcloud compute target-https-proxies import "${TARGET_PROXY}" \
  --global \
  --source="${TARGET_PROXY}"-none.yaml \
  --quiet

echo Verifying "${TARGET_PROXY}" has been restored
while true; do
  if ! curl -s https://"$APIGEE_HOST"/v1/samples/mtls | grep 200; then
    echo "${TARGET_PROXY}" not restored, waiting 10 seconds
    sleep 10
  else
    echo "${TARGET_PROXY}" restored to no mTLS
    break
  fi
done

echo "Undeploying proxy sample-mtls"
REV=$(apigeecli envs deployments get --env "${APIGEE_ENV}" --org "${PROJECT}" --token "${TOKEN}" --disable-check | jq .'deployments[]| select(.apiProxy=="sample-mtls").revision' -r)
apigeecli apis undeploy --name sample-mtls --env "${APIGEE_ENV}" --rev "${REV}" --org "${PROJECT}" --token "${TOKEN}"

echo "Deleting proxy sample-mtls"
apigeecli apis delete --name sample-mtls --org "${PROJECT}" --token "${TOKEN}"

echo "Deleting Security Policies"
gcloud beta network-security server-tls-policies delete "${ROOT}"-lenient --location=global --quiet
gcloud beta network-security server-tls-policies delete "${ROOT}"-strict --location=global --quiet

echo "Delete Trust Config"
gcloud beta certificate-manager trust-configs delete "${TRUST_CONFIG}" --quiet

echo "Deleting the root CA"
gcloud privateca roots disable "${ROOT}" --location=us-east1 --pool="${POOL}"
gcloud privateca roots delete "${ROOT}" --location=us-east1 --pool="${POOL}" --skip-grace-period --ignore-active-certificates --quiet

echo "Deleting CA pool"
gcloud privateca pools delete "${POOL}" --location=us-east1 --quiet
