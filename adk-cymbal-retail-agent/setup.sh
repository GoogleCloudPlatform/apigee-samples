#!/bin/bash

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

set -e

DEPLOY_DISCOVERY_PROXY="${DEPLOY_DISCOVERY_PROXY:-true}"
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --deploy-discovery-proxy) DEPLOY_DISCOVERY_PROXY="$2"; shift 2 ;;
    --deploy-discovery-proxy=*) DEPLOY_DISCOVERY_PROXY="${1#*=}"; shift ;;
    *) echo "Unknown parameter: $1"; exit 1 ;;
  esac
done

if [ -z "$PROJECT_ID" ]; then
  PROJECT_ID="$(gcloud config get-value project 2>/dev/null)"
  if [ -z "$PROJECT_ID" ]; then
    echo "Error: No PROJECT_ID set or configured in gcloud. Please export PROJECT_ID=<project-id>"
    exit 1
  fi
  export PROJECT_ID
fi

PROJECT_NUMBER="$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")"
export PROJECT_NUMBER
export APIGEE_ENV="${APIGEE_ENV:-eval}"
export SERVICE_ACCOUNT_NAME="llm-cymbal-retail-agent"

export GCP_PROJECT_REGION="${GCP_PROJECT_REGION:-us-central1}"
export MODEL_ARMOR_REGION="${GCP_PROJECT_REGION}"
export MODEL_ARMOR_TEMPLATE_ID="llm-governance-template"

export APIGEE_APIHUB_PROJECT_ID="${PROJECT_ID}"
export APIGEE_APIHUB_REGION="${GCP_PROJECT_REGION}"

export VERTEXAI_REGION="${GCP_PROJECT_REGION}"
export VERTEXAI_PROJECT_ID="${PROJECT_ID}"
export MODEL_NAME="gemini-2.5-flash"

# Install apigeecli if not already present
if ! command -v apigeecli &> /dev/null; then
  echo "Installing apigeecli..."
  curl -s https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | bash
  export PATH=$PATH:$HOME/.apigeecli/bin
fi

# Auto-discover APIGEE_HOST if not already set
if [ -z "$APIGEE_HOST" ]; then
  echo "APIGEE_HOST not set. Attempting auto-discovery..."
  TOKEN=$(gcloud auth application-default print-access-token 2>/dev/null || gcloud auth print-access-token 2>/dev/null)
  if [ -n "$TOKEN" ]; then
    HOST_DISCOVERED=$(apigeecli envgroups list -o "$PROJECT_ID" -t "$TOKEN" 2>/dev/null | jq -r '.[0].hostnames[0]' 2>/dev/null || true)
    if [ -n "$HOST_DISCOVERED" ] && [ "$HOST_DISCOVERED" != "null" ]; then
      export APIGEE_HOST="$HOST_DISCOVERED"
      echo "Discovered APIGEE_HOST: $APIGEE_HOST"
    fi
  fi
fi

if [ -z "$APIGEE_HOST" ]; then
  echo "Error: APIGEE_HOST is not set and could not be auto-discovered."
  echo "Please export APIGEE_HOST=<your-apigee-hostname> (e.g. api-my-org.apiservices.dev or 34.xx.xx.xx.nip.io)"
  exit 1
fi

gcloud config set project "$PROJECT_ID"

echo "Enabling required Google Cloud services..."
gcloud services enable \
  artifactregistry.googleapis.com \
  dlp.googleapis.com \
  logging.googleapis.com \
  aiplatform.googleapis.com \
  modelarmor.googleapis.com \
  secretmanager.googleapis.com \
  agentregistry.googleapis.com \
  agentidentitycredentials.googleapis.com \
  iamconnectors.googleapis.com \
  iamconnectorcredentials.googleapis.com \
  --project "$PROJECT_ID"
sleep 15

./deploy-adk-cymbal-retail-agent.sh --deploy-discovery-proxy "$DEPLOY_DISCOVERY_PROXY"
