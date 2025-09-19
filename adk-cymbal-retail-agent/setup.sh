#!/bin/bash

# Copyright 2025 Google LLC
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


PROJECT_NUMBER="$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")"
export PROJECT_NUMBER
export APIGEE_ENV="eval"
export SERVICE_ACCOUNT_NAME="llm-cymbal-retail-agent"

export MODEL_ARMOR_REGION="us-central1"
export MODEL_ARMOR_TEMPLATE_ID="llm-governance-template" #use existing or create new template using this id

export APIGEE_APIHUB_PROJECT_ID="${PROJECT_ID}"
export APIGEE_APIHUB_REGION="${GCP_PROJECT_REGION}"

export VERTEXAI_REGION="${GCP_PROJECT_REGION}"
export VERTEXAI_PROJECT_ID="${PROJECT_ID}"
export MODEL_ID="gemini-2.5-flash"

export OAUTH_CLIENT_ID="OAUTH_CLIENT_ID_TO_SET"
export OAUTH_CLIENT_SECRET="OAUTH_CLIENT_SECRET_TO_SET"
export AGENT_REDIRECT_URI=http://localhost:8000/dev-ui/

export NON_ADMIN_USER="NON_ADMIN_USER_TO_SET"

gcloud config set project $PROJECT_ID

./bq-setup.sh
# ./create-integration-connector.sh
./deploy-adk-cymbal-retail-agent.sh
