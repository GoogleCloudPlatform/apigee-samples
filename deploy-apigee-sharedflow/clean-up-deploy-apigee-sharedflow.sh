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

TOKEN=$(gcloud auth print-access-token)

echo "Installing apigeecli"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/master/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

echo "Undeploying sample-hello-cicd-sf"
REV=$(apigeecli envs deployments get --env "$APIGEE_ENV" --org "$PROJECT" --token "$TOKEN" --sharedflows --disable-check | jq .'deployments[]| select(.apiProxy=="sample-hello-cicd-sf").revision' -r)
apigeecli sharedflows undeploy --name sample-hello-cicd-sf --env "$APIGEE_ENV" --rev "$REV" --org "$PROJECT" --token "$TOKEN"

echo "Deleting sharedflow sample-hello-cicd-sf"
apigeecli sharedflows delete --name sample-hello-cicd-sf --org "$PROJECT" --token "$TOKEN"
