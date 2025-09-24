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

set -e

PROJECT_NUMBER="$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")"
export PROJECT_NUMBER
export APIGEE_ENV="eval"
export SERVICE_ACCOUNT_NAME="llm-cymbal-retail-agent"

export MODEL_ARMOR_REGION="${GCP_PROJECT_REGION}"
export MODEL_ARMOR_TEMPLATE_ID="llm-governance-template" #use existing or create new template using this id

export APIGEE_APIHUB_PROJECT_ID="${PROJECT_ID}"
export APIGEE_APIHUB_REGION="${GCP_PROJECT_REGION}"

export VERTEXAI_REGION="${GCP_PROJECT_REGION}"
export VERTEXAI_PROJECT_ID="${PROJECT_ID}"
export MODEL_ID="gemini-2.5-flash"

export OAUTH_CLIENT_ID="OAUTH_CLIENT_ID_TO_SET"
export OAUTH_CLIENT_SECRET="OAUTH_CLIENT_SECRET_TO_SET"
export AGENT_REDIRECT_URI=http://localhost:8000/dev-ui/

export NON_ADMIN_USER="${GCP_USER_2_ID}"

echo "Installing dependecies like unzip and cosign"
apt-get install -y unzip
wget "https://github.com/sigstore/cosign/releases/download/v2.4.1/cosign-linux-amd64"
mv cosign-linux-amd64 /usr/local/bin/cosign
chmod +x /usr/local/bin/cosign

gcloud config set project $PROJECT_ID

gcloud services enable artifactregistry.googleapis.com run.googleapis.com dlp.googleapis.com logging.googleapis.com aiplatform.googleapis.com modelarmor.googleapis.com secretmanager.googleapis.com bigquery.googleapis.com datacatalog.googleapis.com --project "$PROJECT_ID"
sleep 15

./bq-setup.sh #Configure the BQ dataset, data policies and assign the user to data policy
./oauth-setup.sh
cat oauth_client_env.sh #to be removed
source ./oauth_client_env.sh
./create-integration-connector.sh
./deploy-adk-cymbal-retail-agent.sh
