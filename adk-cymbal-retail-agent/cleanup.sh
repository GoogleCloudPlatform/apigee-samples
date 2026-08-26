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

./cleanup-adk-cymbal-retail-agent.sh
./cleanup-agent-gateway-egress.sh
if [ -f "./cleanup-llm-ai-gateway.sh" ]; then
  ./cleanup-llm-ai-gateway.sh || echo "INFO: LLM AI Gateway cleanup completed or not present."
fi

echo "✅ Cleanup complete!"
