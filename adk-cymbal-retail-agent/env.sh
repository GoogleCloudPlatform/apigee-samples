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

DEFAULT_PROJECT="$(gcloud config get-value project 2>/dev/null || echo "PROJECT_ID_TO_SET")"
export PROJECT_ID="${PROJECT_ID:-$DEFAULT_PROJECT}"
if [ -n "$PROJECT_ID" ] && [ "$PROJECT_ID" != "PROJECT_ID_TO_SET" ]; then
  PROJECT_NUMBER="$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)" 2>/dev/null || true)"
  export PROJECT_NUMBER
fi
export APIGEE_ENV="${APIGEE_ENV:-APIGEE_ENV_TO_SET}"
export APIGEE_HOST="${APIGEE_HOST:-APIGEE_HOST_TO_SET}"
export SERVICE_ACCOUNT_NAME="${SERVICE_ACCOUNT_NAME:-llm-cymbal-retail-agent}"

export MODEL_ARMOR_REGION="${MODEL_ARMOR_REGION:-MODEL_ARMOR_REGION_TO_SET}"
export MODEL_ARMOR_TEMPLATE_ID="${MODEL_ARMOR_TEMPLATE_ID:-llm-governance-template}" #use existing or create new template using this id

export APIGEE_APIHUB_PROJECT_ID="${APIGEE_APIHUB_PROJECT_ID:-$PROJECT_ID}"
export APIGEE_APIHUB_REGION="${APIGEE_APIHUB_REGION:-us-central1}"

export VERTEXAI_REGION="${VERTEXAI_REGION:-us-central1}"
export VERTEXAI_PROJECT_ID="${VERTEXAI_PROJECT_ID:-$PROJECT_ID}"
export MODEL_NAME="${MODEL_NAME:-gemini-2.5-flash}"

export AGENT_GATEWAY_NAME="${AGENT_GATEWAY_NAME:-egress-gateway}"
export STAGING_BUCKET="${STAGING_BUCKET:-${PROJECT_ID}_cymbal_retail_agent}"

export APP_DEFAULT_TOKEN=$(gcloud auth application-default print-access-token 2>/dev/null || true)