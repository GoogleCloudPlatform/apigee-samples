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

if [ -z "$CLOUD_RUN_SERVICE" ]; then
        echo "No CLOUD_RUN_SERVICE variable set"
        exit
fi

if [ -z "$CLOUD_RUN_REGION" ]; then
        echo "No CLOUD_RUN_REGION variable set"
        exit
fi

TOKEN=$(gcloud auth print-access-token)
SA_NAME=run-mock-target-sa

echo "Installing apigeecli"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/master/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

echo "Undeploying sample-cloud-run proxy"
REV=$(apigeecli envs deployments get --env "$APIGEE_ENV" --org "$PROJECT" --token "$TOKEN" --disable-check | jq .'deployments[]| select(.apiProxy=="sample-cloud-run").revision' -r)
apigeecli apis undeploy --name sample-cloud-run --env "$APIGEE_ENV" --rev "$REV" --org "$PROJECT" --token "$TOKEN"

echo "Deleting proxy sample-cloud-logging proxy"
apigeecli apis delete --name sample-cloud-run --org "$PROJECT" --token "$TOKEN"

echo "Delete cloud run service"
gcloud run services delete "$CLOUD_RUN_SERVICE" --region="$CLOUD_RUN_REGION"

echo "Deleting service account"
gcloud iam service-accounts delete ${SA_NAME}@"${PROJECT}".iam.gserviceaccount.com
